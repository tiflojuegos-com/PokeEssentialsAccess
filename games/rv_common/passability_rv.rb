module PokeAccess
  # The passability of the engine Reborn, Rejuvenation and Desolation share (Game_Map#playerPassable?) reads only the
  # lava surf, the Tauros ride and Blindstep (the probe's mode) besides tiles, events and vehicle; on Tauros it refuses
  # what the player faces, so the probe asks from each step's origin. Pushes take the loose check and slide on ice.
  module PassabilityRV
    # The state the engine's passability reads besides the tiles, the events and the vehicle.
    def self.state
      lava = ($PokemonGlobal.lavasurfing rescue nil) ? true : false
      [lava, tauros?, ($game_switches[:Blindstep] rescue nil) ? true : false]
    end

    # True while the player rides Tauros.
    def self.tauros?
      ($game_switches[:Riding_Tauros] rescue nil) ? true : false
    end

    # Declares the state and the placement to the world's probe.
    def self.bind
      PokeAccess::World::Probe.mode_reader { PokeAccess::PassabilityRV.state }
      PokeAccess::World::Probe.place_player_when { PokeAccess::PassabilityRV.tauros? }
      PokeAccess::World::Probe.plain!
      PokeAccess::World::Probe.loose_pushes!
      PokeAccess::Routes::Pushes.sliding_rocks!
    end
  end
end

PokeAccess::PassabilityRV.bind if PokeAccess::DataRV.engine?
