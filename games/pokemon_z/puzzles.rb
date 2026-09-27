# Pokemon Z's map puzzles; the switch, variable and pattern values were read from each map's events.
PokeAccess::Game.define("pokemon_z") do
  # Santuario Prosperidad (map 119): 3x3 floor runes, each toggling a switch, to form X, Y and Z in turn (var 95
  # is the stage; switches 190 and 193 mark Y and Z, 194 the solve).
  sw = [172, 173, 174, 175, 184, 185, 186, 187, 188]
  x_pat = [true, false, true, false, true, false, true, false, true]
  y_pat = [true, false, true, false, true, false, false, true, false]
  z_pat = [true, true, true, false, true, false, true, true, true]
  puzzle(119,
    :cols => 3, :rows => 3,
    :cells => [[13, 11], [15, 11], [17, 11],
               [13, 13], [15, 13], [17, 13],
               [13, 15], [15, 15], [17, 15]],
    :lit => lambda { |i| $game_switches[sw[i]] },
    :active => lambda { $game_variables[95] >= 1 && $game_variables[95] < 4 },
    :solved => lambda { $game_switches[194] || $game_variables[95] >= 4 },
    :target => lambda {
      v = $game_variables[95]
      if v < 1 || v >= 4
        nil
      elsif $game_switches[193]
        { :name => "Z", :pattern => z_pat }
      elsif $game_switches[190]
        { :name => "Y", :pattern => y_pat }
      else
        { :name => "X", :pattern => x_pat }
      end
    })

  # Barco "La Tarasque" (5th gym, maps 143-145): two gold valves (switches 312, 313) open the command room;
  # coloured cranks (vars 132 red, 133 green, 134 blue) toggle the steam jets in the way.
  ship = {
    :kind => :state,
    :watch => [
      { :var => 132, :label => :ship_crank_red,   :on => :ship_crank_on, :off => :ship_crank_off },
      { :var => 133, :label => :ship_crank_green,  :on => :ship_crank_on, :off => :ship_crank_off },
      { :var => 134, :label => :ship_crank_blue,   :on => :ship_crank_on, :off => :ship_crank_off },
      { :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off },
      { :switch => 313, :label => :ship_valve2, :on => :ship_valve_on, :off => :ship_valve_off }
    ],
    :solved => lambda { $game_switches[312] && $game_switches[313] },
    :solved_msg => :ship_solved,
    :hint => :ship_hint,
    # Steam jets ("humo") are invisible walls; the Sharpedo are moving traps that send the player back.
    :obstacles => [
      { :match => /humo/i,     :kind => :wall },
      { :match => /sharpedo/i, :kind => :mover }
    ]
  }
  [143, 144, 145].each { |m| puzzle(m, ship) }

  # 3rd gym "Bastion Pokemon" (maps 87, 89): floor plates toggle the "rayos" barriers; gym3 takes the switches
  # of the red, blue and green plates and of the optional Rotom lever. Said as on/off, as the green plate gates
  # no barrier; no :solved, as the room never settles.
  gym3 = lambda do |red, blue, green, power|
    { :kind => :state,
      :watch => [
        { :switch => red,   :label => :gym3_red,   :on => :gym3_on, :off => :gym3_off },
        { :switch => blue,  :label => :gym3_blue,  :on => :gym3_on, :off => :gym3_off },
        { :switch => green, :label => :gym3_green, :on => :gym3_on, :off => :gym3_off },
        { :switch => power, :label => :gym3_power, :on => :gym3_power_on, :off => :gym3_power_off }
      ],
      :hint => :gym3_hint,
      :obstacles => [{ :match => /rayos/i, :kind => :wall }] }
  end
  puzzle(87, gym3.call(142, 141, 143, 147))
  puzzle(89, gym3.call(144, 145, 146, 148))

  # Palacio Luminalia (maps 172, 191): turn the three "malvoBusto" busts to the facings the map's events check
  # (not a walkthrough's); directions 4 west, 6 east, 8 north.
  busts = { :kind => :facing, :match => /malvoBusto/i, :label => :statue_bust }
  puzzle(172, busts.merge(:targets => { [35, 11] => 6 }))
  puzzle(191, busts.merge(:targets => { [18, 52] => 4, [12, 7] => 8 }))

  # Isla Certijo (map 123): the Riddle King's four riddles, opened in turn by switches 226-232 (accepted, stars
  # done, second told, signs done, third told, Pikachu done, beaten):
  #  1. five hidden stars (events 9, 8, 6, 5, 7) counted in var 112;
  #  2. four signs (events 11-14, vars 113-116) cycling 0-3, passed at the plate (event 15) on a sum of 8;
  #  3. push the Pikachu (event 16) east into the goal; the arrow (event 2) puts it back;
  #  4. var 118 counts the times the last riddle is heard; at seven he fights.
  # The two return stages and the win are quiet: the King's own lines say them.
  riddle = lambda { |on, off| lambda { $game_switches[on] && !$game_switches[off] } }
  king = { :at => [30, 10], :label => :riddle_king }
  puzzle(123,
    :kind => :stages,
    :spots => [king],
    :solved => lambda { $game_switches[232] },
    :solved_msg => :riddle_solved,
    :solved_quiet => true,
    :stages => [
      { :when => riddle.call(226, 227), :title => :riddle1_title,
        :progress => { :var => 112, :of => 5, :label => :riddle_stars, :hide_zero => true },
        :hidden => { :events => [9, 8, 6, 5, 7], :label => :riddle_star },
        :hint => :riddle1_hint },
      { :when => riddle.call(227, 228), :title => :riddle_back, :quiet => true },
      { :when => riddle.call(228, 229), :title => :riddle2_title,
        :values => [{ :var => 113, :event => 11, :label => [:riddle_sign, { :n => 1 }] },
                    { :var => 114, :event => 12, :label => [:riddle_sign, { :n => 2 }] },
                    { :var => 115, :event => 13, :label => [:riddle_sign, { :n => 3 }] },
                    { :var => 116, :event => 14, :label => [:riddle_sign, { :n => 4 }] }],
        :sum => true,
        :spots => [{ :at => [15, 59], :label => :riddle_plate }],
        :hint => :riddle2_hint },
      { :when => riddle.call(229, 230), :title => :riddle_back, :quiet => true },
      { :when => riddle.call(230, 231), :title => :riddle3_title,
        :track => { :event => 16, :label => :riddle_pikachu, :goal => [54, 40, 72, 44], :goal_label => :riddle_goal },
        :spots => [{ :event => 2, :label => :riddle_reset }],
        :hint => :riddle3_hint },
      { :when => riddle.call(231, 232), :title => :riddle4_title,
        :progress => { :var => 118, :of => 7, :label => :riddle_asked, :assist => true, :announce => true },
        :hint => :riddle4_hint }
    ])
end
