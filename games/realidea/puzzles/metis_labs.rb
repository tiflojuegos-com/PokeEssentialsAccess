# Metis Labs: the four levers of the first floor (map 18), told apart by their colour (levers.rb), which must be pulled in
# order and are checked at the fourth (variable 115 counts them); the papers with A, B and C on floors 1, 2 and 3 (maps 18,
# 133 and 56); and the door of the ground floor (map 62), which asks for A+BxC. The levers' door open ends the first floor's
# rule and its count on the info key.
module PokeAccess
  module RealideaMetis
    LEVER_DOOR = [18, 12]
    KEYPAD_MAP = 62
    KEYPAD = 1
    KEYPAD_AT = [9, 28]
    # How far from the door the info key still speaks of it.
    NEAR = 12
    CLUES = [8, 9, 10]

    # True once the levers' door of the first floor is open.
    def self.door_open?
      $game_self_switches[[LEVER_DOOR[0], LEVER_DOOR[1], "A"]] ? true : false
    end

    # What the lever count falling to none says: that the door opened, or that the order was wrong.
    def self.levers_reset
      door_open? ? :rea_metis_opened : :rea_metis_wrong
    end

    # True while the player is near the door of the ground floor and it has not opened.
    def self.near_keypad?
      return false if $game_self_switches[[KEYPAD_MAP, KEYPAD, "A"]]
      ($game_player.x - KEYPAD_AT[0]).abs + ($game_player.y - KEYPAD_AT[1]).abs <= NEAR
    end
  end
end

PokeAccess::Game.define("realidea") do
  metis = PokeAccess::RealideaMetis
  mechanic(:state, 18) do
    auto
    count :rea_levers_pulled, :var => 115, :of => 4, :reset => lambda { metis.levers_reset }
    name metis::CLUES, :rea_metis_clue
    name 6, :rea_metis_paper
    arrival_hint :rea_metis_rule
    solved { metis.door_open? }
    hint :rea_metis_hint
  end
  mechanic(:state, 133) do
    auto
    name 32, :rea_metis_paper
  end
  mechanic(:state, 56) do
    auto
    name 7, :rea_metis_paper
  end
  mechanic(:state, metis::KEYPAD_MAP) do
    auto
    name metis::KEYPAD, :rea_metis_keypad
    info { :rea_metis_door_rule }
    active { metis.near_keypad? }
    hint :rea_metis_door_hint
  end
end
