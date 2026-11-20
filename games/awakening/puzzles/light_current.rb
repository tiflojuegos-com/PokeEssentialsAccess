# The light currents of the Water shrine (map 220) and the Fire shrine (map 340): terrain 19 drawn as a stream of light
# from the entry to a door. With switch 115 on, a parallel event turns it off as soon as the player stands off the
# current, and the door then only speaks; a self switch A of the event that checks the door's tile marks it walked.
# The current and the ground beside it are said underfoot; with the puzzle assist the routes keep to the current while
# it is lit, and once it is out a phase says how to light it again.
module PokeAccess
  module AwakeningLight
    # map => [the event whose self switch A marks the current walked, the box of its side of the map, its lit test]
    MAPS = { 220 => [1, [27, 44, 0, 44], lambda { $game_self_switches[[219, 2, "A"]] }],
             340 => [4, [35, 59, 0, 34], lambda { $game_switches[212] }] }

    # True on a tile of the current.
    def self.current?(x, y); PokeAccess::World::Terrain.number(x, y) == 19; end

    # True on the current's side of a map with one.
    def self.side?(x, y)
      room = MAPS[$game_map.map_id]
      return false unless room
      x0, x1, y0, y1 = room[1]
      x >= x0 && x <= x1 && y >= y0 && y <= y1
    end

    # True once the current of this map has been walked to its end.
    def self.walked?
      room = MAPS[$game_map.map_id]
      room ? ($game_self_switches[[$game_map.map_id, room[0], "A"]] ? true : false) : false
    end

    # True while the current is lit and still to walk.
    def self.lit?; $game_switches[115] && !walked? ? true : false; end

    # True while the current is out though the way to light it is open: back through the entry and in again.
    def self.out?
      room = MAPS[$game_map.map_id]
      return false unless room && !walked? && !$game_switches[115] && room[2].call
      side?($game_player.x, $game_player.y)
    end
  end
end

PokeAccess::Game.define("awakening") do
  light = PokeAccess::AwakeningLight
  PokeAccess::World::Terrain.label_rule do |x, y|
    next nil unless light.side?(x, y)
    light.current?(x, y) ? :awk_light_on : :awk_light_off
  end
  terrain_rule(:maps => light::MAPS.keys, :tiles => lambda { |x, y| light.side?(x, y) && !light.current?(x, y) },
               :assist => true) do |_x, _y, _d|
    light.lit? ? false : nil
  end
  mechanic(:state, light::MAPS.keys, :part => :light) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? && light.out? }, :quiet => true, :hint => :awk_light_relight
    solved { light.walked? }
  end
end
