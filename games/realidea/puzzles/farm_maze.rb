# The maze of the Route 3 farm (maps 37 to 41): four rooms alike, each with four exits taken facing their way; one leads
# on and the rest back to the first room. Each room's sign says that its flowers tell the time: the clock in the middle
# of the room wears so many flowers of one colour (nine red, six purple, three yellow, twelve lilac), the hour, that the
# sign says is on time or three hours late. The right exits are left in the first room (9), right in the second (6 less
# 3), up in the third (3 less 3) and in the fourth (12); the fifth holds the Carnivine (switch 131).
module PokeAccess
  module RealideaFarm
    DONE = 131
    # The exit that leads on, by room: its event and the way it is taken.
    RIGHT = { 37 => [4, :dir_left], 38 => [3, :dir_right], 39 => [3, :dir_up], 40 => [3, :dir_up] }
    # The flowers of each room's clock: their colour's line and how many there are, read off the map's tiles.
    FLOWERS = { 37 => [:rea_farm_flowers_red, 9], 38 => [:rea_farm_flowers_purple, 6], 39 => [:rea_farm_flowers_yellow, 3],
                40 => [:rea_farm_flowers_lilac, 12] }
  end
end

PokeAccess::Game.define("realidea") do
  farm = PokeAccess::RealideaFarm
  farm::RIGHT.each do |map, right|
    mechanic(:state, map) do
      auto
      name right[0], :rea_farm_right_exit, :assist => true
      arrival_hint [farm::FLOWERS[map][0], { :n => farm::FLOWERS[map][1] }]
      active { !$game_switches[farm::DONE] }
      solved(nil, :quiet => true) { $game_switches[farm::DONE] }
      hint lambda { [:rea_farm_hint, { :way => PokeAccess::I18n.t(right[1]) }] }
    end
  end
end
