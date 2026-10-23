# Relict's difficulty picker (games/relict/difficulty.rb: the option, its description while descriptions are said, both
# kept on the info key until it closes) and Fire Ash's Grandeur Club card (games/fireash/gc_card.rb: each page as
# painted, its number a position from medium, and a tier line per challenge from the variable its emblem follows).
class PickDifficulty
  def initialize(diffs); @difficulties = diffs; @index = 0; end
  def update; :updated; end
  def run; update; :done; end
end

# The card's four pages, each painting its labels; the first also its trainer id.
class GCCard_Scene
  def pbDrawGCCardOne
    pbDrawTextPositions(nil, [["ID No.", 0, 0], ["12345", 100, 0], ["Practice", 0, 40], ["Club", 0, 80]])
    :drawn
  end

  def pbDrawGCCardTwo; paint_labels(%w[Gauntlet Duet Mayhem Sync Titan]); end
  def pbDrawGCCardThree; paint_labels(%w[Kanto Johto Hoenn Sinnoh Unova]); end
  def pbDrawGCCardFour; paint_labels(%w[Kalos Alola Galar Frontier Hisui]); end

  def paint_labels(names)
    pbDrawTextPositions(nil, names.each_with_index.map { |n, i| [n, 0, i * 40] })
    :drawn
  end
end

