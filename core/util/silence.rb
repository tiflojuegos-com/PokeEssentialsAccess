module PokeAccess
  # Watches for a screen that came up and said nothing, and writes what it saw into the diagnostic.
  #
  # This is the one failure the mod cannot find on its own. A reader that raises leaves a line in the log; a
  # reader that binds to the wrong ivar, the wrong page or the wrong moment leaves nothing at all -- the
  # screen is simply quiet, and quiet is indistinguishable from "there was nothing to say". Every silent
  # screen fixed so far was found by a person noticing it, which means it had already cost them the screen.
  #
  # So the mod notices instead: a new screen, then WINDOW frames without a single line spoken, and the pair
  # goes in a list the diagnostic prints. That turns an ordinary play session into a report -- press the
  # diagnostic key after playing and the screens that never spoke are named, whether or not the player
  # thought to check each one.
  #
  # This is EVIDENCE, not a fault. Plenty of screens are legitimately silent for two seconds: an animation,
  # a cutscene, a map you walk across without passing anything. What matters is a screen in this list that
  # the player knows they were navigating.
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
      # Anything spoken at all clears the watch: the screen has a voice, and whether every part of it does
      # is not something a frame counter can answer.
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
