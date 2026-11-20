# The Lost Cave of Resort Gorgeous (Five Island): rooms of 20x15 with an invisible exit at the middle of each side, most of
# them back to the first room (map 94). The rocks drawn on each room's floor (tile 1626, upper layer; no events) tell the
# way, as the villager of map 93 says: 3 rocks east, 6 south, 9 west, 12 north. The last room (map 120) holds Petrel.
module PokeAccess
  module SeviiLostCave
    # Rooms with their drawn rocks (counted on the maps' tile layers) and the exit that goes on, by event id.
    ROOMS = { 94 => [3, 1], 97 => [12, 2], 100 => [0, nil], 101 => [6, 1], 102 => [6, 2], 103 => [0, nil],
              104 => [3, 1], 105 => [9, 2], 106 => [0, nil], 107 => [6, 1], 109 => [3, 2], 111 => [0, nil],
              119 => [12, 1] }
    # The exit events stand at the middle of each side.
    SIDES = { [6, 2] => :sevii_lost_north, [6, 10] => :sevii_lost_south, [10, 6] => :sevii_lost_east,
              [2, 6] => :sevii_lost_west }
    # The way each count points to.
    RULE = { 3 => :sevii_lost_east, 6 => :sevii_lost_south, 9 => :sevii_lost_west, 12 => :sevii_lost_north }

    # The exit's name by its side, or nil for an event off the middle of the sides.
    def self.exit_name(ev)
      side = SIDES[[ev.x, ev.y]]
      side ? [:sevii_lost_exit, { :side => PokeAccess::I18n.t(side) }] : nil
    end

    # What the room shows on arriving: its rocks.
    def self.arrival
      room = ROOMS[$game_map.map_id]
      return nil unless room
      room[0] > 0 ? [:sevii_lost_rocks, { :n => room[0] }] : :sevii_lost_no_rocks
    end

    # The assisted line: the side the count points to, or that the room is a dead end.
    def self.hint
      room = ROOMS[$game_map.map_id]
      return nil unless room
      side = RULE[room[0]]
      return :sevii_lost_dead_end unless side
      [:sevii_lost_hint, { :n => room[0], :side => PokeAccess::I18n.t(side) }]
    end
  end
end

PokeAccess::Game.define("sevii") do
  cave = PokeAccess::SeviiLostCave

  mechanic(:state, cave::ROOMS.keys) do
    auto
    name(/^tree$/, lambda { |ev| cave.exit_name(ev) })
    arrival_hint lambda { cave.arrival }
    hint lambda { cave.hint }
    info { cave.arrival }
    solved(nil, :quiet => true) { $game_switches[122] }
  end

  cave::ROOMS.each do |map, room|
    way = room[1]
    next unless way
    mechanic(:state, map, :part => :way) do
      auto
      spot :event => way, :label => :sevii_lost_way, :assist => true, :onto => true
    end
  end
end
