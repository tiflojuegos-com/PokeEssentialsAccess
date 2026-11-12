# Celadon Sewers maps are identical in the inspected IF 6.8.2 and 6.9.1 data.
# The dry planks drop only from the east approach; walking under them is not a use.
# Their original interpreter performs the drop and all water changes.
PokeAccess::Game.define("infinitefusion") do
  [431, 446, 447, 448].each do |map|
    mechanic(:state, map, :part => :celadon_sewers) do
      auto
      watch :switch => 127, :label => :if_sewers_first_plank, :on => :if_sewers_lowered, :off => :if_sewers_raised
      watch :switch => 129, :label => :if_sewers_second_plank, :on => :if_sewers_lowered, :off => :if_sewers_raised
      watch :switch => 130, :label => :if_sewers_water_level, :on => :if_sewers_flooded, :off => :if_sewers_dry
      watch :switch => 128, :quiet => true
      controls
      hint :if_sewers_hint

      if map == 431
        hide [2, 4, 5, 11, 13, 17]
        name [2, 4, 5, 11], :if_sewers_first_plank, :when => false
        name [13, 17], :if_sewers_second_plank, :when => false
        name 3, :if_sewers_first_approach
        name 16, :if_sewers_second_approach
      elsif map == 446
        name 9, :if_sewers_first_plank, :when => lambda { |_event| !$game_switches[127] }
        name 6, :if_sewers_second_plank, :when => lambda { |_event| !$game_switches[129] }
        spot :event => 9, :label => :if_sewers_first_crossing, :onto => true, :when => lambda { $game_switches[127] }
        spot :event => 6, :label => :if_sewers_second_crossing, :onto => true, :when => lambda { $game_switches[129] }
      else
        name 1, :if_sewers_water_control
        name 2, :if_sewers_west_exit, :when => false
        name 3, :if_sewers_east_exit, :when => false
      end
    end
  end
end
