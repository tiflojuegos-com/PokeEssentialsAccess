# Dark Horizon's DiegoWT's Starter Selection (games/darkhorizon/starter_selection.rb): the box's request as the balls
# appear; the ball under the cursor by where it stands; the opened ball's question with each of the pair, shiny from
# brief and its types from medium; the question's own Yes and No; and the ball said again after a No.

# The screen as the game runs it: the text box, the pair the opened ball holds, pbStartChoosing waiting for a first
# key, pbAnimation every frame of the choosing loop, pbChoiceBoxes painting the answers, pbConfirm the question's loop
# (the block, ticking the pollers each frame as Input.update does) and pbChooseBall running both.
class DiegoWTsStarterSelection
  def initialize(first, second)
    @sprites = { "textbox" => Window_AdvancedTextPokemon.new("<ac>Choose your Pokémon.</ac>") }
    @pokemon = first
    @pokemon2 = second
    @endscene = 0
    @select = nil
  end

  def pbStartChoosing; :waiting; end

  def pbAnimation; :frame; end

  def pbChoiceBoxes(switch)
    if switch == 0
      pbDrawTextPositions(nil, [["Yes", 442, 192], ["No", 442, 238]])
      @choicesel = 1
    end
    :boxes
  end

  def pbConfirm
    yield self if block_given?
    @answer
  end

  def pbChooseBall(answer, &frames)
    @sprites["textbox"].text = "<ac>Will you choose #{@pokemon.name} & #{@pokemon2.name}?</ac>"
    pbChoiceBoxes(0)
    @answer = answer
    pbConfirm(&frames)
    @endscene = 1 if answer == 1
    :chose
  end
end

# The profile's shared helpers (constants.rb's module), loaded once and without the profile's settings.
unless defined?(PokeAccess::DarkHorizon)
  constants = File.join(Harness::ROOT, "games", "darkhorizon", "constants.rb")
  src = Harness.source(constants)
  part = src[/^module PokeAccess\r?\n.*?^end\r?\n/m]
  eval(part, TOPLEVEL_BINDING, constants, src[0, src.index(part)].count("\n") + 1)
end

starter_selection = File.join(Harness::ROOT, "games", "darkhorizon", "starter_selection.rb")
eval(Harness.source(starter_selection), TOPLEVEL_BINDING, starter_selection)

class DarkhorizonStartersGdTest < PokeAccessTest
  # A starter as the screen holds it: its name, its types and whether it is shiny.
  Mon = Struct.new(:name, :types, :shiny) do
    def shiny?; shiny ? true : false; end
  end

  test "the box's request is said as the balls appear, queued, with the keys" do
    screen.pbStartChoosing
    assert_equal [["Choose your Pokémon. #{t(:dh_starter_keys, :key => 'C')}", false]], SpeakCapture.log
  end

  test "the ball under the cursor is said by where it stands, the first queued and the next cutting in" do
    s = screen
    s.pbAnimation
    s.instance_variable_set(:@select, 2)
    2.times { s.pbAnimation }
    s.instance_variable_set(:@select, 3)
    s.pbAnimation
    assert_equal [["#{t(:dh_starter_ball_middle)}, #{list_place(2, 3)}", false],
                  ["#{t(:dh_starter_ball_right)}, #{list_place(3, 3)}", true]], SpeakCapture.log
  end

  test "an opened ball asks about its pair with each one's types, then reads its own Yes and No" do
    s = screen
    s.pbChooseBall(1) do |q|
      PokeAccess::Frame.run_pollers
      q.instance_variable_set(:@choicesel, 2)
      PokeAccess::Frame.run_pollers
    end
    assert_equal [["Will you choose Aipom & Yanma? Aipom, TypeNORMAL. Yanma, TypeBUG/TypeFLYING", false],
                  ["Yes", false], ["No", true]], SpeakCapture.log
  end

  test "at brief the question names the pair alone, and a shiny one is said shiny" do
    PokeAccess::Config.verbosity = :brief
    screen(Mon.new("Aipom", [:NORMAL], false), Mon.new("Yanma", [:BUG, :FLYING], true)).pbChooseBall(1)
    assert_equal [["Will you choose Aipom & Yanma? Yanma #{t(:pk_shiny)}", false]], SpeakCapture.log
  end

  test "the info key keeps the whole question" do
    PokeAccess::Config.verbosity = :brief
    screen.pbChooseBall(1)
    assert_equal "Will you choose Aipom & Yanma? Aipom, TypeNORMAL. Yanma, TypeBUG/TypeFLYING", PokeAccess::Info.info_text
  end

  test "after a No the ball under the cursor is said again" do
    s = screen
    s.instance_variable_set(:@select, 1)
    s.pbAnimation
    s.pbChooseBall(nil)
    SpeakCapture.clear
    s.pbAnimation
    assert_spoken_once(/\A#{Regexp.escape(t(:dh_starter_ball_left))}/)
  end

  test "keeps the screen's own returns" do
    s = screen
    assert_equal [:waiting, :frame, :boxes, :chose], [s.pbStartChoosing, s.pbAnimation, s.pbChoiceBoxes(1), s.pbChooseBall(1)]
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def screen(first = Mon.new("Aipom", [:NORMAL], false), second = Mon.new("Yanma", [:BUG, :FLYING], false))
    DiegoWTsStarterSelection.new(first, second)
  end
end
