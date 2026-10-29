# Dark Horizon's new game (games/darkhorizon/new_game.rb): the difficulty, Randomizer and Nuzlocke panels said as
# painted, their bullets left out, the first time queued with how to answer and after a switch cutting in; the
# introduction's and the TV report's pages said as their lines run together, the first queued and the next cutting in.

# The difficulty panel: pbUpdateText paints the mode @modeSelected holds, as the game's does every frame.
class EasyHardModeWindow
  def initialize; @modeSelected = false; end

  def pbUpdateText
    rows = if @modeSelected
             [["Hard Mode", 226, 15], ["■ Level Caps", 25, 80], ["■ Reduced EXP gain", 25, 120]]
           else
             [["Easy Mode", 226, 15], ["■ No Level Caps", 25, 80], ["■ Normal EXP gain", 25, 120]]
           end
    pbDrawTextPositions(nil, rows)
    :painted
  end

  def pbEndScene; :closed; end
end

# The Randomizer and Nuzlocke panels: pbUpdateSprites repaints the same rules every frame.
class RandomizerWindow
  def pbUpdateSprites
    pbDrawTextPositions(nil, [["Randomizer", 226, 15], ["■ Randomized Items", 25, 80]])
    :frame
  end

  def pbEndScene; :closed; end
end

class NuzlockeWindow
  def pbUpdateSprites
    pbDrawTextPositions(nil, [["Nuzlocke", 226, 15], ["■ Shiny Pokémon are excluded", 25, 80]])
    :frame
  end

  def pbEndScene; :closed; end
end

# The introduction: pbTextUpdate paints the phase's next page, one line per row, and counts it.
class GameIntroduction
  def initialize(phases); @phases = phases; @introPhaseCnt = 0; @txtCnt = 0; end

  def pbTextUpdate
    lines = @phases[@introPhaseCnt][@txtCnt]
    pbDrawTextPositions(nil, lines.each_with_index.map { |l, i| [l, 256, 160 + 40 * i] })
    @txtCnt += 1
    :page
  end

  def next_phase; @introPhaseCnt += 1; @txtCnt = 0; end

  def pbEndScene; :closed; end
end

# The TV report: pbTextUpdate paints the next page left-aligned in its text box and counts it.
class TV_Window
  def initialize(pages); @TVText = pages; @txtCnt = 0; end

  def pbTextUpdate
    pbDrawTextPositions(nil, @TVText[@txtCnt].each_with_index.map { |l, i| [l, 36, 300 + 30 * i] })
    @txtCnt += 1
    :page
  end

  def pbEndScene; :closed; end
end

# The profile's shared helpers (constants.rb's module), loaded once and without the profile's settings.
unless defined?(PokeAccess::DarkHorizon)
  constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
  src = Harness.source(constants)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, constants, src[0, src.index(part)].count("\n") + 1)
end

new_game = File.join(Harness::ROOT, "games", "darkhorizon", "new_game.rb")
eval(Harness.source(new_game), TOPLEVEL_BINDING, new_game)

class DarkhorizonNewGameGdTest < PokeAccessTest
  # The first page of the introduction and of the TV report, as the game breaks their lines.
  INTRO = [[["Hello and welcome to", "Pokémon Dark Horizon!"], ["How would you best", "describe yourself?"]],
           [["You look fantastic!"]]].freeze
  TV = [["...Good evening, dear viewers!"], ["Today on ONBS:", "We're talking about the two years since"]].freeze

  test "the difficulty panel's first paint says its title and rules without bullets, queued, with how to switch" do
    EasyHardModeWindow.new.pbUpdateText
    hint = PokeAccess::I18n.t(:dh_mode_switch_hint, :key => "C")
    assert_equal [["Easy Mode. No Level Caps. Normal EXP gain. #{hint}", false]], SpeakCapture.log
  end

  test "a frame that repaints the same mode says nothing" do
    panel = EasyHardModeWindow.new
    panel.pbUpdateText
    SpeakCapture.clear
    panel.pbUpdateText
    assert_nothing_spoken
  end

  test "switching the mode says the other panel, cutting in, without the hint" do
    panel = EasyHardModeWindow.new
    panel.pbUpdateText
    SpeakCapture.clear
    panel.instance_variable_set(:@modeSelected, true)
    panel.pbUpdateText
    assert_equal [["Hard Mode. Level Caps. Reduced EXP gain", true]], SpeakCapture.log
  end

  test "with hints left out, the first panel comes alone" do
    PokeAccess::Config.verbosity = :brief
    EasyHardModeWindow.new.pbUpdateText
    assert_equal [["Easy Mode. No Level Caps. Normal EXP gain", false]], SpeakCapture.log
  end

  test "the info key holds the panel until its screen closes" do
    panel = EasyHardModeWindow.new
    panel.pbUpdateText
    assert_equal "Easy Mode. No Level Caps. Normal EXP gain", PokeAccess::Info.info_text
    panel.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "the Randomizer and Nuzlocke panels are said once each, queued, with how to answer" do
    hint = PokeAccess::I18n.t(:dh_mode_ask_hint, :key => "C")
    { RandomizerWindow => "Randomizer. Randomized Items", NuzlockeWindow => "Nuzlocke. Shiny Pokémon are excluded" }.each do |klass, text|
      SpeakCapture.clear
      panel = klass.new
      2.times { panel.pbUpdateSprites }
      assert_equal [["#{text}. #{hint}", false]], SpeakCapture.log, klass.name
    end
  end

  test "the introduction's first page runs its lines together, queued" do
    GameIntroduction.new(INTRO).pbTextUpdate
    assert_equal [["Hello and welcome to Pokémon Dark Horizon!", false]], SpeakCapture.log
  end

  test "each next page of the introduction cuts in, also the first of a new phase" do
    intro = GameIntroduction.new(INTRO)
    intro.pbTextUpdate
    SpeakCapture.clear
    intro.pbTextUpdate
    intro.next_phase
    intro.pbTextUpdate
    assert_equal [["How would you best describe yourself?", true], ["You look fantastic!", true]], SpeakCapture.log
  end

  test "the TV report's pages are said the same way, and the info key keeps the page shown" do
    tv = TV_Window.new(TV)
    tv.pbTextUpdate
    tv.pbTextUpdate
    assert_equal [["...Good evening, dear viewers!", false],
                  ["Today on ONBS: We're talking about the two years since", true]], SpeakCapture.log
    assert_equal "Today on ONBS: We're talking about the two years since", PokeAccess::Info.info_text
  end

  test "keeps every screen's own returns" do
    assert_equal [:painted, :frame, :frame, :page, :page],
                 [EasyHardModeWindow.new.pbUpdateText, RandomizerWindow.new.pbUpdateSprites,
                  NuzlockeWindow.new.pbUpdateSprites, GameIntroduction.new(INTRO).pbTextUpdate,
                  TV_Window.new(TV).pbTextUpdate]
  end
end
