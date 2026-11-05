# The Result Panel (plugins/result_panel.rb): a tournament's matches on opening, the competitor or match under the cursor
# and the page of details each opens, with the bracket's data laid out as the plugin keeps it.

# The panel as the plugin's after pbStartScene: competitors by number, who passed each round with the round's title last.
class ResultPanelScene
  attr_accessor :cursor_to

  def initialize(state)
    state.each { |k, v| instance_variable_set("@#{k}", v) }
  end

  def pbStartScene(*_a); end
  def pbUpdateCursor(_direction); @cursor_position = @cursor_to if @cursor_to; end
  def pbEndScene; end
end

# A page of details: paints its rows and has its icons in @sprites.
class DetailsScene
  attr_accessor :rows, :cursor_position

  def initialize(cursor, rows, sprites = {})
    @cursor_position = cursor
    @rows = rows
    @sprites = sprites
  end

  def pbUpdateTrainerInfo
    pbDrawTextPositions(nil, @rows)
    :painted
  end
end

Settings.const_set(:CURSORFUNCTIONS, true) unless Settings.const_defined?(:CURSORFUNCTIONS)

begin
  path = File.join(Harness::ROOT, "plugins", "result_panel.rb")
  src = Harness.source(path)
  hooks = src.index('PokeAccess::Hooks.after_hook("ResultPanelScene"')
  eval(src[hooks..-1], TOPLEVEL_BINDING, path, src[0, hooks].count("\n") + 1)
end

