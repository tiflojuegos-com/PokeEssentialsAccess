# Elite Battle: DX's command buttons, target buttons and battle question boxes (plugins/ebdx.rb), each its own window
# that the stock Battle::Scene menus the core reads never see: read as painted, the first line of each opening queued
# and each cursor move interrupting.
require File.expand_path("ebdx_stand_ins", File.dirname(__FILE__))

class EbdxMenusGdTest < PokeAccessTest
  T = PokeAccess::I18n
  # A target choice's data: how many battlers the move hits.
  Targets = Struct.new(:num_targets)

  test "opening the command menu reads the focused button as painted, queued; moving interrupts once" do
    cw = CommandWindowEBDX.new(single, %w[FIGHT BAG PARTY RUN])
    cw.refreshCommands(0)
    cw.update
    assert_equal [["FIGHT", false]], SpeakCapture.log
    assert_equal :battle_foe, PokeAccess::Info.instance_variable_get(:@kind), "the info key describes the foes"
    SpeakCapture.clear
    cw.index = 2
    cw.update
    cw.update
    assert_equal [["PARTY", true]], SpeakCapture.log
  end

  test "the buttons are read as compileCommands answers them, a game's own included" do
    cw = CommandWindowEBDX.new(single, %w[FIGHT PARTY CALL])
    cw.refreshCommands(0)
    cw.index = 2
    cw.update
    assert_equal ["CALL"], SpeakCapture.lines
  end

  test "reopened, the command menu reads its focused button again" do
    cw = CommandWindowEBDX.new(single, %w[FIGHT BAG PARTY RUN])
    cw.refreshCommands(0)
    cw.update
    SpeakCapture.clear
    cw.refreshCommands(0)
    cw.update
    assert_equal [["FIGHT", false]], SpeakCapture.log
  end

  test "with several Pokemon on the player's side, the one taking the orders is said first, queued" do
    battle = EbdxBattle.new([EbdxBattler.new(0, "Pikachu"), nil, EbdxBattler.new(2, "Eevee")], 2)
    cw = CommandWindowEBDX.new(battle, %w[FIGHT BAG PARTY RUN])
    cw.refreshCommands(2)
    cw.update
    assert_equal [["Eevee", false], ["FIGHT", false]], SpeakCapture.log
  end

  test "choosing a target reads the first one and its side, queued, then each the cursor moves to" do
    choose([1, 3], 0, 1)
    assert_equal [["Rattata, #{T.t(:bt_target_foe)}", false], ["Pidgey, #{T.t(:bt_target_foe)}", true]],
                 SpeakCapture.log
    assert_equal :text, PokeAccess::Info.instance_variable_get(:@kind), "the info key holds the target"
  end

  test "the chooser's own slot and its ally's are told apart" do
    choose([2, 0], 2, 1)
    assert_equal ["Eevee, #{T.t(:bt_target_self)}", "Pikachu, #{T.t(:bt_target_ally)}"], SpeakCapture.lines
  end

  test "a move that hits several battlers reads every one it lights" do
    choose([1], 0, 2, [nil, "Rattata", nil, "Pidgey"])
    assert_equal [["Rattata, #{T.t(:bt_target_foe)}. Pidgey, #{T.t(:bt_target_foe)}", false]], SpeakCapture.log
  end

  test "a fainted battler's button reads as an empty slot" do
    choose([3], 0, 1, ["Pikachu", "Rattata", "Eevee", ""])
    assert_equal ["#{T.t(:bt_empty_slot)}, #{T.t(:bt_target_foe)}"], SpeakCapture.lines
  end

  test "a cancelled target choice sends the move menu back to saying its focused move" do
    scene = choose([1], 0, 1)
    fw = scene.instance_variable_get(:@fightWindow)
    SpeakCapture.clear
    fw.update
    move = PokeAccess::MoveInfo.line("Placaje", "TypeTYPE1", 40, 100, :cat => T.t(:cat_physical), :pp => 35,
                                     :total_pp => 35)
    assert_equal [[move, false]], SpeakCapture.log, "queued, as a reopening"
  end

  test "a chosen target leaves the move menu as it was" do
    scene = choose([1], 0, 1, nil, 1)
    SpeakCapture.clear
    scene.instance_variable_get(:@fightWindow).update
    assert_nothing_spoken
  end

  test "a battle question's boxes read the first queued and each move interrupting" do
    box = ChoiceWindowEBDX.new(%w[Sí No])
    box.update
    box.index = 1
    box.update
    box.update
    assert_equal [["Sí", false], ["No", true]], SpeakCapture.log
  end

  private

  # A single battle with one Pokemon on each side.
  def single
    EbdxBattle.new([EbdxBattler.new(0, "Pikachu"), EbdxBattler.new(1, "Rattata")])
  end

  # Runs a target choice in a double battle and answers its scene: the chooser's move menu already read, the cursor on
  # each index of path in turn (the first where the window opens), for a move hitting num battlers, answering ret.
  def choose(path, chooser, num, texts = nil, ret = -1)
    scene = Battle::Scene.new
    fw = FightWindowEBDX.new
    fw.battler = EbdxBattler.new(chooser, "Pikachu", [EbdxMove.new(:TACKLE, "Placaje", nil, 0, 35, 35, 40, 100)])
    fw.generateButtons
    fw.update
    scene.instance_variable_set(:@fightWindow, fw)
    scene.instance_variable_set(:@targetWindow, TargetWindowEBDX.new)
    scene.instance_variable_set(:@target_texts, texts || %w[Pikachu Rattata Eevee Pidgey])
    scene.instance_variable_set(:@target_path, path)
    scene.instance_variable_set(:@target_ret, ret)
    SpeakCapture.clear
    scene.pbChooseTarget(chooser, Targets.new(num))
    scene
  end
end
