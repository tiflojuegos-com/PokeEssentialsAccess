# Elite Battle: DX's fight menu (plugins/ebdx.rb): its own pbFightMenu drives FightWindowEBDX and never the stock
# Battle::Scene::FightMenu the core reads, which left Dark Horizon's moves silent. The move under the cursor is read as
# its button paints it, with the battle_move details; and the mechanic buttons, Mega Evolution and the ZUD patch's
# (Golden Crown), are said as they come up and on each press.
require File.expand_path("ebdx_stand_ins", File.dirname(__FILE__))

class EbdxFightGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "opening the move menu reads the focused move with its details, queued" do
    open_menu(battler)
    assert_equal [[line("Placaje", :cat_physical, 40, 100, 35, 35), false]], SpeakCapture.log
    assert_equal :move, PokeAccess::Info.instance_variable_get(:@kind), "the info key holds the move"
  end

  test "moving the cursor reads the move now focused once, interrupting" do
    win = open_menu(battler)
    SpeakCapture.clear
    win.index = 1
    win.update
    win.update
    assert_equal [[line("Rayo", :cat_special, 90, 100, 15, 15), true]], SpeakCapture.log
  end

  test "the category is the one the button shows and the PP the one it writes" do
    move = EbdxMove.new(:SHELLSIDEARM, "Brazo Concha", nil, 1, 4, 16, 90, 100)
    open_menu(EbdxBattler.new(0, "Slowbro", [move]))
    assert_equal [[line("Brazo Concha", :cat_special, 90, 100, 4, 16), false]], SpeakCapture.log
  end

  test "a name the button cut short is said whole, a painted Z kept" do
    cut = EbdxMove.new(:ALLOUTPUMMELING, "All-Out Pummeling", "All-Out Pummel...", 0, 1, 1, 175, 0)
    status = EbdxMove.new(:GROWL, "Gruñido", "Z-Gruñido", 2, 40, 40, 0, 100)
    win = open_menu(EbdxBattler.new(0, "Machamp", [cut, status]))
    win.index = 1
    win.update
    assert_equal [line("All-Out Pummeling", :cat_physical, 175, 0, 1, 1), line("Z-Gruñido", :cat_status, 0, 100, 40, 40)],
                 SpeakCapture.lines
  end

  test "reopened for another battler, the menu reads its focused move again" do
    win = open_menu(battler)
    SpeakCapture.clear
    win.update
    open_menu(battler, win)
    assert_equal [[line("Placaje", :cat_physical, 40, 100, 35, 35), false]], SpeakCapture.log
  end

  test "the Mega button is said available after the move, then on and off on each press" do
    win = open_menu(battler) { |w| w.megaButton }
    assert_equal [line("Placaje", :cat_physical, 40, 100, 35, 35), T.t(:bt_mega_ready)], SpeakCapture.lines
    SpeakCapture.clear
    win.megaButtonTrigger
    win.update
    win.megaButtonTrigger
    win.update
    assert_equal [[T.t(:bt_mega_on), true], [T.t(:bt_mega_off), true]], SpeakCapture.log
  end

  test "a Z-Move press says it on and the renamed move after it; going back says it off and the move again" do
    base = battler
    win = open_menu(base) { |w| w.zMoveButton }
    assert_equal [line("Placaje", :cat_physical, 40, 100, 35, 35), special(:bt_special_ready)], SpeakCapture.lines
    SpeakCapture.clear
    plain = base.moves
    base.moves = [EbdxMove.new(:BREAKNECKBLITZ, "Breakneck Blitz", nil, 0, 1, 1, 100, 0)] + plain[1..-1]
    win.generateButtons
    win.showPlay
    win.zMoveButtonTrigger
    win.update
    assert_equal [[special(:bt_special_on), true], [line("Breakneck Blitz", :cat_physical, 100, 0, 1, 1), false]],
                 SpeakCapture.log
    SpeakCapture.clear
    base.moves = plain
    win.generateButtons
    win.showPlay
    win.update
    assert_equal [[special(:bt_special_off), true], [line("Placaje", :cat_physical, 40, 100, 35, 35), false]],
                 SpeakCapture.log
  end

  test "the Ultra Burst button is said available, then on and off, the move not read again" do
    win = open_menu(battler) { |w| w.ultraButton }
    assert_equal T.t(:bt_ultra_ready), SpeakCapture.last
    SpeakCapture.clear
    win.ultraButtonTrigger
    win.update
    win.ultraButtonTrigger
    win.update
    assert_equal [[T.t(:bt_ultra_on), true], [T.t(:bt_ultra_off), true]], SpeakCapture.log
  end

  test "a menu with no mechanic button says none" do
    win = open_menu(battler)
    SpeakCapture.clear
    3.times { win.update }
    assert_nothing_spoken
  end

  private

  # A battler with Placaje (physical, 40 power, 35 PP) and Rayo (special, 90 power, 15 PP).
  def battler
    EbdxBattler.new(0, "Pikachu", [EbdxMove.new(:TACKLE, "Placaje", nil, 0, 35, 35, 40, 100),
                                   EbdxMove.new(:THUNDERBOLT, "Rayo", nil, 1, 15, 15, 90, 100)])
  end

  # Opens the window for b as EBDX's pbFightMenu does (battler, its mechanic buttons, the cursor, the buttons, the
  # slide-in) and runs the loop's first frame.
  def open_menu(b, win = FightWindowEBDX.new)
    win.battler = b
    yield win if block_given?
    win.index = 0
    win.generateButtons
    win.showPlay
    win.update
    win
  end

  # A move line at the full battle_move level, its type as the stub's move data names it.
  def line(name, cat, power, acc, pp, tot)
    PokeAccess::MoveInfo.line(name, "TypeTYPE1", power, acc, :cat => T.t(cat), :pp => pp, :total_pp => tot)
  end

  # A Z-Move toggle line.
  def special(key)
    T.t(key, :name => T.t(:bt_m_zmove))
  end
end
