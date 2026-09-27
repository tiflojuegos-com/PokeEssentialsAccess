# FL's Roulette (plugins/fl_roulette.rb) over the gen-6 stub of its scene: the bet under the cursor with the multiplier
# its box paints, the coins as their box paints them, and the cell each spin's ball falls on.
Suite.define("fl roulette: the bet under the cursor and its painted multiplier, the coins, and where the ball falls") do
  t = PokeAccess::I18n
  scene = RouletteScene.new
  SpeakCapture.clear
  scene.bet(2, 3, 12)
  eq "one cell by its row and column, with the multiplier painted for it", SpeakCapture.lines,
     ["#{t.t(:mg_rowcol, :row => 3, :col => 2)}. #{t.t(:flr_multiplier, :n => '12')}"]
  eq "cutting in, as a cursor move", SpeakCapture.log.last[1], true
  SpeakCapture.clear
  scene.bet(0, 2, 4)
  eq "the header column bets on a whole row", SpeakCapture.lines, ["#{t.t(:flr_row, :n => 2)}. #{t.t(:flr_multiplier, :n => '4')}"]
  SpeakCapture.clear
  scene.bet(3, 0, 3)
  eq "the header row on a whole column", SpeakCapture.lines, ["#{t.t(:flr_column, :n => 3)}. #{t.t(:flr_multiplier, :n => '3')}"]
  scene.played!(6)
  SpeakCapture.clear
  scene.bet(3, 2, 0)
  eq "a bet with nothing left to come up paints no multiplier, and says so", SpeakCapture.lines,
     ["#{t.t(:mg_rowcol, :row => 2, :col => 3)}. #{t.t(:flr_played)}"]
  truthy "the info key adds the cells come up so far",
         PokeAccess::Info.info_text.to_s.include?(t.t(:flr_hits, :list => t.t(:mg_rowcol, :row => 2, :col => 3)))

  SpeakCapture.clear
  scene.coins(150)
  scene.coins(150)
  scene.coins(149)
  eq "the coins as their box paints them, once per change, queued", SpeakCapture.log,
     [[t.t(:mg_coins, :n => 150), false], [t.t(:mg_coins, :n => 149), false]]

  SpeakCapture.clear
  scene.result = 6
  scene.pbEndSpin
  eq "a spin ends on the cell its ball falls on", SpeakCapture.lines,
     [t.t(:flr_landed, :cell => t.t(:mg_rowcol, :row => 2, :col => 3))]
end
