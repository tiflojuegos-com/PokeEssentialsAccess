# Opalo's trap floor: the game sends a player who steps on terrain tag 4 (PBTerrain::Rock) back to the entrance of
# its psychic gym (map 36; 21,69), whatever the map, so no route steps on it and it is named as a trap. In the gym a
# sensor lights the safe path for a step: each light is said as it goes on and off, and the traps' rule on entering.
module PokeAccess
  module OpaloTraps
    GYM_MAP = 36
    # The gym's path lights: switch 313 over the three fields on the way to the leader, 314 over the northern one.
    LIGHTS = [[313, :op_lights], [314, :op_lights_north]]

    @lights = nil

    # True where (x,y) is trap floor.
    def self.trap?(x, y)
      PokeAccess::Terrain.kind(x, y) == :rock
    end

    # Once per frame: on the gym's map, the traps' rule on entering (while hints are said) and each light as it goes
    # on or off, queued; elsewhere forgets the lights, so the next visit starts afresh.
    def self.poll
      unless ($game_map.map_id rescue nil) == GYM_MAP
        @lights = nil
        return
      end
      if @lights.nil?
        @lights = {}
        LIGHTS.each { |sw, _key| @lights[sw] = lit?(sw) }
        PokeAccess.speak(PokeAccess::I18n.t(:op_traps_hint), false) if PokeAccess::Verbosity.hints?
        return
      end
      LIGHTS.each do |sw, key|
        on = lit?(sw)
        next if on == @lights[sw]
        @lights[sw] = on
        PokeAccess.speak("#{PokeAccess::I18n.t(key)}: #{PokeAccess::I18n.t(on ? :op_lights_on : :op_lights_off)}", false)
      end
    rescue StandardError
      nil
    end

    # Whether a light's switch is on.
    def self.lit?(switch)
      ($game_switches[switch] rescue false) ? true : false
    end
  end
end

PokeAccess::Game.define("opalo") do
  terrain_rule { |x, y, _d| PokeAccess::OpaloTraps.trap?(x, y) ? false : nil }

  override(PokeAccess::Terrain, :label) do |_mod, original, args|
    PokeAccess::OpaloTraps.trap?(args[0], args[1]) ? :op_trap : original.call
  end

  poll_each_frame { PokeAccess::OpaloTraps.poll }
end
