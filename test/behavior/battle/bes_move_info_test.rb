# Essentials BES's move info screen (plugins/bes_move_info.rb, MoveInfoScene): the move under the arrows is read once
# when it changes, from the text the screen paints in paint order, with the type and the category it draws as pictures
# put after the name, and the dashes it paints for no power or no never-missing accuracy, and the 1 it paints for a power
# that varies, said in words.

BesInfoMove = Struct.new(:id, :type, :weather)
BesInfoMoveData = Struct.new(:type, :category, :basedamage, :accuracy)
BesInfoMoveUser = Struct.new(:moves)

# The screen: a script of move indexes, each shown for a frame. draw_info paints the rows the script's move has, as
# BES does: the name, four label and value pairs, the target pair, the secondary effect pair, the flags' label and
# one row per flag; a pair is painted in one call, a flag in its own.
class MoveInfoScene
  ROWS = {
    0 => [[["Surf", 24, 40]], [["Potencia:", 24, 78], ["90", 232, 78]], [["Precisión:", 24, 108], ["100", 232, 108]],
          [["PP:", 24, 138], ["15", 232, 138]], [["Prioridad:", 24, 168], ["0", 232, 168]],
          [["Objetivo:", 256, 78], ["Todos excepto usuario", 256, 108]],
          [["Efecto secundario:", 256, 138], ["10%", 256, 168]], [["Características:", 24, 206]],
          [["* Protegible", 44, 238]], [["* Reflectable", 184, 238]]],
    1 => [[["Gruñido", 24, 40]], [["Potencia:", 24, 78], ["---", 232, 78]], [["Precisión:", 24, 108], ["---", 232, 108]],
          [["PP:", 24, 138], ["40", 232, 138]], [["Prioridad:", 24, 168], ["+1", 232, 168]],
          [["Objetivo:", 256, 78], ["Todos los oponentes", 256, 108]],
          [["Efecto secundario:", 256, 138], ["---", 256, 168]], [["Características:", 24, 206]], [["* ---", 44, 238]]],
    2 => [[["Magnitud", 24, 40]], [["Potencia:", 24, 78], ["1", 232, 78]], [["Precisión:", 24, 108], ["100", 232, 108]],
          [["PP:", 24, 138], ["1", 232, 138]], [["Prioridad:", 24, 168], ["1", 232, 168]],
          [["Objetivo:", 256, 78], ["Uno", 256, 108]]]
  }.freeze

  def initialize(battler, battle, data, script)
    @battler = battler
    @battle = battle
    @datas = data.is_a?(Array) ? data : nil
    @movedata = @datas ? @datas[0] : data
    @script = script
    @current_index = 0
  end

  def draw_info
    ROWS[@current_index].each { |call| pbDrawTextPositions(nil, call) }
  end

  def main
    @script.each do |index|
      @current_index = index
      @movedata = @datas[index] if @datas
      PokeAccess::Frame.run_pollers
    end
    :closed
  end
end

# The plugin's registrations bound to the stand-in (the harness's own load of the file ran before it existed).
eval(Harness.source(File.join(Harness::ROOT, "plugins", "bes_move_info.rb")).split(/^end\n/, 2)[1], TOPLEVEL_BINDING,
     "plugins/bes_move_info.rb")

