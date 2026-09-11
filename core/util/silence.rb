module PokeAccess
  # Watches for a screen that came up and said nothing, and writes what it saw into the diagnostic: a reader
  # bound to the wrong ivar or the wrong moment leaves no trace, so a new screen followed by WINDOW frames
  # without a line spoken goes in a list the diagnostic prints. EVIDENCE, not a fault: an animation or a
  # cutscene is legitimately silent, and what matters is a screen the player knows they were navigating.
  module Silence
    # Two seconds at 60fps. Long enough that a screen with a reader has always spoken by then (readers fire
    # on the opening frame or the first cursor move), short enough that a screen the player opened and
    # closed quickly is still caught.
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

    # Which screen the player is on. Hooks.screen -- the class whose hooked method ran last -- rather than
    # $scene, because a screen with its own blocking loop is never assigned to $scene: through a whole
    # minigame $scene still answers Scene_Map, and those are exactly the screens most likely to be silent.
    # $scene is the fallback for the stretch before any hook has fired.
    def self.current
      s = (PokeAccess::Hooks.screen rescue nil)
      return s if s && !s.to_s.empty?
      ($scene.class.to_s rescue nil)
    end

    # One frame of the silence watch: a screen that has just come up gets WINDOW frames to say something,
    # and is noted if it never does. Anything spoken at all clears the watch -- the screen has a voice, and
    # whether every part of it does is not something a frame counter can answer.
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

    # Capped and deduped, like the suppressed-hook list: it must never grow with playtime.
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
