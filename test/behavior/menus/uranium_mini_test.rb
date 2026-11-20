require "rbconfig"
require "json"

# Uranium's Winotingo (games/uranium/bingo.rb), driven in a gen-6 process of its own so the profile binds to a
# BingoUpdate shaped as the game's: the card said with the rules as it is dealt, how it stands at the next win, the
# line it completes, and both grids on the info key while the bingo's map is on.
class UraniumMiniTest < PokeAccessTest
  # The game's repaint, declared before the toolkit loads so the profile's hook finds it, and the Bingo Handler's
  # deal and draw as the event's scripts keep the two grids (a marked space turns 0).
  WORLD = <<-'RUBY'
    def BingoUpdate(grid, column)
      grid
    end
    def ura_deal(card, bonus)
      $bingo = card.map { |c| c.dup }
      $winotingernum = bonus.dup
      $bingo.each_with_index { |col, i| BingoUpdate(col, i) }
      BingoUpdate($winotingernum, 5)
    end
    def ura_ball(letter, num)
      $bingo[letter] = $bingo[letter].map { |x| x == num ? 0 : x }
      (letter * 3...letter * 3 + 3).each { |i| $winotingernum[i] = 0 if $winotingernum[i] == num } if letter < 3
      $bingo.each_with_index { |col, i| BingoUpdate(col, i) }
      BingoUpdate($winotingernum, 5)
    end
  RUBY

  CARD = [[7, 2, 9, 1, 4], [3, 6, 8, 1, 5], [5, 8, 0, 1, 6], [2, 4, 6, 8, 9], [1, 3, 5, 7, 9]]
  BONUS = [3, 5, 8, 2, 0, 9, 2, 3, 4]
  OTHER_CARD = [[1, 2, 3, 4, 5], [9, 8, 7, 6, 5], [1, 2, 0, 3, 4], [5, 6, 7, 8, 9], [2, 4, 6, 8, 1]]
  OTHER_BONUS = [6, 7, 8, 1, 0, 3, 5, 6, 7]

  # Runs the game's steps in order and prints, as one JSON line, what each step said with what the nets caught.
  RUNNER = <<-'RUBY'
    say = lambda { |line| SpeakCapture.clear; PokeAccess.say_dialogue(line); SpeakCapture.log.map { |t, c| [t, c] } }
    info = lambda { |map| $game_map.map_id = map; PokeAccess::UraniumBingo.info }
    out = { "errors" => ERRS, "absent" => PokeAccess::Hooks.fn_absent.grep(/Bingo/), "steps" => {} }
    s = out["steps"]
    $game_map.map_id = 226
    ura_deal(CARD, BONUS)
    s["dealt"] = say.call("Here's your card. Ready?")
    ura_ball(0, 7)
    s["first win"] = say.call("Pirate Flotsam: WINOTINGO!")
    s["same ball"] = say.call("The #1 winner is Pirate Flotsam, after 1 balls drawn.")
    ura_ball(1, 2)
    ura_ball(3, 6)
    s["two balls"] = say.call("Tuber Lenore: WINOTINGO!")
    [2, 9, 1, 4].each { |n| ura_ball(0, n) }
    s["completed"] = say.call("WINOTINGO! The #3 winner is Red, after 7 balls drawn.")
    s["info"] = [info.call(226), PokeAccess::Info.map_text]
    s["info elsewhere"] = info.call(224)
    $game_map.instance_variable_set(:@events, {})
    s["info back"] = info.call(226)
    ura_deal(OTHER_CARD, OTHER_BONUS)
    s["dealt again"] = say.call("Ready?")
    s["info again"] = info.call(226)
    out["raw"] = SpeakCapture.raw_offenders.map { |_test, text| text }
    out["arity"] = ArityNet.offenders
    puts "RESULT #{JSON.generate(out, :ascii_only => true)}"
  RUBY

  test "binds to the game's BingoUpdate" do
    assert_equal [], outcome["absent"]
  end

  test "says the rules and the card as it is dealt, after the game's line" do
    assert_equal [["Here's your card. Ready?", false], [dealt(CARD, BONUS), false]], step("dealt")
  end

  test "at the next win says how the card stands, once" do
    assert_equal [["Pirate Flotsam: WINOTINGO!", false], [standing(1, 3, 0), false]], step("first win")
    assert_equal [["The #1 winner is Pirate Flotsam, after 1 balls drawn.", false]], step("same ball")
  end

  test "says only how the card stands after the last ball before a win" do
    assert_equal [["Tuber Lenore: WINOTINGO!", false], [standing(2, 3, 1), false]], step("two balls")
  end

  test "names the line the card completes" do
    done = t(:ura_bingo_done, :lines => t(:ura_bingo_column, :letter => "T"))
    assert_equal [["WINOTINGO! The #3 winner is Red, after 7 balls drawn.", false], [done, false]], step("completed")
  end

  test "the info key on the bingo's map says both grids as they stand and how the card does" do
    marked = t(:ura_bingo_marked_cell)
    cols = [col("T", [marked] * 5), col("I", %w[3 6 8 1 5]), col("N", ["5", "8", t(:ura_bingo_free), "1", "6"]),
            col("G", ["2", "4", marked, "8", "9"]), col("O", %w[1 3 5 7 9])]
    bonus = [col("T", %w[3 5 8]), col("I", [marked, t(:ura_bingo_free), "9"]), col("N", %w[2 3 4])]
    done = t(:ura_bingo_done, :lines => t(:ura_bingo_column, :letter => "T"))
    text = PokeAccess.sentences([grids(cols, bonus), done])
    assert_equal [text, text], step("info")
  end

  test "the info key leaves the bingo on another map and once its map is left" do
    assert_nil step("info elsewhere")
    assert_nil step("info back")
  end

  test "a new deal is a new card, said and kept for the info key" do
    assert_equal [["Ready?", false], [dealt(OTHER_CARD, OTHER_BONUS), false]], step("dealt again")
    assert_equal PokeAccess.sentences([dealt_grids(OTHER_CARD, OTHER_BONUS), standing(0, 4, 0)]), step("info again")
  end

  private

  def col(letter, words)
    t(:ura_bingo_col, :letter => letter, :cells => words.join(", "))
  end

  def grids(cols, bonus)
    PokeAccess.sentences([t(:ura_bingo_card, :cols => cols.join("; ")), t(:ura_bingo_bonus, :cols => bonus.join("; "))])
  end

  # Both grids of a card just dealt: its numbers, the two centres free.
  def dealt_grids(card, bonus)
    letters = %w[T I N G O]
    free = t(:ura_bingo_free)
    cols = (0...5).map { |i| col(letters[i], card[i].each_with_index.map { |v, r| i == 2 && r == 2 ? free : v.to_s }) }
    third = (0...3).map { |i| col(letters[i], bonus[i * 3, 3].each_with_index.map { |v, r| i == 1 && r == 1 ? free : v.to_s }) }
    grids(cols, third)
  end

  def dealt(card, bonus)
    PokeAccess.sentences([t(:ura_bingo_rules), dealt_grids(card, bonus)])
  end

  def standing(marked, need, bonus)
    PokeAccess.sentences([t(:ura_bingo_marked, :n => marked), t(:ura_bingo_need, :n => need),
                          t(:ura_bingo_bonus_marked, :n => bonus)])
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # One step's result; flunks when the process failed to load the profile whole or tripped a net.
  def step(name)
    all = outcome
    problems = all.reject { |k, v| k == "steps" || k == "absent" || v.empty? }
    flunk "the bingo process: #{problems.inspect}" unless problems.empty?
    flunk "the bingo process reported no step #{name}" unless all["steps"].key?(name)
    all["steps"][name]
  end

  # What the bingo process printed, run once per test process.
  def outcome
    self.class.instance_variable_get(:@outcome) || self.class.instance_variable_set(:@outcome, spawn_bingo)
  end

  # Runs the world, the uranium profile's load and the steps in a gen-6 process, the mod's speech captured in Spanish
  # and the arity net on; flunks with the process's output when it prints no result.
  def spawn_bingo
    support = File.join(Harness::ROOT, "test", "support")
    script = "require #{File.join(support, 'harness').inspect}\nrequire 'json'\n#{WORLD}\n" \
             "ERRS = Harness.load_all('uranium')\n" \
             "require #{File.join(support, 'speak_capture').inspect}\n" \
             "require #{File.join(support, 'arity_net').inspect}\n" \
             "SpeakCapture.install\nPokeAccess::Config.language = :es\n" \
             "CARD = #{CARD.inspect}\nBONUS = #{BONUS.inspect}\n" \
             "OTHER_CARD = #{OTHER_CARD.inspect}\nOTHER_BONUS = #{OTHER_BONUS.inspect}\n#{RUNNER}"
    out = IO.popen([{ "PA_ENGINE" => "gen6" }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
    line = out.to_s[/^RESULT (.*?)\r?$/, 1]
    flunk "the bingo process printed no result: #{out.to_s[0, 400]}" unless line
    JSON.parse(line)
  end
end
