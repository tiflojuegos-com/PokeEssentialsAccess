module PokeAccess
  # Remembers the most recent dialogue line so it can be repeated on demand (the info key with shift), in
  # case the player skipped through text too fast.
  def self.note_dialogue(text)
    @last_dialogue = text unless text.nil? || text.to_s.strip.empty?
  end

  # The most recent dialogue line, or nil.
  def self.last_dialogue; @last_dialogue; end

  # Cleans, remembers and speaks (queued) a dialogue line. Shared by every message hook so the repeat key
  # always has the latest line regardless of which engine path ran. An identical line within half a second
  # is remembered but not re-spoken, so a message reaching here through two layered hooks (e.g. a battle
  # paused message whose before_hook AND the internal pbMessageDisplay both fire) is voiced once -- this
  # relies on clean() stripping control bytes so the two forms compare equal. The window stays short so a
  # deliberate re-read (re-talking to an NPC) still speaks.
  def self.say_dialogue(message)
    t = clean(message)
    note_dialogue(t)
    now = (clock rescue 0)
    return if t == @last_say && @last_say_t && (now - @last_say_t) < 0.5
    @last_say = t; @last_say_t = now
    speak(t, false)
  end

  # Marks a line as already accounted for: remembered for the repeat key, not spoken, and recorded so the
  # dedup window swallows the copy the engine is about to route through the message hooks. For the one case
  # where a reader says the same thing sooner and better than the game's own text.
  def self.say_dialogue_skip(message)
    t = clean(message)
    note_dialogue(t)
    @last_say = t
    @last_say_t = (clock rescue 0)
  end
end

# Dialogue and messages, queued (interrupt=false) so consecutive lines do not cut each other off.
#
# Which form the GAME defines is read once, before anything is wrapped. OLD Essentials (the gen-6 era)
# routes every message through Kernel.pbMessageDisplay, a Kernel SINGLETON; MODERN Essentials dropped the
# prefix and everything (map events via command_101 -> pbMessage included) flows through a bare top-level
# pbMessageDisplay, an Object instance method. Asking after the singleton wrap would lie on a modern
# engine: aliasing inside `class << Kernel` finds Object's bare method and MAKES a public singleton the
# game never had, which then read as "the engine's entry is the singleton" and left the real one
# unwrapped -- six GameData games went mute at once.
pa_msg_singleton = (Kernel.respond_to?(:pbMessageDisplay) rescue false)
pa_msg_bare = (Object.private_method_defined?(:pbMessageDisplay) rescue false)

begin
  if pa_msg_singleton
    class << Kernel
      unless method_defined?(:pbMessageDisplay__access_orig)
        alias_method :pbMessageDisplay__access_orig, :pbMessageDisplay
        def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, &block)
          PokeAccess.say_dialogue(message)
          pbMessageDisplay__access_orig(msgwindow, message, letterbyletter, commandProc, &block)
        end
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_text: #{e.message}
")
end

# The bare function is wrapped wherever the engine calls it: every modern game, and a gen-6 game that only
# has the bare form. Two gen-6 games (africanvs, awakening via BES-T compat) define BOTH, with the bare one
# delegating INTO the singleton, and wrapping both there would voice a line twice; on a modern engine a
# compatibility singleton would be the delegate instead, so the era decides. Splat args to survive
# signature differences.
begin
  if pa_msg_bare && (!pa_msg_singleton || PokeAccess::Engine.gamedata?)
    class Object
      unless private_method_defined?(:pbMessageDisplay__pa_inst) || method_defined?(:pbMessageDisplay__pa_inst)
        alias_method :pbMessageDisplay__pa_inst, :pbMessageDisplay
        def pbMessageDisplay(msgwindow, message, *args, &block)
          PokeAccess.say_dialogue(message)
          pbMessageDisplay__pa_inst(msgwindow, message, *args, &block)
        end
        private :pbMessageDisplay, :pbMessageDisplay__pa_inst
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_text_modern: #{e.message}\n")
end
