# Celadon Sewers, dry (431) and flooded (446) with their two control rooms (447, 448). In the dry sewers a plank drops
# when stepped on walking west from its approach (switches 127 and 129, 128 marking the approach); flooded, a dropped
# plank is a crossing. The control room's PC sets switch 130, flooded when on, and the game says that change itself. The
# puzzle ends with the hideout (switch 148).
PokeAccess::Game.define("infinitefusion") do
  state_line = lambda do |label, on, words|
    PokeAccess::I18n.t(:puzzle_value, :label => PokeAccess::I18n.t(label), :v => PokeAccess::I18n.t(on ? words[0] : words[1]))
  end

  [431, 446, 447, 448].each do |map|
    mechanic(:state, map, :part => :celadon_sewers) do
      auto
      watch :switch => 127, :label => :ifk_sw_plank1, :on => :ifk_sw_lowered, :off => :ifk_sw_raised
      watch :switch => 129, :label => :ifk_sw_plank2, :on => :ifk_sw_lowered, :off => :ifk_sw_raised
      watch :switch => 130, :quiet => true
      watch :switch => 128, :quiet => true
      controls
      hint :ifk_sw_hint
      solved { $game_switches[148] }
      info do
        PokeAccess.sentences([
          state_line.call(:ifk_sw_water, $game_switches[130], [:ifk_sw_flooded, :ifk_sw_dry]),
          state_line.call(:ifk_sw_plank1, $game_switches[127], [:ifk_sw_lowered, :ifk_sw_raised]),
          state_line.call(:ifk_sw_plank2, $game_switches[129], [:ifk_sw_lowered, :ifk_sw_raised])])
      end

      if map == 431
        hide [2, 4, 5, 11, 13, 17]
        name [2, 4, 5, 11], :ifk_sw_plank1, :when => false
        name [13, 17], :ifk_sw_plank2, :when => false
        name 3, :ifk_sw_approach1
        name 16, :ifk_sw_approach2
        arrival_hint :ifk_sw_rule
      elsif map == 446
        name 9, :ifk_sw_plank1, :when => lambda { |_event| !$game_switches[127] }
        name 6, :ifk_sw_plank2, :when => lambda { |_event| !$game_switches[129] }
        spot :event => 9, :label => :ifk_sw_cross1, :onto => true, :when => lambda { $game_switches[127] }
        spot :event => 6, :label => :ifk_sw_cross2, :onto => true, :when => lambda { $game_switches[129] }
        arrival_hint :ifk_sw_rule
      else
        name 1, :ifk_sw_control
        name 2, :ifk_sw_west_exit, :when => false
        name 3, :ifk_sw_east_exit, :when => false
      end
    end
  end
end
