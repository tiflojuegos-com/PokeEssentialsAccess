# The Dionysus Palace in Siracusa: on its upper floor (map 64) a chest on rails, EV1, slides by itself to another stretch
# of rail when used facing it from one side; V81 is the stretch it stands on, 7 a dead end (leaving the floor puts it
# back, EV3) and 8 the goal, which moves the sword out of the banquet hall's door on the floor below (map 63, EV13 to
# EV16 on column 17), where the cup the play needs is kept. PUSHES holds, for each stretch, the tile the chest is used
# from and the way the player faces there, on the shortest way to the goal.
module PokeAccess
  module AfricanusRailChest
    UPPER = 64
    HALL = 63
    CHEST = 1
    SWORD = 13
    STRETCH = 81
    STUCK = 7
    GOAL = 8
    PUSHES = { 0 => [[11, 8], :af_rail_push_right], 1 => [[17, 6], :af_rail_push_right],
               2 => [[25, 6], :af_rail_push_right], 3 => [[28, 7], :af_rail_push_up],
               4 => [[30, 6], :af_rail_push_left], 5 => [[21, 3], :af_rail_push_down] }

    # The stretch of rail the chest stands on.
    def self.stretch
      $game_variables[STRETCH].to_i
    end

    # Whether the chest has reached the goal.
    def self.done?
      stretch >= GOAL
    end
  end
end

PokeAccess::Game.define("africanus") do
  chest = PokeAccess::AfricanusRailChest
  mechanic(:state, chest::UPPER) do
    auto
    name chest::CHEST, :af_rail_chest
    arrival_hint :af_rail_rule, :once => true
    phase lambda { chest.stretch == chest::STUCK }, :title => :af_rail_stuck, :hint => :af_rail_stuck_hint
    chest::PUSHES.each do |stretch, (tile, push)|
      phase lambda { chest.stretch == stretch }, :hint => push
      spot :at => tile, :label => :af_rail_push_here, :assist => true, :onto => true,
           :when => lambda { chest.stretch == stretch }
    end
    solved(nil) { chest.done? }
  end
  mechanic(:state, chest::HALL) do
    auto
    name chest::SWORD, :af_palace_sword
    hint :af_palace_sword_hint
    solved(nil) { chest.done? }
  end
end
