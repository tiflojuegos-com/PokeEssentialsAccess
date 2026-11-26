# Rhodochrine Jungle (map 150), variable 77 below 4: three Team Meteor grunts (events 63 to 65) stand by the way north
# and eight graphic-less tiles (69 to 76) set 77 to 4, which has event 66 throw the player into the Nuzleaf cage. Switch
# 1786, set by either entrance tile (events 67 and 68), starts the watch. WAY is a route past the eight tiles.
module PokeAccess
  module RebornStealth
    FACING = { 2 => :rbf_grunt_down, 4 => :rbf_grunt_left, 6 => :rbf_grunt_right, 8 => :rbf_grunt_up }
    WAY = [[118, 101], [117, 101], [116, 101], [115, 101], [114, 101], [114, 100], [113, 100], [113, 99], [112, 99],
           [112, 98], [112, 97], [113, 97], [113, 96], [113, 95]]
    LOWER_ENTRANCE = [118, 102]
    PRESS = { [0, 1] => 2, [-1, 0] => 4, [1, 0] => 6, [0, -1] => 8 }

    # True while the grunts can still catch the player.
    def self.watching?
      $game_variables[77].to_i < 4
    end

    # The presses that walk a run of tiles, as said ("4 left, 1 up").
    def self.steps(tiles)
      presses = (0...tiles.length - 1).map do |k|
        PRESS[[tiles[k + 1][0] - tiles[k][0], tiles[k + 1][1] - tiles[k][1]]]
      end
      PokeAccess::Routes::Text.steps(presses)
    end

    # With the assist, the safe way on from where the player stands: along WAY from its tile, from the lower entrance
    # tile by first stepping up onto it, from anywhere else the whole way from the upper one; nil once north of it all.
    def self.hint
      at = [$game_player.x, $game_player.y]
      return nil if at[1] <= WAY.last[1]
      i = WAY.index(at)
      return [:rbf_stealth_hint, { :steps => steps(WAY[i..-1]) }] if i
      return [:rbf_stealth_hint, { :steps => steps([LOWER_ENTRANCE] + WAY) }] if at == LOWER_ENTRANCE
      [:rb2_stealth_hint_entrance, { :steps => steps(WAY) }]
    end
  end
end

PokeAccess::Game.define("reborn") do
  stealth = PokeAccess::RebornStealth
  mechanic(:state, 150, :part => :meteor_stealth) do
    auto
    name 63..65, lambda { |ev| stealth.watching? ? stealth::FACING[ev.direction] : nil }
    avoid 69..76, :assist => true
    watch :switch => 1786, :say => lambda { stealth.watching? ? :rbf_stealth_rule : nil }
    phase lambda { stealth.watching? && $game_switches[1786] }, :quiet => true,
          :hint => lambda { stealth.hint }
    active { stealth.watching? && $game_switches[1786] }
  end
end