%w[relict/difficulty fireash/gc_card].each do |rel|
  path = File.join(Harness::ROOT, "games", "#{rel}.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
end

class RelictFireashScreensGdTest < PokeAccessTest
  DIFFS = [["NORMAL", "Normal difficulty."], ["HARD", "Harder battles."]]

  test "the picker says its heading once, then each option with its description, cutting in" do
    picker = PickDifficulty.new(DIFFS)
    assert_equal :updated, picker.update, "the picker's own update runs"
    picker.instance_variable_set(:@index, 1)
    picker.update
    assert_equal [["#{heading}. NORMAL. Normal difficulty.", true], ["HARD. Harder battles.", true]], SpeakCapture.log
  end

  test "the picker says an option once while the cursor stays on it" do
    picker = PickDifficulty.new(DIFFS)
    2.times { picker.update }
    assert_equal ["#{heading}. NORMAL. Normal difficulty."], SpeakCapture.lines
  end

  test "the picker says the description only at full, and the info key keeps both at every level" do
    said = vb_levels do
      SpeakCapture.clear
      PickDifficulty.new(DIFFS).update
      [SpeakCapture.last, PokeAccess::Info.info_text]
    end
    whole = "NORMAL. Normal difficulty."
    assert_equal [["#{heading}. NORMAL", whole], ["#{heading}. NORMAL", whole], ["#{heading}. #{whole}", whole]], said
  end

  test "the picker closing takes its option off the info key" do
    picker = PickDifficulty.new(DIFFS)
    picker.update
    assert_equal :done, picker.run, "the picker's own loop runs"
    assert_nil PokeAccess::Info.info_text
  end

  test "the picker's own loop still says the option it opens on" do
    PickDifficulty.new(DIFFS).run
    assert_equal [["#{heading}. NORMAL. Normal difficulty.", true]], SpeakCapture.log
  end

  test "the picker says nothing for a cursor past its options or without them" do
    past = PickDifficulty.new(DIFFS)
    past.instance_variable_set(:@index, 2)
    past.update
    PickDifficulty.new(nil).update
    assert_nothing_spoken
  end

  test "a tier line counts the thresholds passed, caps a value at the top, or gives the plain count" do
    t = PokeAccess::I18n
    {
      ["Gauntlet", 10, [10, 25, 50]] => t.t(:gc_tier, :name => "Gauntlet", :n => 1, :max => 3),
      ["Gauntlet", 49, [10, 25, 50]] => t.t(:gc_tier, :name => "Gauntlet", :n => 2, :max => 3),
      ["Gauntlet", 50, [10, 25, 50]] => t.t(:gc_tier, :name => "Gauntlet", :n => 3, :max => 3),
      ["Club", 3, 4] => t.t(:gc_tier, :name => "Club", :n => 3, :max => 4),
      ["Club", 4, 4] => t.t(:gc_tier, :name => "Club", :n => 4, :max => 4),
      ["Club", 6, 4] => t.t(:gc_tier, :name => "Club", :n => 4, :max => 4),
      ["Wins", 7, nil] => t.t(:gc_count, :name => "Wins", :n => 7)
    }.each do |(name, value, top), want|
      assert_equal want, PokeAccess::FireAshGC.tier_text(name, value, top), "#{name} at #{value} of #{top.inspect}"
    end
  end

  test "a slot with no emblem yet, a zero or under the first threshold, is said as blank" do
    t = PokeAccess::I18n
    { ["Gauntlet", 5, [10, 25, 50]] => "Gauntlet", ["Gauntlet", 9, [10, 25, 50]] => "Gauntlet",
      ["Gauntlet", 0, [10, 25, 50]] => "Gauntlet",
      ["Club", 0, 4] => "Club", ["Club", -1, 4] => "Club", ["Wins", 0, nil] => "Wins" }.each do |(name, value, top), slot|
      assert_equal t.t(:gc_empty, :name => slot), PokeAccess::FireAshGC.tier_text(name, value, top),
                   "#{name} at #{value} of #{top.inspect}"
    end
  end

  test "each page reads its challenges from the variables their emblems follow, cutting in" do
    t = PokeAccess::I18n
    {
      :pbDrawGCCardOne => [1, { 91 => 2, 92 => 1 }, "ID No., 12345", [["Practice", 2, 3], ["Club", 1, 4]]],
      :pbDrawGCCardTwo => [2, { 93 => 30, 97 => 3, 94 => 2, 95 => 4, 96 => 1 }, nil,
                           [["Gauntlet", 2, 3], ["Duet", 3, 4], ["Mayhem", 2, 3], ["Sync", 4, 4], ["Titan", 1, 4]]],
      :pbDrawGCCardThree => [3, { 90 => 1, 89 => 2, 88 => 1, 87 => 2, 86 => 1 }, nil,
                             [["Kanto", 1, 2], ["Johto", 2, 2], ["Hoenn", 1, 2], ["Sinnoh", 2, 2], ["Unova", 1, 2]]],
      :pbDrawGCCardFour => [4, { 85 => 1, 84 => 2, 48 => 1, 83 => 1, 47 => 2 }, nil,
                            [["Kalos", 1, 2], ["Alola", 2, 2], ["Galar", 1, 2], ["Frontier", 1, 2], ["Hisui", 2, 2]]]
    }.each do |meth, (page, vars, painted, tiers)|
      $game_variables.clear
      vars.each { |var, v| $game_variables[var] = v }
      SpeakCapture.clear
      assert_equal :drawn, GCCard_Scene.new.send(meth), "#{meth}: the page paints as the game's"
      parts = [t.t(:gc_page, :n => page, :total => 4), painted]
      parts.concat(tiers.map { |name, n, max| t.t(:gc_tier, :name => name, :n => n, :max => max) })
      assert_equal [[parts.compact.join(". "), true]], SpeakCapture.log, meth.to_s
    end
  end

  test "the Gauntlet's emblems on the card follow its three thresholds" do
    t = PokeAccess::I18n
    { 9 => t.t(:gc_empty, :name => "Gauntlet") }.merge(
      10 => t.t(:gc_tier, :name => "Gauntlet", :n => 1, :max => 3),
      25 => t.t(:gc_tier, :name => "Gauntlet", :n => 2, :max => 3),
      50 => t.t(:gc_tier, :name => "Gauntlet", :n => 3, :max => 3)
    ).each do |streak, want|
      $game_variables[93] = streak
      SpeakCapture.clear
      GCCard_Scene.new.pbDrawGCCardTwo
      assert_equal want, SpeakCapture.last.split(". ")[1], "a best streak of #{streak}"
    end
  end

  test "the card's page number leads the page from medium on, and brief reads the page without it" do
    page = PokeAccess::I18n.t(:gc_page, :n => 1, :total => 4)
    said = vb_levels do
      SpeakCapture.clear
      GCCard_Scene.new.pbDrawGCCardOne
      SpeakCapture.last
    end
    assert_equal [blank_page_one, "#{page}. #{blank_page_one}", "#{page}. #{blank_page_one}"], said
  end

  test "a zero leaves its slot blank on the card" do
    $game_variables[91] = 2
    GCCard_Scene.new.pbDrawGCCardOne
    assert_equal PokeAccess::I18n.t(:gc_empty, :name => "Club"), SpeakCapture.last.split(". ").last
  end

  test "a card drawn while the game keeps no variables leaves its slots blank" do
    without_variables { GCCard_Scene.new.pbDrawGCCardOne }
    assert_equal [["#{PokeAccess::I18n.t(:gc_page, :n => 1, :total => 4)}. #{blank_page_one}", true]], SpeakCapture.log
  end

  private

  # The picker's heading, said before its first option.
  def heading
    PokeAccess::I18n.t(:rel_difficulty)
  end

  # The card's first page as read with both its slots blank, without its page number.
  def blank_page_one
    t = PokeAccess::I18n
    "ID No., 12345. #{t.t(:gc_empty, :name => 'Practice')}. #{t.t(:gc_empty, :name => 'Club')}"
  end

  # Runs the block with $game_variables unset, put back after.
  def without_variables
    was = $game_variables
    $game_variables = nil
    yield
  ensure
    $game_variables = was
  end
end