class BesMoveInfoTest < PokeAccessTest
  T = PokeAccess::I18n
  SURF = BesInfoMoveData.new(11, 1, 90, 100)
  GROWL = BesInfoMoveData.new(0, 2, 0, 0)

  # The game's helper for the type a move is drawn with, held only while a test runs: the move's own type but for the
  # one that follows the weather, and an error where there is no battle, as the screen then falls back to the move's own.
  def setup
    super
    helper = Module.new do
      def self.get_move_type(_battler, move, battle)
        raise "no battle" if battle.nil? && move.weather
        move.weather ? 10 : move.type
      end
    end
    Object.const_set(:MoveTypeHelper, helper)
  end

  def teardown
    Object.send(:remove_const, :MoveTypeHelper) if Object.const_defined?(:MoveTypeHelper)
    super
  end

  test "a move reads its name, type and category, then its figures, target and flags as painted" do
    scene([[0], SURF]).main
    want = ["Surf", T.t(:mv_type, :t => "Tipo11"), T.t(:cat_special), "Potencia: 90", "Precisión: 100", "PP: 15",
            "Prioridad: 0", "Objetivo: Todos excepto usuario", "Efecto secundario: 10%",
            "Características: Protegible, Reflectable"]
    assert_equal [[PokeAccess.sentences(want), false]], SpeakCapture.log
  end

  test "a move with no power and no accuracy says so in words, and leaves the dashes unsaid" do
    scene([[1], GROWL]).main
    want = ["Gruñido", T.t(:mv_type, :t => "Tipo0"), T.t(:cat_status), T.t(:mv_power, :p => T.t(:mv_power_none)),
            T.t(:mv_acc, :a => T.t(:mv_acc_perfect)), "PP: 40", "Prioridad: +1", "Objetivo: Todos los oponentes"]
    assert_equal [[PokeAccess.sentences(want), false]], SpeakCapture.log
  end

  test "a move whose power is the 1 that stands for a varying one says so in words; any other figure of 1 stays" do
    scene([[2], BesInfoMoveData.new(4, 0, 1, 100)]).main
    want = ["Magnitud", T.t(:mv_type, :t => "Tipo4"), T.t(:cat_physical), T.t(:mv_power, :p => T.t(:mv_power_var)),
            "Precisión: 100", "PP: 1", "Prioridad: 1", "Objetivo: Uno"]
    assert_equal [[PokeAccess.sentences(want), false]], SpeakCapture.log
  end

  test "a move with a power or an accuracy of 1 is given no words for none" do
    scene([[0], BesInfoMoveData.new(11, 1, 1, 1)]).main
    line = SpeakCapture.lines.first
    refute_includes line, T.t(:mv_power, :p => T.t(:mv_power_none))
    refute_includes line, T.t(:mv_acc, :a => T.t(:mv_acc_perfect))
  end

  test "a move whose data tells none of its figures is given no words for none" do
    scene([[0], Object.new]).main
    line = SpeakCapture.lines.first
    refute_includes line, T.t(:mv_power, :p => T.t(:mv_power_none))
    refute_includes line, T.t(:mv_acc, :a => T.t(:mv_acc_perfect))
  end

  test "a screen with no move under the arrows reads nothing" do
    assert_nil PokeAccess::BesMoveInfo.reading(Object.new)
  end

  test "the type is the one the game's helper works out, else the move's own" do
    weather = BesInfoMove.new(57, 11, true)
    scene([[0], SURF], BesInfoMoveUser.new([weather, weather]), :battle).main
    assert_includes SpeakCapture.lines.first, T.t(:mv_type, :t => "Tipo10")
    SpeakCapture.clear
    scene([[0], SURF], BesInfoMoveUser.new([weather, weather]), nil).main
    assert_includes SpeakCapture.lines.first, T.t(:mv_type, :t => "Tipo11")
  end

  test "switching move reads the new one, interrupting, and staying on one reads nothing more" do
    scene([[0, 0, 1], [SURF, GROWL]]).main
    assert_equal [false, true], SpeakCapture.log.map { |_, interrupt| interrupt }
    assert_match(/\ASurf/, SpeakCapture.lines[0])
    assert_match(/\AGruñido/, SpeakCapture.lines[1])
  end

  test "the info key keeps the flags at any verbosity" do
    texts = vb_levels do
      scene([[0], SURF]).main
      PokeAccess::Info.info_text
    end
    texts.each { |text| assert_includes text, "Características: Protegible, Reflectable" }
  end

  test "the flags are left out at brief verbosity" do
    lines = vb_levels do
      SpeakCapture.clear
      scene([[0], SURF]).main
      SpeakCapture.lines.first
    end
    refute_includes lines[0], "Características"
    assert_includes lines[2], "Características: Protegible, Reflectable"
  end

  test "a move painted with no flags says no flags line" do
    scene([[1], GROWL]).main
    refute_includes SpeakCapture.lines.first, "Características"
  end

  test "the line reaches the info key" do
    scene([[0], SURF]).main
    assert_equal SpeakCapture.lines.first, PokeAccess::Info.info_text
  end

  private

  def scene(script_and_data, user = BesInfoMoveUser.new([BesInfoMove.new(57, 11, false), BesInfoMove.new(45, 0, false)]),
            battle = :battle)
    script, data = script_and_data
    MoveInfoScene.new(user, battle, data, script)
  end
end
