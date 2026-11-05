# Isla Certijo (map 123): the Riddle King's four riddles, opened in turn by switches 226-232 (accepted, stars done,
# second told, signs done, third told, Pikachu done, beaten): hidden stars, signs summing 8 at the plate, the Pikachu
# pushed into the goal, the last riddle heard seven times. Return phases and win are quiet: the King's lines say them.
PokeAccess::Game.define("pokemon_z") do
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
