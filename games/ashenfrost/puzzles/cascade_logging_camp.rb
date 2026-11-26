# Ashen Frost's Cascade Logging Camp (Case Ten): on the camp (map 54) the hatchet (EV1, twin EV2) opens the log east
# (EV8). As Mordecai (switch 83), the Purrloin (variable 122) is chased to the well edge (EV13), then up the Abandoned
# Tunnels (map 56) to Eloise's studio (EV36), where the chase ends (122 at 4).
module PokeAccess
  module AshenLoggingCamp
    CAMP = 54
    TUNNELS = 56
    HATCHETS = [1, 2]
    CROSSING = 8
    WELL_EDGE = 13
    PURRLOIN = 12
    PLATFORMS = [18, 30, 35]
    STUDIO = 36
    MORDECAI = 83
    CHASE = 122

    # Whether a self switch of the camp's event is on.
    def self.on?(ev, letter = "A")
      $game_self_switches[[CAMP, ev, letter]] ? true : false
    end

    # Whether the hatchet has been taken from its stump.
    def self.hatchet_taken?; on?(HATCHETS[0]); end

    # Whether the hatchet errand is on: Sylvester on the camp, the crossing east not yet made with it.
    def self.errand?
      !$game_switches[MORDECAI] && !on?(CROSSING)
    end

    # Whether Mordecai is chasing the Purrloin on the camp: the key taken, the well not yet fallen into.
    def self.chasing?
      v = $game_variables[CHASE].to_i
      $game_switches[MORDECAI] && v >= 1 && v < 3 ? true : false
    end

    # A stump's name: with the hatchet in it until taken.
    def self.stump_label
      hatchet_taken? ? :afb_stump : :afb_hatchet
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  camp = PokeAccess::AshenLoggingCamp
  mechanic(:state, camp::CAMP) do
    auto
    name camp::HATCHETS, lambda { |_e| camp.stump_label }, :grouped => true
    name camp::WELL_EDGE, :afb_well_edge, :when => lambda { |_e| camp.chasing? }
    phase lambda { PokeAccess::Puzzles.assist? && camp.errand? && !camp.hatchet_taken? },
          :hint => :afb_camp_hatchet, :hidden => right_way(camp::HATCHETS[0])
    phase lambda { PokeAccess::Puzzles.assist? && camp.errand? && camp.hatchet_taken? },
          :hint => :afb_camp_back, :hidden => right_way(camp::CROSSING)
    phase lambda { PokeAccess::Puzzles.assist? && camp.chasing? }, :hint => :afb_camp_purrloin,
          :hidden => right_way(camp::WELL_EDGE)
  end

  mechanic(:state, camp::TUNNELS) do
    auto
    name camp::PLATFORMS, :afb_platform
    arrival_hint :afb_tunnels_hops
    phase lambda { PokeAccess::Puzzles.assist? && $game_variables[camp::CHASE].to_i == 3 },
          :hint => :afb_tunnels_studio, :hidden => right_way(camp::STUDIO)
    solved(nil, :quiet => true) { $game_variables[camp::CHASE].to_i >= 4 }
  end
end
