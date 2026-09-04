# Pokemon Z map puzzles, declared through the adapter API (Puzzles is core, always loaded before this
# profile). Switch/variable/pattern values were read from each map's events.
PokeAccess::Game.define("pokemon_z") do
  # Santuario Prosperidad (map 119): step on the 3x3 floor runes to form the letters X, then Y, then Z.
  # Each tile toggles a switch; a parallel event watches the pattern and advances the stage (var 95). The
  # player hears their grid position, each tile's lit state and the target letter.
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

  # Barco "La Tarasque" (5th gym, maps 143/144/145): the command-room door needs two gold valves turned
  # (switches 312/313); coloured cranks toggle steam jets that block the way (red=var132, green=var133,
  # blue=var134, any instance of a colour flips its var). All invisible blind (turning one only plays a
  # sound), so a :state puzzle announces each crank/valve as it flips, the info key reads them all and
  # (assist on) adds a hint.
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
    # Steam jets are solid invisible walls (sprite "humo"); the Sharpedo are moving traps that send you
    # back. Positional audio pings the steam as a wall and the Sharpedo with the distinct boop.
    :obstacles => [
      { :match => /humo/i,     :kind => :wall },
      { :match => /sharpedo/i, :kind => :mover }
    ]
  }
  [143, 144, 145].each { |m| puzzle(m, ship) }

  # 3rd gym "Bastion Pokemon" (maps 87 and 89, two floors of one puzzle): floor plates toggle the electric
  # barriers ("rayos..." sprites) that wall the room off. The page a plate reacts on carries NO graphic, so
  # nothing announced them and the pathfinder had nothing to route to; declaring the switches they write is
  # what lets build_controls find them by what they DO, and each plate becomes a locatable control. Map 89
  # puts two plates on one switch, which is why they are declared by switch and not by position.
  #
  # Colours are the sprites' own, sampled from the graphics rather than guessed from the file names:
  # rayosR and rayosRojosV red, rayosBarrera and rayosAzulesV blue, rayosV green. WHICH colour a switch
  # raises is inverted between the two floors, so the state is spoken as on/off and never as "the blue wall
  # is up", which would be true on one floor and a lie on the other.
  #
  # The last watched switch is the Rotom lever (map 87 @4,17; map 89 @23,19): optional, powers the leader
  # up for a bigger reward, and its state is otherwise only readable by walking over and reading the sign.
  #
  # Deliberately no :solved. The room never settles -- the leader can be beaten and the player walk back
  # in -- so the state of the plates stays the answer to "how do I get through" for the rest of the game.
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

  # Palacio Luminalia statue puzzle (maps 172/191): rotate the 3 King Malvo "malvoBusto" busts so each
  # sets its flag (172@35,11 -> east; 191@18,52 -> west; 191@12,7 -> north); EV007 on map 191 opens the
  # way when all three are set. Goal facings come from that variable logic, not the walkthrough (whose
  # compass was wrong). rpg dir codes: 4 west, 6 east, 8 north.
  busts = { :kind => :facing, :match => /malvoBusto/i, :label => :statue_bust }
  puzzle(172, busts.merge(:targets => { [35, 11] => 6 }))
  puzzle(191, busts.merge(:targets => { [18, 52] => 4, [12, 7] => 8 }))
end
