# FL's Roulette (plugins/fl_roulette.rb) over the gen-6 stub of its scene: the bet under the cursor with the multiplier
# its box paints, the cells come up so far for the info key, the coins as their box paints them, and the cell each
# spin's ball falls on.
class FlRouletteTest < PokeAccessTest
  test "the bet under the cursor is said by its row and column with the multiplier its box paints, cutting in" do
    RouletteScene.new.bet(2, 3, 12)
    assert_equal [["#{cell(3, 2)}. #{t(:flr_multiplier, :n => '12')}", true]], SpeakCapture.log
  end

  test "the header column bets on a whole row, the header row on a whole column" do
    { [0, 2] => t(:flr_row, :n => 2), [3, 0] => t(:flr_column, :n => 3) }.each do |(x, y), bet|
      SpeakCapture.clear
      RouletteScene.new.bet(x, y, 4)
      assert_equal ["#{bet}. #{t(:flr_multiplier, :n => '4')}"], SpeakCapture.lines, "the cursor at (#{x}, #{y})"
    end
  end

  test "a bet with nothing left to come up paints no multiplier, and says so" do
    scene = RouletteScene.new
    scene.played!(6)
    scene.bet(3, 2, 0)
    assert_equal ["#{cell(2, 3)}. #{t(:flr_played)}"], SpeakCapture.lines
  end

  test "the info key holds the bet and the cells come up so far, row by row" do
    scene = RouletteScene.new
    [6, 1].each { |i| scene.played!(i) }
    scene.bet(2, 3, 12)
    assert_equal "#{cell(3, 2)}. #{t(:flr_multiplier, :n => '12')}. " \
                 "#{t(:flr_hits, :list => "#{cell(1, 2)}, #{cell(2, 3)}")}", PokeAccess::Info.info_text
  end

  test "with no cell come up the info key holds the bet alone" do
    RouletteScene.new.bet(2, 3, 12)
    assert_equal "#{cell(3, 2)}. #{t(:flr_multiplier, :n => '12')}", PokeAccess::Info.info_text
  end

  test "a scene with no cursor says no bet" do
    scene = RouletteScene.new
    scene.instance_variable_set(:@cursor, nil)
    scene.pbDrawMultiplier
    assert_nothing_spoken
  end

  test "the coins are said as their box paints them, once per change, queued" do
    scene = RouletteScene.new
    [150, 150, 149].each { |n| scene.coins(n) }
    assert_equal [[t(:mg_coins, :n => 150), false], [t(:mg_coins, :n => 149), false]], SpeakCapture.log
  end

  test "a coin box painted with no number says nothing" do
    RouletteScene.new.coins("")
    assert_nothing_spoken
  end

  test "a spin ends on the cell its ball falls on, queued before the messages that say whether the bet won" do
    { 6 => cell(2, 3), 0 => cell(1, 1), 11 => cell(3, 4) }.each do |result, landed|
      scene = RouletteScene.new
      scene.result = result
      SpeakCapture.clear
      scene.pbEndSpin
      assert_equal [[t(:flr_landed, :cell => landed), false]], SpeakCapture.log, "ball #{result}"
    end
  end

  private

  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A cell of the table by its row and column, as the reader names it.
  def cell(row, col); t(:mg_rowcol, :row => row, :col => col); end
end
