module PokeAccess
  # Lists for the diagnostic each screen that came up and spoke nothing for WINDOW frames: evidence of a reader
  # bound wrong, not a fault in itself (a cutscene is silent too).
  module Silence
    # Frames a new screen gets to speak: two seconds at 60 fps.
    WINDOW = 120
    MAX = 20

    @screen = nil
    @left = 0
    @mark = nil
    @seen = {}
    @order = []

    def self.reset
      @screen = nil
      @left = 0
      @mark = nil
      @seen = {}
      @order = []
    end

    # The screens that stayed quiet, in the order they were first seen.
    def self.quiet; @order; end

    # The screen the player is on: Hooks.screen (the class whose hooked method ran last), which sees blocking-loop
    # screens that $scene does not; $scene before any hook has fired.
    def self.current
      s = (PokeAccess::Hooks.screen rescue nil)
      return s if s && !s.to_s.empty?
      ($scene.class.to_s rescue nil)
    end

    # One frame of the watch: a new screen gets WINDOW frames to say something and is noted if it never does;
    # anything spoken clears the watch.
    def self.tick
      now = current
      return if now.nil? || now.empty?
      if now != @screen
        @screen = now
        @left = WINDOW
        @mark = spoken
        return
      end
      return if @left <= 0
      if spoken != @mark
        @left = 0
        return
      end
      @left -= 1
      note(now) if @left <= 0
    end

    def self.spoken
      (PokeAccess.spoken_seq rescue 0)
    end

    # Notes a quiet screen with its map id, deduped and capped at MAX.
    def self.note(name)
      return if @seen[name] || @order.length >= MAX
      @seen[name] = true
      @order.push("#{name}@#{($game_map.map_id rescue nil) || '?'}")
    end
  end
end

PokeAccess::Keys.on_frame { PokeAccess::Silence.tick }

PokeAccess::Keys.register_diag_section(:diag_silence, :scene) do |o|
  q = PokeAccess::Silence.quiet
  o.push("silent: #{q.empty? ? 'none' : q.join(', ')}")
end
