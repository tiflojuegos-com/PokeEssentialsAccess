# Pokemon Z's map puzzles; the switch, variable and pattern values were read from each map's events.
PokeAccess::Game.define("pokemon_z") do
  # Santuario Prosperidad (map 119): 3x3 floor runes, each toggling a switch, to form X, Y and Z in turn (var 95
  # is the stage; switches 190 and 193 mark Y and Z, 194 the solve). The solve's autorun puts every rune out 80 frames
  # later, var 95 still at its stage until the transfer, so the puzzle is over once 194 is on.
  sw = [172, 173, 174, 175, 184, 185, 186, 187, 188]
  x_pat = [true, false, true, false, true, false, true, false, true]
  y_pat = [true, false, true, false, true, false, false, true, false]
  z_pat = [true, true, true, false, true, false, true, true, true]
  mechanic(:grid, 119) do
    cells 3, [[13, 11], [15, 11], [17, 11],
              [13, 13], [15, 13], [17, 13],
              [13, 15], [15, 15], [17, 15]]
    lit { |i| $game_switches[sw[i]] }
    active { $game_variables[95] >= 1 && $game_variables[95] < 4 && !$game_switches[194] }
    solved { $game_switches[194] || $game_variables[95] >= 4 }
    target do
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
    end
  end

  # Barco "La Tarasque" (5th gym, maps 143-145): two gold valves (switches 312, 313) open the command room;
  # coloured cranks (vars 132 red, 133 green, 134 blue) toggle the steam jets in the way. The steam jets ("humo")
  # are walls, all drawn alike; the Sharpedo are moving traps that send the player back to the deck's entrance.
  mechanic(:state, [143, 144, 145]) do
    watch :var => 132, :label => :ship_crank_red,   :on => :ship_crank_on, :off => :ship_crank_off
    watch :var => 133, :label => :ship_crank_green, :on => :ship_crank_on, :off => :ship_crank_off
    watch :var => 134, :label => :ship_crank_blue,  :on => :ship_crank_on, :off => :ship_crank_off
    watch :switch => 312, :label => :ship_valve1, :on => :ship_valve_on, :off => :ship_valve_off
    watch :switch => 313, :label => :ship_valve2, :on => :ship_valve_on, :off => :ship_valve_off
    controls
    obstacle(/humo/i, :label => :ship_steam)
    obstacle(/sharpedo/i, :moving => true)
    solved(:ship_solved) { $game_switches[312] && $game_switches[313] }
    hint :ship_hint
  end

  # A Sharpedo of the middle deck (map 144, events "sharpedoGym") that touches the player sends them back to the deck's
  # entrance (4, 8) with no message: a teleport there from beside one is said as its doing.
  PokeAccess::Locator.teleport_cause(:z_ship_sharpedo) do |from, to|
    sharks = to == [4, 8, 144] ? PokeAccess::World::Mechanics.pieces(:obstacle).select { |p| p.moving } : []
    touched = sharks.any? { |p| (p.ev.x - from[0]).abs + (p.ev.y - from[1]).abs <= 1 }
    touched ? PokeAccess::I18n.t(:ship_sharpedo_back) : nil
  end

  # 3rd gym "Bastion Pokemon" (maps 87, 89): floor plates toggle the "rayos" barriers, named by colour and lie as drawn;
  # each room's red, blue and green plate switches and the optional Rotom lever are said as on/off. No win: the room
  # never settles.
  [[87, 142, 141, 143, 147], [89, 144, 145, 146, 148]].each do |map, red, blue, green, power|
    mechanic(:state, map) do
      watch :switch => red,   :label => :gym3_red,   :on => :gym3_on, :off => :gym3_off
      watch :switch => blue,  :label => :gym3_blue,  :on => :gym3_on, :off => :gym3_off
      watch :switch => green, :label => :gym3_green, :on => :gym3_on, :off => :gym3_off
      watch :switch => power, :label => :gym3_power, :on => :gym3_power_on, :off => :gym3_power_off
      controls
      obstacle(/\ArayosR\z/i, :label => :gym3_rays_red)
      obstacle(/\ArayosRojosV\z/i, :label => :gym3_rays_red_v)
      obstacle(/\ArayosBarrera\z/i, :label => :gym3_rays_blue)
      obstacle(/\ArayosAzulesV\z/i, :label => :gym3_rays_blue_v)
      obstacle(/\ArayosV\z/i, :label => :gym3_rays_green)
      hint :gym3_hint
    end
  end

  # Palacio Luminalia (maps 172, 191): turn the three "malvoBusto" busts to the facings the map's events check (4 west,
  # 6 east, 8 north); each sets its variable (162, 163, 164) to 1 while facing its goal and map 191 turns switch 398 on
  # once all three do, so the win is the three variables, or 398 for good once on.
  { 172 => { [35, 11] => 6 }, 191 => { [18, 52] => 4, [12, 7] => 8 } }.each do |map, facings|
    mechanic(:facing, map) do
      statues(/malvoBusto/i, :statue_bust)
      goals facings
      solved { $game_switches[398] || [162, 163, 164].all? { |v| $game_variables[v] == 1 } }
    end
  end

  # Isla Certijo (map 123): the Riddle King's four riddles, opened in turn by switches 226-232 (accepted, stars done,
  # second told, signs done, third told, Pikachu done, beaten): hidden stars, signs summing 8 at the plate, the Pikachu
  # pushed into the goal, the last riddle heard seven times. Return phases and win are quiet: the King's lines say them.
  riddle = lambda { |on, off| lambda { $game_switches[on] && !$game_switches[off] } }
  mechanic(:state, 123) do
    spot :at => [30, 10], :label => :riddle_king
    solved(:riddle_solved, :quiet => true) { $game_switches[232] }
    phase riddle.call(226, 227), :title => :riddle1_title,
          :progress => { :var => 112, :of => 5, :label => :riddle_stars, :hide_zero => true },
          :hidden => { :events => [9, 8, 6, 5, 7], :label => :riddle_star },
          :hint => :riddle1_hint
    phase riddle.call(227, 228), :title => :riddle_back, :quiet => true
    phase riddle.call(228, 229), :title => :riddle2_title,
          :values => [{ :var => 113, :event => 11, :label => [:riddle_sign, { :n => 1 }] },
                      { :var => 114, :event => 12, :label => [:riddle_sign, { :n => 2 }] },
                      { :var => 115, :event => 13, :label => [:riddle_sign, { :n => 3 }] },
                      { :var => 116, :event => 14, :label => [:riddle_sign, { :n => 4 }] }],
          :sum => true,
          :spots => [{ :at => [15, 59], :label => :riddle_plate }],
          :hint => :riddle2_hint
    phase riddle.call(229, 230), :title => :riddle_back, :quiet => true
    phase riddle.call(230, 231), :title => :riddle3_title,
          :track => { :event => 16, :label => :riddle_pikachu, :goal => [54, 40, 72, 44], :goal_label => :riddle_goal },
          :spots => [{ :event => 2, :label => :riddle_reset }],
          :hint => :riddle3_hint
    phase riddle.call(231, 232), :title => :riddle4_title,
          :progress => { :var => 118, :of => 7, :label => :riddle_asked, :assist => true, :announce => true },
          :hint => :riddle4_hint
  end
end
