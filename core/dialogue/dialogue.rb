module PokeAccess
  # Remembers the latest non-blank dialogue line for the repeat key (shift with the info key).
  def self.note_dialogue(text)
    @last_dialogue = text unless text.nil? || text.to_s.strip.empty?
  end

  # The most recent dialogue line, or nil.
  def self.last_dialogue; @last_dialogue; end

  # How many messages pbMessageDisplay is showing now, one inside another; a reader watching a window's text keeps
  # quiet for a message deeper than its screen opened at, which the dialogue reader already says.
  def self.message_depth; @msg_depth || 0; end
  def self.message_enter; @msg_depth = (@msg_depth || 0) + 1; end
  def self.message_leave; @msg_depth = [(@msg_depth || 1) - 1, 0].max; end

  # The letterbyletter flag of a pbMessageDisplay call, from the arguments after the message: the first one, or
  # true when there is none or it is the options Hash a game passes as keywords (Reborn's tts: false).
  def self.letter_by_letter(args)
    return true if args.empty? || args[0].is_a?(Hash)
    args[0]
  end

  # The message reader every screen hook shares: says the first argument only when it is a non-empty String (a
  # command list handed first is the command window's to name).
  def self.say_screen_message(args)
    text = args[0]
    say_dialogue(text) if text.is_a?(String) && !text.empty?
  end

  # For the diagnostic: how many dialogue lines the message hooks handed over, and which entry points got wrapped
  # (:singleton for Kernel.pbMessageDisplay, :bare for the top-level function).
  def self.dialogue_seen; @dialogue_seen || 0; end
  def self.note_dialogue_seen; @dialogue_seen = dialogue_seen + 1; end
  def self.dialogue_wraps; @dialogue_wraps ||= []; end
  def self.note_dialogue_wrap(form); dialogue_wraps.push(form) unless dialogue_wraps.include?(form); end

  # Cleans, remembers and speaks (queued) a dialogue line, led by any promised head, then any promised tail; a copy
  # of the same cleaned line within half a second (another hook's) is remembered as it was said but not spoken again.
  def self.say_dialogue(message)
    note_dialogue_seen
    t = clean(message)
    if recently_said?(t)
      note_dialogue(@last_led || t)
      return
    end
    @last_say = t; @last_say_t = (clock rescue 0)
    @last_led = t.to_s.strip.empty? ? t : led(take_head, t)
    note_dialogue(@last_led)
    kind = dialogue_category
    speak(@last_led, false, kind)
    tail = take_tail
    speak(tail, false, kind) if tail
  end

  # The speech category of a message line: :battle during a fight, else :dialogue.
  def self.dialogue_category
    (PokeAccess::Battle.in_battle? rescue false) ? :battle : :dialogue
  end

  # True if this exact cleaned line was voiced within the last half second.
  def self.recently_said?(t)
    now = (clock rescue 0)
    t == @last_say && @last_say_t && (now - @last_say_t) < 0.5 ? true : false
  end

  # Something to say once, right after the next dialogue line (e.g. a hatchling's shiny sparkle).
  def self.after_next_line(text)
    @tail = text
  end

  # The line promised for after the next dialogue line, handed over once.
  def self.take_tail
    t = @tail
    @tail = nil
    t
  end

  # Who leads the next dialogue line, said as its head ("head: line") once (e.g. the event a speech bubble points
  # at); nil drops a pending one.
  def self.before_next_line(text)
    @head = text
  end

  # The head promised for the next dialogue line, handed over once.
  def self.take_head
    t = @head
    @head = nil
    t
  end

  # A line as said with its head, or the line alone.
  def self.led(head, line)
    head.nil? || head.to_s.empty? ? line : "#{head}: #{line}"
  end

  # Remembers a line for the repeat key without speaking it, so the dedup window swallows the copy the engine is
  # about to route through the message hooks.
  # param head the head its reader says it with, kept with it for the repeat key
  def self.say_dialogue_skip(message, head = nil)
    t = clean(message)
    @last_led = head ? led(head, t) : nil
    note_dialogue(@last_led || t)
    @last_say = t
    @last_say_t = (clock rescue 0)
  end
end

# Dialogue and messages, queued, through Kernel.pbMessageDisplay (gen 6) or the bare top-level one (modern). Which
# forms the game defines is asked before wrapping: the singleton wrap would create one the game never had.
pa_msg_singleton = (Kernel.respond_to?(:pbMessageDisplay) rescue false)
pa_msg_bare = (Object.private_method_defined?(:pbMessageDisplay) rescue false)

begin
  if pa_msg_singleton
    class << Kernel
      unless method_defined?(:pbMessageDisplay__access_orig)
        alias_method :pbMessageDisplay__access_orig, :pbMessageDisplay
        def pbMessageDisplay(msgwindow, message, *args, &block)
          paged = PokeAccess::DialoguePages.open(msgwindow, message, PokeAccess.letter_by_letter(args))
          PokeAccess.say_dialogue(message) unless paged
          PokeAccess.message_enter
          begin
            pbMessageDisplay__access_orig(msgwindow, message, *args, &block)
          ensure
            PokeAccess.message_leave
            PokeAccess::DialoguePages.close(msgwindow) if paged
          end
        end
        PokeAccess::Hooks.pass_keywords(self, :pbMessageDisplay)
        PokeAccess.note_dialogue_wrap(:singleton)
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_text: #{e.message}\n")
end

# The bare function, wrapped on every modern game and on a gen-6 game without the singleton: where both exist, one
# delegates to the other, so the era picks which to wrap. Splat args absorb signature differences.
begin
  if pa_msg_bare && (!pa_msg_singleton || PokeAccess::Engine.gamedata?)
    class Object
      unless private_method_defined?(:pbMessageDisplay__pa_inst) || method_defined?(:pbMessageDisplay__pa_inst)
        alias_method :pbMessageDisplay__pa_inst, :pbMessageDisplay
        def pbMessageDisplay(msgwindow, message, *args, &block)
          paged = PokeAccess::DialoguePages.open(msgwindow, message, PokeAccess.letter_by_letter(args))
          PokeAccess.say_dialogue(message) unless paged
          PokeAccess.message_enter
          begin
            pbMessageDisplay__pa_inst(msgwindow, message, *args, &block)
          ensure
            PokeAccess.message_leave
            PokeAccess::DialoguePages.close(msgwindow) if paged
          end
        end
        PokeAccess::Hooks.pass_keywords(self, :pbMessageDisplay)
        private :pbMessageDisplay, :pbMessageDisplay__pa_inst
        PokeAccess.note_dialogue_wrap(:bare)
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_text_modern: #{e.message}\n")
end
