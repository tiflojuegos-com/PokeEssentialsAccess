# The Rangers' missions after the story, counted by variable 133 (which mission) and 134 (its progress, 99 once done).
# Moki Town (map 32, mission 7): the Xenomite (event 26) runs along a fixed path each time the player speaks to it,
# where to by the side spoken from and by variable 134, the spot it stands on; at 6 it is cornered.
# Nuclear Plant Omicron (map 112, mission 6): four Hazma (events 41 to 44) each slide two tiles the way the player faces
# when pressed, and go once one stands on the ball (35, 53). Angelure Town (map 225, mission 5): four Floatzel (events 41,
# 43, 46 and 47) slide five tiles, and go once one stands beside the Ranger (20 or 21, 31). The pushes of each, in turn,
# were searched from where they start against the maps' tiles and events.
module PokeAccess
  module UraniumRangers
    def self.mission?(number)
      $game_variables[133].to_i == number && $game_variables[134].to_i < 99
    end

    # The side to speak to the Xenomite from, by the spot it stands on, on the shortest way to the corner.
    def self.xenomite_sides
      { 0 => :ura_r2_xeno_above_or_left, 1 => :ura_r2_xeno_any, 2 => :ura_r2_xeno_any, 3 => :ura_r2_xeno_not_right,
        4 => :ura_r2_xeno_left, 5 => :ura_r2_xeno_left, 6 => :ura_r2_xeno_cornered, 7 => :ura_r2_xeno_not_above }
    end

    def self.xenomite_hint
      return "" unless mission?(7)
      xenomite_sides[$game_variables[134].to_i] || ""
    end

    # Each mission's Pokémon in the order planned, each with its pushes as [x, y, direction] from its starting tile.
    def self.plans
      { 112 => [[41, [[35, 42, 2], [35, 44, 2], [35, 46, 2], [35, 48, 2], [35, 50, 2], [35, 52, 2]]],
                [42, [[34, 41, 2], [34, 43, 2], [34, 45, 2], [34, 47, 2], [34, 49, 2], [34, 51, 2], [34, 52, 4],
                      [32, 52, 4], [31, 52, 8], [31, 50, 6], [33, 50, 6], [35, 50, 2], [35, 52, 2]]],
                [43, [[54, 39, 4], [52, 39, 4], [50, 39, 4], [48, 39, 2], [48, 41, 4], [46, 41, 2], [46, 43, 4],
                      [44, 43, 4], [42, 43, 4], [40, 43, 2], [40, 45, 6], [41, 45, 2], [41, 47, 4], [39, 47, 2],
                      [39, 49, 4], [37, 49, 4], [35, 49, 2], [35, 51, 2]]],
                [44, [[16, 40, 4], [15, 40, 8], [15, 38, 6], [17, 38, 6], [19, 38, 2], [19, 39, 6], [21, 39, 6],
                      [23, 39, 6], [25, 39, 6], [27, 39, 2], [27, 41, 6], [29, 41, 2], [29, 43, 6], [31, 43, 2],
                      [31, 45, 2], [31, 47, 2], [31, 49, 6], [33, 49, 6], [35, 49, 2], [35, 51, 2]]]],
        225 => [[41, [[20, 29, 2]]],
                [43, [[27, 12, 2], [27, 17, 4], [22, 17, 4], [17, 17, 2], [17, 22, 2], [17, 27, 2], [17, 29, 6],
                      [21, 29, 2]]],
                [46, [[34, 25, 8], [34, 20, 4], [29, 20, 4], [25, 20, 8], [25, 16, 4], [20, 16, 4], [15, 16, 2],
                      [15, 21, 2], [15, 26, 2], [15, 29, 6], [20, 29, 2]]],
                [47, [[37, 16, 4], [32, 16, 4], [27, 16, 2], [27, 17, 4], [22, 17, 4], [17, 17, 2], [17, 22, 2],
                      [17, 27, 2], [17, 29, 6], [21, 29, 2]]]] }
    end

    def self.missions; { 112 => 6, 225 => 5 }; end
    def self.pushes; { 2 => :ura_r2_push_down, 4 => :ura_r2_push_left, 6 => :ura_r2_push_right, 8 => :ura_r2_push_up }; end

    def self.delivered?(map, id)
      $game_self_switches[[map, id, "A"]] ? true : false
    end

    def self.active?(map)
      mission?(missions[map])
    end

    # The next push of the first Pokémon still out, as it stands now; off its planned way, asking the Ranger to start
    # over.
    def self.push_hint(map)
      return "" unless active?(map)
      found = (plans[map] || []).find { |id, _way| !delivered?(map, id) }
      return "" unless found
      id, way = found
      ev = $game_map.events[id]
      return "" unless ev
      step = way.find { |x, y, _dir| ev.x == x && ev.y == y }
      return :ura_r2_ranger_reset unless step
      [pushes[step[2]], { :x => ev.x, :y => ev.y }]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 32, :part => :xenomite) do
    auto
    name 26, :ura_r2_xenomite, :when => lambda { |ev| PokeAccess::UraniumRangers.mission?(7) }
    active { PokeAccess::UraniumRangers.mission?(7) }
    hint lambda { PokeAccess::UraniumRangers.xenomite_hint }
  end

  mechanic(:state, 112, :part => :hazma) do
    auto
    name((41..44).to_a, :ura_r2_hazma,
         :when => lambda { |ev| PokeAccess::UraniumRangers.active?(112) && !PokeAccess::UraniumRangers.delivered?(112, ev.id) })
    spot :at => [35, 53], :label => :ura_r2_hazma_ball, :when => lambda { PokeAccess::UraniumRangers.active?(112) }
    arrival_hint lambda { PokeAccess::UraniumRangers.active?(112) ? :ura_r2_hazma_rule : nil }
    active { PokeAccess::UraniumRangers.active?(112) }
    hint lambda { PokeAccess::UraniumRangers.push_hint(112) }
  end

  mechanic(:state, 225, :part => :floatzel) do
    auto
    name [41, 43, 46, 47], :ura_r2_floatzel,
         :when => lambda { |ev| PokeAccess::UraniumRangers.active?(225) && !PokeAccess::UraniumRangers.delivered?(225, ev.id) }
    spot :at => [21, 31], :label => :ura_r2_floatzel_goal, :when => lambda { PokeAccess::UraniumRangers.active?(225) }
    arrival_hint lambda { PokeAccess::UraniumRangers.active?(225) ? :ura_r2_floatzel_rule : nil }
    active { PokeAccess::UraniumRangers.active?(225) }
    hint lambda { PokeAccess::UraniumRangers.push_hint(225) }
  end
end
