# Ashen Frost's 16 Floor House (map 772, Case Twenty): the entrance stairs (EV2) set variable 346 to 2 and lead to one
# floor drawn once, where the stairs up (EV4) add 1 and the stairs down (EV3) take 1; at 16 they lead to the top, where
# the owner (EV8) sets 17 and counts the house in variable 353. The assist adds the floor and the climbs left.
module PokeAccess
  module AshenSixteenFloors
    MAP = 772
    FLOOR = 346
    TOP = 16
    UP = [2, 4]
    DOWN = [3, 5]
    STAIRS_X = [13, 19]
    OWNER = 8

    # The floor variable's value.
    def self.floor
      $game_variables[FLOOR].to_i
    end

    # Whether the owner has been reached.
    def self.done?
      floor > TOP
    end

    # The assist's line: the climbs left on the stairs' floor, else the owner at the top or the stairs at the entrance.
    def self.hint
      return nil if done?
      x = $game_player.x
      return :afd_floors_owner if x > STAIRS_X[1]
      return :afd_floors_start if x < STAIRS_X[0]
      [:afd_floors_climb, { :floor => floor, :n => TOP - floor }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  floors = PokeAccess::AshenSixteenFloors
  mechanic(:state, floors::MAP, :part => :afd_floors) do
    auto
    name floors::UP, :afd_floors_up, :when => lambda { |_ev| !floors.done? }
    name floors::DOWN, :afd_floors_down, :when => lambda { |_ev| !floors.done? }
    hint lambda { floors.hint }
    active { !floors.done? }
    solved(nil, :quiet => true) { floors.done? }
  end
end
