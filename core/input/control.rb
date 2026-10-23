module PokeAccess
  # Whether the player has free control on the map, checked in this order: screens holding it while their loop runs
  # (hold), the pulse's watch on the scene and a stalled map, registered conditions (condition) and the engine's flags.
  # Each reason has a scope: :hold quiets cues, guides and soundscape, :keys locks the locator keys, :both does both.
  # Evaluated each map frame, on changed! and on a scene change or stall; emits :control_lost and :control_regained.
  module Control
    @holds = []
    @conditions = []
    @carriers = []
    @memo = {}
    @held = nil
    @watched = [true, false]

    # Registers a polled condition; registering a reason again replaces it.
    # param scope :hold, :keys or :both
    def self.condition(reason, scope = :both, &probe)
      @conditions.reject! { |c| c[0] == reason }
      @conditions.push([reason, scope, probe])
      reason
    end

    # Holds control for a reason while the block runs (a screen's own blocking loop), with the transitions fired at
    # once on the way in and out.
    def self.hold(reason, scope = :both)
      @holds.push([reason, scope])
      changed!
      yield
    ensure
      i = @holds.rindex { |h| h[0] == reason }
      @holds.delete_at(i) if i
      changed!
    end

    # Re-evaluates now and fires the transition, for a change the frame would only see later: an engine flag's setter,
    # a battle starting, a module's own screen opening. Never raises into the engine code it is called from.
    def self.changed!
      @memo = {}
      transition
    rescue StandardError => e
      PokeAccess.log_once("control_changed", e)
      nil
    end

    # The first reason that holds the player in a scope (:hold or :keys), or nil; inside a map frame, asked once per
    # frame and scope, every step sharing the answer, unless a modal loop opened from a step pulses meanwhile.
    def self.reason(scope = :hold)
      return find(scope) unless PokeAccess::Frame.running?
      key = [PokeAccess::Frame.serial, PokeAccess::Frame.pulses, scope]
      return @memo[key] if @memo.key?(key)
      @memo[key] = find(scope)
    end

    # True while nothing holds the cues, the guides and the soundscape.
    def self.free?; reason(:hold).nil?; end

    # True while nothing locks the locator keys.
    def self.keys?; reason(:keys).nil?; end

    # The tile right in front of the player, by the way they face.
    def self.front_tile
      d = PokeAccess::DIR_DELTA[$game_player.direction] || [0, 0]
      [$game_player.x + d[0], $game_player.y + d[1]]
    end

    # The map event on a tile, or nil: any tile of an event with a size, as the engine's at_coordinate? finds it to act.
    def self.event_at(x, y)
      return nil unless $game_map
      r = PokeAccess::World::Events.at(x, y).first
      r ? r.ev : nil
    end

    # Registers a plugin's probe, true while it moves the player along by itself (a spin tile's spin, a rock climb);
    # registering a name again replaces it.
    def self.carrier(name, &probe)
      @carriers.reject! { |c| c[0] == name }
      @carriers.push([name, probe])
      name
    end

    # True while a registered plugin moves the player along (see carrier).
    def self.carrier?
      @carriers.any? { |_n, probe| (probe.call rescue false) ? true : false }
    end

    # How the player moves this frame: :forced (a move route the game drives, or a plugin's carrier), :sliding (see
    # sliding?), :jumping, :moving (a step the player took) or :still.
    def self.motion
      p = $game_player
      return :still if p.nil?
      return :forced if flag(p, :move_route_forcing) || carrier?
      return :sliding if sliding?
      return :jumping if flag(p, :jumping?)
      flag(p, :moving?) ? :moving : :still
    end

    # True while an ice slide carries the player: the engine's flag (sliding up to v20, ice_sliding in v21), or the
    # frame they step onto ice before it is set, where the step on from it is open, as every engine checks to slide.
    def self.sliding?
      g = $PokemonGlobal
      return true if flag(g, :sliding) || flag(g, :ice_sliding)
      p = $game_player
      return false unless flag(p, :moving?) && PokeAccess::World::Terrain.ice?(p.x, p.y)
      PokeAccess::World::Probe.step?(p.x, p.y, p.direction)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # True while the engine carries the player on by itself: an ice slide (sliding?), v21's forced movement (a
    # waterfall's descent or climb, a plugin's whirlpool) or a plugin's carrier (a spin, a rock climb).
    def self.carried?
      sliding? || flag($PokemonGlobal, :forced_movement?) || carrier?
    end

    # True on the map scene with a map and a player and no menu open over it.
    def self.on_map?
      return false unless $game_map && $game_player && scene_map?
      !flag($game_temp, :in_menu)
    end

    # True while the scene is the map; also true where the engine has no map scene to tell.
    def self.scene_map?
      !defined?(::Scene_Map) || $scene.is_a?(::Scene_Map)
    end

    # True while a message or menu loop updates the map: $game_temp.in_mini_update (v21) or $PokemonTemp.miniupdate.
    def self.mini_update?
      flag($game_temp, :in_mini_update) || flag($PokemonTemp, :miniupdate)
    end

    # The map frame's evaluation, once the world stage has settled: the frame's answer asked afresh, and the
    # transition since the last check.
    def self.evaluate
      @memo = {}
      transition
    end

    # The pulse's check, every frame in every scene: leaving the map scene, or a screen looping over the map until it
    # stalls, is a transition the map frame cannot see, since it stops running.
    def self.pulse
      now = [scene_map?, PokeAccess::Frame.stalled?]
      return if now == @watched
      @watched = now
      changed!
    end

    # The first reason in a scope: the innermost hold, then the scene, a stalled map, a battle, the registered
    # conditions and the engine's flags.
    def self.find(scope)
      @holds.reverse_each { |r, s| return r if covers?(s, scope) }
      return :other_scene unless scene_map?
      return :stalled if PokeAccess::Frame.stalled?
      return :battle if scope == :hold && (PokeAccess::Battle.in_battle? rescue false)
      @conditions.each { |r, s, probe| return r if covers?(s, scope) && (probe.call rescue false) }
      engine_reason(scope)
    end

    # The engine's flags as reasons: a message holds the cues but leaves the locator keys free, and a reduced update
    # with no message locks the keys only.
    def self.engine_reason(scope)
      t = $game_temp
      message = flag(t, :message_window_showing)
      return :message if scope == :hold && message
      return :in_menu if flag(t, :in_menu)
      return :in_battle if flag(t, :in_battle)
      mini = mini_update?
      return :mini_update if scope == :hold && mini
      return :overlay if scope == :keys && mini && !message
      return nil unless scope == :hold
      return :move_route if flag($game_player, :move_route_forcing)
      interp = ($game_system.respond_to?(:map_interpreter) ? $game_system.map_interpreter : nil) if $game_system
      flag(interp, :running?) ? :interpreter : nil
    end

    # Whether a reason of one scope applies to the scope asked.
    def self.covers?(scope, asked)
      scope == :both || scope == asked
    end

    # An engine object's boolean reader, false where the object or the reader is missing, without raising.
    def self.flag(obj, meth)
      obj && obj.respond_to?(meth) && obj.send(meth) ? true : false
    end

    # Emits :control_lost or :control_regained when the hold reason starts or stops.
    def self.transition
      now = reason(:hold)
      was = @held
      @held = now
      if now && was.nil?
        PokeAccess::Events.emit(:control_lost, now)
      elsif now.nil? && was
        PokeAccess::Events.emit(:control_regained, was)
      end
      now
    end
  end
end

# The engine's battle and menu flags change control at once: the map frame does not run under a menu that never
# updates the map, nor while a battle runs. Insurgence has no menu flag.
PokeAccess::Hooks.after_hook("Game_Temp", :in_battle=) { |_t, _r, _args| PokeAccess::Control.changed! }
PokeAccess::Hooks.after_hook("Game_Temp", :in_menu=, :optional => true) { |_t, _r, _args| PokeAccess::Control.changed! }
