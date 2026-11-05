# Balneario Oculto (maps 468 and 345): Urano's four riddles, told in turn by var 253 (1 the mirror, 3 the candles, 5 the
# clown, 7 the paintings; 2, 4 and 6 send the player back to him), then switch 775 his challenge and 778 his chest. Each
# of the four paintings shows what its var (249-252) says, 1 to 4, and touching the plaque below it moves that on; an
# autorun deals 1, 2, 3, 4 on each arrival, which is what the phases wait for on the first. The plaques and the third
# candle's plate have no graphic, name or text, so nothing else lists them.
PokeAccess::Game.define("pokemon_z") do
  pictures = { 1 => :z_spa_pic_pikachu, 2 => :z_spa_pic_purple, 3 => :z_spa_pic_wigglytuff, 4 => :z_spa_pic_goldeen }
  paintings = (0..3).map do |i|
    { :var => 249 + i, :event => 12 + i, :label => [:z_spa_painting, { :n => i + 1 }], :words => pictures }
  end
  spa = lambda do |*stages|
    lambda { $game_variables[252] >= 1 && !$game_switches[775] && stages.include?($game_variables[253]) }
  end
  spa_challenge = lambda { $game_switches[775] && !$game_switches[778] }
  mechanic(:state, 468) do
    active { $game_variables[253] >= 1 && !$game_switches[778] }
    phase spa.call(0), :quiet => true, :values => paintings
    phase spa.call(1), :title => :z_spa1_title, :hint => :z_spa1_hint, :values => paintings,
          :spots => [{ :at => [27, 9], :label => :z_spa_mirror }]
    phase spa.call(2, 4, 6), :title => :z_spa_back, :quiet => true, :values => paintings
    phase spa.call(3), :title => :z_spa2_title, :hint => :z_spa2_hint, :values => paintings
    phase spa.call(5), :title => :z_spa3_title, :hint => :z_spa3_hint, :values => paintings
    phase spa.call(7), :title => :z_spa4_title, :hint => :z_spa4_hint, :values => paintings
    phase spa_challenge, :title => :z_spa_last, :quiet => true
  end
  mechanic(:state, 345) do
    phase spa.call(1), :title => :z_spa1_title, :hint => :z_spa1_hint
    phase spa.call(2, 4, 6), :title => :z_spa_back, :quiet => true
    phase spa.call(3), :title => :z_spa2_title, :hint => :z_spa2_hint,
          :progress => { :var => 254, :of => 3, :label => :z_spa_candles, :hide_zero => true, :announce => true },
          :hidden => { :events => [20, 21, 26], :label => :z_spa_candle }
    phase spa.call(5), :title => :z_spa3_title, :hint => :z_spa3_hint,
          :spots => [{ :event => 23, :label => :z_spa_clown }]
    phase spa.call(7), :title => :z_spa4_title, :hint => :z_spa4_hint
    phase spa_challenge, :title => :z_spa_last, :quiet => true
  end
end
