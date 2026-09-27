module PokeAccess
  # The screen reader that games of the engine Reborn and Rejuvenation share carry inside: a global tts(text,
  # interrupt) over $tts, to which Rejuvenation adds a lowercase: keyword. Two readers would talk over each other, so
  # while the mod can speak the game's is muted, and what the game hands tts on the screens a profile names is said by
  # the mod. Nothing binds until a profile installs it; Desolation has no such reader.
  module OwnVoiceRV
    @live = []
    @last_frame = nil
    @always = []
    @always_frame = nil
    @active = false

    # Mutes the game's reader, but only once the mod's own voice is up: without it the game's is all there is.
    def self.mute
      return if $tts.nil?
      return unless PokeAccess.init_speech!
      $tts = nil
    rescue StandardError
      nil
    end

    # A relayed screen comes up: what it hands tts is said until leave.
    def self.enter
      @live.push(PokeAccess.message_depth)
      @last_frame = nil
    end

    def self.leave; @live.pop; end

    # Whether one of those screens is up.
    def self.relaying?; !@live.empty?; end

    # Runs a block as one of those screens; as it is while no profile installed the relay.
    def self.relayed
      return yield unless @active
      enter
      begin
        yield
      ensure
        leave
      end
    end

    # The interrupt flag tts got. A Hash in its place is the keywords (tts(text, lowercase: false)), not the flag.
    def self.interrupt_flag(arg)
      (arg.nil? || arg == false || arg.is_a?(Hash)) ? false : true
    end

    # The text without the private-use placeholders the game's own tts strips (TextPlaceholders, where it has them).
    def self.speakable(text)
      t = text.to_s
      return t unless defined?(TextPlaceholders) && TextPlaceholders.respond_to?(:removeFrom)
      (TextPlaceholders.removeFrom(t) rescue t).to_s
    end

    # One line the game handed its reader, said while a relayed screen is up and no message sits on it (the dialogue
    # reader says those); a line matching an always pattern is said anywhere, the first of its frame cutting in and
    # the rest of that frame queued behind it (an event's script may say several at once). On a relayed screen the
    # first line of a later frame cuts in, as a cursor move does; the rest of that frame queues behind it.
    def self.relay(text, interrupt = false)
      return unless @active
      t = speakable(text)
      return if t.strip.empty?
      if @live.empty?
        return unless @always.any? { |re| t =~ re }
        now = (Graphics.frame_count rescue 0)
        cut = @always_frame != now
        @always_frame = now
        PokeAccess.speak_clean(t, cut)
        return
      end
      return if PokeAccess.message_depth > @live.last
      now = (Graphics.frame_count rescue 0)
      cut = interrupt || (!@last_frame.nil? && now != @last_frame)
      @last_frame = now
      PokeAccess.speak_clean(t, cut ? true : false)
    rescue StandardError
      nil
    end

    # A message the game shows after saying it itself (tts: false) while its screen is relayed: the line was just
    # said, so the dialogue reader lets it pass in silence.
    def self.said_already(args)
      opts = args.last
      return unless relaying? && opts.is_a?(Hash) && opts[:tts] == false
      PokeAccess.say_dialogue_skip(args[0].to_s)
    rescue StandardError
      nil
    end

    # Installs the relay for a profile: mutes the game's reader, follows its tts, and runs the profile's screens as
    # relayed. The field notes and the time and weather app have readers of the mod's own (FieldNotesRV, TimeWeatherRV).
    # param screens [class name, method] pairs of the game's own screens with no reader of the mod's
    # param always patterns of lines said on any screen (Reborn's Blindstep coordinates)
    def self.install(screens = [], always = [])
      @active = true
      @always = always
      mute
      follow_tts
      screens.each do |cname, meth|
        PokeAccess::Hooks.around_hook(cname, meth, :optional => true) do |_s, nxt, _a|
          PokeAccess::OwnVoiceRV.relayed { nxt.call }
        end
      end
    end

    # Leaves the gen-6 nest page (PokemonNestMapScene) to a game that says its places itself: the mod's own reading of
    # it stands down, and the profile relays the page.
    def self.leave_nest_to_game
      PokeAccess::Hooks.override("PokeAccess::DexEntry", :gen6_area, :tag => "rv_own_voice") { |_m, _o, _a| nil }
    end

    # Follows the game's tts and the messages it shows after saying them; bound once, since each wrap adds a body.
    def self.follow_tts
      return if @following
      @following = true
      PokeAccess::Hooks.wrap_global("tts", "rv_own_voice_relay", :before) do |args, _r|
        PokeAccess::OwnVoiceRV.relay(args[0], PokeAccess::OwnVoiceRV.interrupt_flag(args[1]))
      end
      PokeAccess::Hooks.wrap_kernel("pbMessage", "rv_own_voice_said", :before) do |args, _r|
        PokeAccess::OwnVoiceRV.said_already(args)
      end
    end
  end
end
