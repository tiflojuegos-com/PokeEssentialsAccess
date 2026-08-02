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
end

# Dialogue and messages, queued (interrupt=false) so consecutive lines do not cut each other off.
# OLD Essentials (the gen-6 era, and the fangames built on it) routes every message through
# Kernel.pbMessageDisplay, a Kernel SINGLETON method, so that is the form to wrap there.
begin
  class << Kernel
    unless method_defined?(:pbMessageDisplay__access_orig)
      alias_method :pbMessageDisplay__access_orig, :pbMessageDisplay
      def pbMessageDisplay(msgwindow, message, letterbyletter = true, commandProc = nil, &block)
        PokeAccess.say_dialogue(message)
        pbMessageDisplay__access_orig(msgwindow, message, letterbyletter, commandProc, &block)
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_text: #{e.message}\n")
end

# MODERN Essentials dropped the Kernel. prefix: dialogue (including map events via command_101 ->
# pbMessage) flows through a bare top-level pbMessageDisplay, an Object instance method the singleton wrap
# above does not intercept, so wrap it too. gen-6 defines only the Kernel singleton (def Kernel.
# pbMessageDisplay), which is NOT an Object instance method, so this capability check is false there and
# never double-wraps -- no engine-version guard is needed. Splat args to survive signature differences.
begin
  if Object.private_method_defined?(:pbMessageDisplay)
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
