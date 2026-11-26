# Victory Road's falling traps. Map 787, variable 475 from 123: Fern's controller (event 77) drops event 76's target on
# the player while they stand at x 78 or less and y 30 or more. Map 784, 475 from 110 to 113: the ice controller (event
# 113) drops event 112 a tile below the player. Each hurts and throws the player two steps back.
module PokeAccess
  module RebornVrTraps
    PARK = [1, 0]
    BLINDSTEP = 2226
    TRAPS = { 787 => [76, :rbc_vr_arrow_mark, :rb3_dodge_tile], 784 => [112, :rbc_vr_ice_mark, :rb3_dodge_ice] }

    # True while the map's controller drops its targets.
    def self.on?(map)
      return false if $game_switches[BLINDSTEP]
      v = $game_variables[475].to_i
      map == 787 ? v >= 123 : (v >= 110 && v < 114)
    end

    # Each pulse on the map: says the trap's target once as it lands on or beside the player (targets wait at (1,0)
    # between drops; the ice hurts a cross of five tiles), and with the assist how to dodge it.
    def self.tick
      return unless $game_map && $game_player && PokeAccess::Control.scene_map?
      trap = TRAPS[$game_map.map_id]
      return unless trap
      ev = $game_map.events[trap[0]]
      return unless ev
      pos = [ev.x, ev.y]
      return if pos == @last
      @last = pos
      return if pos == PARK || !on?($game_map.map_id)
      return unless (ev.x - $game_player.x).abs + (ev.y - $game_player.y).abs <= 1
      dodge = PokeAccess::Puzzles.assist? ? PokeAccess::I18n.t(trap[2]) : nil
      PokeAccess.speak(PokeAccess.sentences([PokeAccess::I18n.t(trap[1]), dodge]), true)
    end

    # Forgets the last place seen, on a new map.
    def self.forget; @last = nil; end

    PokeAccess::Frame.each_pulse { PokeAccess::RebornVrTraps.tick } unless @pulsing
    @pulsing = true
  end
end

PokeAccess::Game.define("reborn") do
  traps = PokeAccess::RebornVrTraps
  traps::TRAPS.each do |map, trap|
    mechanic(:state, map, :part => :traps) do
      auto
      hide trap[0]
      arrival_hint lambda { traps.on?(map) ? (map == 787 ? :rbc_vr_arrow_rule : :rbc_vr_ice_rule) : nil }
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornVrTraps.forget }
