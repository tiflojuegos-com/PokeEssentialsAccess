# Balansopoli's Root Gym (map 93): halls of three doors, left, middle and right, each a pair of touch tiles with no sprite
# that moves the player to another room of the map. A sign in the hall marks the good door of the three with an O among
# Xs (events 37 and 63 in the first hall, 64 and 65 in the second); a wrong door leads to a room where a Trevenant (touch
# tiles 40 to 49) drives the player back to the entrance, saying so itself. The first badge (switch 27) ends it.
module PokeAccess
  module XenoRootGym
    MAP = 93
    LEFT = [5, 8, 21, 22]
    MIDDLE = [9, 10, 23, 24]
    RIGHT = [11, 12, 25, 26]
    ONWARD = [19, 20, 33, 34]
    BACK = [1, 6, 13, 14, 15, 16, 17, 18, 27, 28, 29, 30, 31, 32, 35]
    TREVENANT_TILES = [40, 41, 44, 45, 46, 47, 48, 49]
    SIGNS = [37, 63, 64, 65]
    FIRST_HALL = [0, 61, 104, 136]
    SECOND_HALL = [0, 61, 55, 90]
    BADGE = 27
  end
end

PokeAccess::Game.define("xenoverse") do
  root = PokeAccess::XenoRootGym
  mechanic(:state, root::MAP) do
    auto
    name root::LEFT, :xv_root_door_left, :grouped => true
    name root::MIDDLE, :xv_root_door_middle, :grouped => true
    name root::RIGHT, :xv_root_door_right, :grouped => true
    name root::ONWARD, :xv_root_door_onward, :grouped => true, :when => false
    name root::BACK, :xv_root_door_back, :grouped => true, :when => false
    name root::SIGNS, :xv_root_sign, :grouped => true
    hide root::TREVENANT_TILES
    phase at(*root::FIRST_HALL), :hint => :xv_root_hint_first
    phase at(*root::SECOND_HALL), :hint => :xv_root_hint_second
    solved { $game_switches[root::BADGE] }
  end
end
