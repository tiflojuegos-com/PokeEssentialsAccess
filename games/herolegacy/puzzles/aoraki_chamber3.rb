# Mt. Aoraki, chamber 3 (map 362): eight Strength boulders and eleven tiles a parallel event checks for them. A boulder
# on its tile turns a switch on: 155, 157, 158, 159 and 161 break ice blocks for good; 151 to 154, 156 and 160 lower
# spikes (151 and 160 also break blocks) and raise them again once the boulder leaves. The four spikes of column 21
# (switches 151 to 154) close the way to Frigometri (21, 9), who ends the chamber (switch 146). The engine keeps a
# pushed event off ice, so boulders only move over rock. The order of the boulders is given with the assist alone. The
# switch tiles are drawn with the caves' tile 439, here, in chamber 2 (map 361) and on the way in (map 358), and the free
# camera names each.
module PokeAccess
  module HeroLegacySwitchChamber
    SWITCH_TILE = 439
    SWITCH_MAPS = [358, 361, 362]

    # True where the map draws a switch tile on any layer.
    def self.switch_tile?(x, y)
      (0...3).any? { |z| $game_map.data[x, y, z] == SWITCH_TILE }
    end

    # Each boulder, where it stands then, the tile it goes to and the switch, in an order whose every push plan was
    # found against the map, each from the entrance (21, 24); three boulders serve two tiles in turn.
    STEPS = [[3, [21, 19], [21, 17], 151], [13, [16, 21], [12, 20], 155], [13, [12, 20], [10, 17], 156],
             [23, [8, 11], [8, 10], 157], [23, [8, 10], [13, 13], 152], [31, [15, 15], [12, 5], 158],
             [24, [24, 5], [30, 9], 159], [49, [33, 18], [28, 15], 160], [51, [26, 19], [27, 15], 161],
             [58, [28, 13], [27, 10], 154], [31, [12, 5], [21, 5], 153]]
  end
end

PokeAccess::Game.define("herolegacy") do
  mechanic(:state, 362) do
    auto
    name(/\ASpikes\z/, :hl_spikes)
    name(/\AEisblock/, :hl_ice_block)
    PokeAccess::HeroLegacySwitchChamber::STEPS.each do |step|
      ev, from, goal, sw = step
      phase lambda { PokeAccess::Puzzles.assist? && !$game_switches[sw] && !$game_switches[146] }, :quiet => true,
            :hint => [:hl_boulder_to, { :x => from[0], :y => from[1], :gx => goal[0], :gy => goal[1] }],
            :track => { :event => ev, :label => :hl_boulder, :goal => [goal[0], goal[1], goal[0], goal[1]],
                        :goal_label => :hl_switch_tile }
    end
    arrival_hint :hl_q3_rule
    solved { $game_switches[146] }
  end
  switches = PokeAccess::HeroLegacySwitchChamber
  camera_tile(:maps => switches::SWITCH_MAPS, :tiles => lambda { |x, y| switches.switch_tile?(x, y) }) do |_x, _y|
    PokeAccess::I18n.t(:hl_switch_tile)
  end
end