class ResultPanelGdTest < PokeAccessTest
  NAMES = %w[Ana Bea Cid Dan Eva Fer Gus Hal].freeze
  # An eight-panel's rounds: 1, 4, 5 and 8 pass the first, 1 and 5 the second, 5 the final.
  ROUNDS = [[1, 4, 5, 8, "Quarters"], [1, 5, "Semis"], [5, "Final"]].freeze
  Icon = Struct.new(:pokemon, :gone) do
    def disposed?; gone; end
  end
  Mon = Struct.new(:name)
  Trainer = Struct.new(:name)

  def setup
    super
    @player_was = $player
    $player = Trainer.new("Yo")
  end

  def teardown
    $player = @player_was
    super
  end

  test "the first round opens with its title and every match, queued with the keys, then the cursor's entry" do
    panel(:round => 1, :cursor_position => 2).pbStartScene
    matches = [vs("Ana", "Bea"), vs("Cid", "Dan"), vs("Eva", "Fer"), vs("Gus", "Hal")].join(". ")
    assert_equal [["Cup. #{matches}. #{t(:rpanel_hint)}", false], ["Bea", false]], SpeakCapture.log
  end

  test "a later round pairs those who passed the one before" do
    panel(:round => 2, :cursor_position => 9).pbStartScene
    assert_spoken(/\ACup\. #{vs("Ana", "Dan")}\. #{vs("Eva", "Hal")}\./)
  end

  test "the last round names the winner" do
    panel(:round => 4, :cursor_position => 15).pbStartScene
    assert_spoken(/\ACup\. #{t(:rpanel_winner, :name => "Eva")}\./)
  end

  test "the player is named on the panel wherever the data says Player" do
    names = NAMES.dup
    names[1] = "Player"
    panel(:round => 1, :cursor_position => 2, :trainers => names).pbStartScene
    assert_spoken(/#{vs("Ana", "Yo")}/)
    assert_equal ["Yo", false], SpeakCapture.log.last
  end

  test "a double panel's team is its two members" do
    pairs = NAMES.each_slice(2).to_a * 2
    pairs[0] = ["Player", "Bea"]
    assert_equal "Yo & Bea", PokeAccess::ResultPanel.name_of(panel(:trainers => pairs), 1)
  end

  test "moving says a competitor, cutting in, and whether they are out" do
    scene = panel(:round => 2, :cursor_position => 1)
    move(scene, 1)
    SpeakCapture.clear
    move(scene, 2)
    move(scene, 4)
    assert_equal [[t(:rpanel_out, :name => "Bea"), true], ["Dan", true]], SpeakCapture.log
  end

  test "before any round is played nobody is out" do
    assert_equal "Bea", PokeAccess::ResultPanel.entry(panel(:round => 1), 2)
  end

  test "each match is the pair its round brought together and who won it" do
    scene = panel(:round => 4)
    got = [9, 10, 11, 12, 13, 14, 15].map { |pos| PokeAccess::ResultPanel.entry(scene, pos) }
    assert_equal [won("Ana", "Bea", "Ana"), won("Cid", "Dan", "Dan"), won("Eva", "Fer", "Eva"), won("Gus", "Hal", "Hal"),
                  won("Ana", "Dan", "Ana"), won("Eva", "Hal", "Eva"), won("Ana", "Eva", "Eva")], got
  end

  test "a sixteen-panel's rounds halve the same way, down to the final" do
    names = (1..16).map { |i| "T#{i}" }
    rounds = [(1..8).map { |i| 2 * i - 1 } + ["R1"], [1, 5, 9, 13, "R2"], [1, 9, "R3"], [9, "R4"]]
    scene = panel(:round => 5, :trainers => names, :classified => rounds)
    got = [17, 24, 25, 28, 29, 30, 31].map { |pos| PokeAccess::ResultPanel.entry(scene, pos) }
    assert_equal [won("T1", "T2", "T1"), won("T15", "T16", "T15"), won("T1", "T3", "T1"), won("T13", "T15", "T13"),
                  won("T1", "T5", "T1"), won("T9", "T13", "T9"), won("T1", "T9", "T9")], got
  end

  test "a match whose winner is not listed yet is only its two sides" do
    scene = panel(:round => 2, :classified => [[1, 4, 5, 8, "Quarters"], ["Semis"], ["Final"]])
    assert_equal vs("Ana", "Dan"), PokeAccess::ResultPanel.entry(scene, 13)
  end

  test "a cursor with no place on the panel says nothing and keeps nothing" do
    panel(:round => 1, :cursor_position => 0).pbUpdateCursor("")
    assert_nothing_spoken
    assert_nil PokeAccess::Info.info_text
  end

  test "without the panel's cursor only its title and matches are said, with no keys" do
    with_no_cursor { panel(:round => 1, :cursor_position => 2).pbStartScene }
    assert_equal 1, SpeakCapture.log.length
    assert_equal false, SpeakCapture.log[0][0].include?(t(:rpanel_hint))
  end

  test "back from the details the entry is said again, queued, and the info key has it again" do
    scene = panel(:round => 1, :cursor_position => 2)
    scene.pbStartScene
    PokeAccess::Info.set_info(:text, "details", "details")
    SpeakCapture.clear
    scene.pbUpdateCursor("")
    assert_equal [["Bea", false]], SpeakCapture.log
    assert_equal "Bea", PokeAccess::Info.info_text
  end

  test "back from the details on another entry says that one" do
    scene = panel(:round => 1, :cursor_position => 2)
    scene.pbStartScene
    SpeakCapture.clear
    scene.cursor_to = 5
    scene.pbUpdateCursor("")
    assert_equal [["Eva", false]], SpeakCapture.log
  end

  test "a competitor's page says what it paints, without its placeholders, and the team its icons show" do
    icons = { "pokemon1" => Icon.new(Mon.new("Pikachu"), false), "pokemon2" => Icon.new(Mon.new("Mew"), false),
              "pokemon3" => Icon.new(Mon.new("Stale"), true) }
    page = DetailsScene.new(2, [["TRAINER BEA", 256, 66], ["-", 256, 268], ["Emphasizes SPEED.", 256, 300]], icons)
    assert_equal :painted, page.pbUpdateTrainerInfo
    line = "TRAINER BEA. Emphasizes SPEED. #{t(:rpanel_team, :list => "Pikachu, Mew")}"
    assert_equal [["#{line}. #{t(:rpanel_details_hint)}", false]], SpeakCapture.log
    assert_equal line, PokeAccess::Info.info_text
  end

  test "a page whose icons are all placeholders says the team is hidden" do
    page = DetailsScene.new(2, [["TRAINER BEA", 256, 66]], "pokemon1" => Icon.new(nil, false))
    page.pbUpdateTrainerInfo
    assert_equal "TRAINER BEA. #{t(:rpanel_team_hidden)}", PokeAccess::Info.info_text
  end

  test "with hints left out a page says no keys" do
    PokeAccess::Config.verbosity = :brief
    DetailsScene.new(2, [["TRAINER BEA", 256, 66]]).pbUpdateTrainerInfo
    assert_equal [["TRAINER BEA", false]], SpeakCapture.log
  end

  test "moving between pages cuts in, a repaint of the same one says nothing, and a match's page has no team" do
    page = DetailsScene.new(9, [["Round 1", 256, 68], ["ANA", 136, 112], ["BEA", 376, 112]])
    2.times { page.pbUpdateTrainerInfo }
    page.cursor_position = 10
    page.rows = [["Round 1", 256, 68], ["CID", 136, 112], ["DAN", 376, 112]]
    page.instance_variable_set(:@cursor_position, 10)
    page.pbUpdateTrainerInfo
    assert_equal [["Round 1. ANA. BEA. #{t(:rpanel_details_hint)}", false], ["Round 1. CID. DAN", true]], SpeakCapture.log
    assert_equal "Round 1. CID. DAN", PokeAccess::Info.info_text
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def vs(a, b)
    t(:rpanel_vs, :a => a, :b => b)
  end

  def won(a, b, winner)
    t(:rpanel_match, :a => a, :b => b, :winner => winner)
  end

  def panel(state = {})
    ResultPanelScene.new({ :title => "Cup", :trainers => NAMES, :classified => ROUNDS, :round => 1,
                           :cursor_position => 1 }.merge(state))
  end

  def move(scene, pos)
    scene.cursor_to = pos
    scene.pbUpdateCursor("right")
  end

  def with_no_cursor
    Settings.send(:remove_const, :CURSORFUNCTIONS)
    Settings.const_set(:CURSORFUNCTIONS, false)
    yield
  ensure
    Settings.send(:remove_const, :CURSORFUNCTIONS)
    Settings.const_set(:CURSORFUNCTIONS, true)
  end
end
