# The v21 fight menu's mechanic button (Battle::Scene::MenuBase): setIndexAndMode opens the menu without mode=, so its
# hook reads the first move, queued, primes the button's state from the opening mode and says a button that opens
# available; each press on mode= then says the mechanic on or off, by the name the Deluxe Battle Kit gave it, and
# reads the move again.
class MegaToggleGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "opening with the button available reads the move, then says the mechanic ready, both queued" do
    with_special(nil) { fight_menu.setIndexAndMode(0, 1) }
    assert_equal [[move_line, false], [T.t(:bt_mega_ready), false]], SpeakCapture.log
  end

  test "opening with no move under the cursor says only the mechanic ready" do
    with_special(nil) { Battle::Scene::FightMenu.new.setIndexAndMode(0, 1) }
    assert_equal [[T.t(:bt_mega_ready), false]], SpeakCapture.log
  end

  test "opening with the button hidden or already pressed reads only the move" do
    [0, 2].each do |mode|
      SpeakCapture.clear
      with_special(nil) { fight_menu.setIndexAndMode(0, mode) }
      assert_equal [[move_line, false]], SpeakCapture.log, "mode #{mode}"
    end
  end

  test "names the mechanic the kit opened the menu for as it comes up" do
    named = lambda { |key| T.t(:bt_special_ready, :name => T.t(key)) }
    { :mega => T.t(:bt_mega_ready), true => T.t(:bt_mega_ready), :ultra => T.t(:bt_ultra_ready),
      :dynamax => named.call(:bt_m_dynamax), :zmove => named.call(:bt_m_zmove), :tera => named.call(:bt_m_tera),
      :style => T.t(:bt_special_other_ready) }.each do |action, ready|
      SpeakCapture.clear
      with_special(action) { fight_menu.setIndexAndMode(0, 1) }
      assert_equal [[move_line, false], [ready, false]], SpeakCapture.log, "opened for #{action.inspect}"
    end
  end

  test "the first press after opening says the mechanic on, then the move again, queued" do
    menu = fight_menu
    with_special(nil) do
      menu.setIndexAndMode(0, 1)
      SpeakCapture.clear
      menu.mode = 2
    end
    assert_equal [[T.t(:bt_mega_on), true], [move_line, false]], SpeakCapture.log
  end

  test "a press back from registered says the mechanic off" do
    menu = fight_menu
    with_special(nil) do
      menu.setIndexAndMode(0, 2)
      SpeakCapture.clear
      menu.mode = 1
    end
    assert_equal [[T.t(:bt_mega_off), true], [move_line, false]], SpeakCapture.log
  end

  test "names a kit mechanic on each press, and words one it has no name for generically" do
    { :dynamax => [T.t(:bt_special_on, :name => T.t(:bt_m_dynamax)), T.t(:bt_special_off, :name => T.t(:bt_m_dynamax))],
      :style => [T.t(:bt_special_other_on), T.t(:bt_special_other_off)] }.each do |action, (on, off)|
      menu = fight_menu
      with_special(action) do
        menu.setIndexAndMode(0, 1)
        SpeakCapture.clear
        menu.mode = 2
        menu.mode = 1
      end
      assert_equal [[on, true], [move_line, false], [off, true], [move_line, false]], SpeakCapture.log, "for #{action}"
    end
  end

  test "says nothing when the button is hidden or set to what it was, whatever the mechanic" do
    [nil, :dynamax].each do |action|
      menu = fight_menu
      with_special(action) do
        menu.setIndexAndMode(0, 1)
        SpeakCapture.clear
        menu.mode = 1
        menu.mode = 0
      end
      assert_nothing_spoken "opened for #{action.inspect}"
    end
  end

  test "another menu says no mechanic and reads no move, even over a battler with moves" do
    menu = fight_menu(Battle::Scene::MenuBase)
    with_special(nil) do
      menu.setIndexAndMode(0, 1)
      menu.mode = 2
      menu.mode = 1
    end
    assert_nothing_spoken
  end

  private

  # A v21 fight menu, or a menu of another kind, on a battler whose one move is Rayo (electric, special, 90 power, 100
  # accuracy, 15 pp).
  def fight_menu(kind = Battle::Scene::FightMenu)
    shape = Struct.new(:name, :type, :category, :power, :accuracy, :pp, :total_pp)
    move = shape.new("Rayo", :ELECTRIC, 1, 90, 100, 15, 15)
    battler = Struct.new(:index, :moves).new(0, [move])
    menu = kind.new
    menu.define_singleton_method(:battler) { battler }
    menu
  end

  # The fight menu's line for that move, as the stub's type data names its type.
  def move_line
    ["Rayo", T.t(:mv_type, :t => "TypeELECTRIC"), T.t(:cat_special), T.t(:mv_power, :p => "90"),
     T.t(:mv_acc, :a => 100), T.t(:mv_pp, :pp => 15, :tot => 15)].join(". ")
  end

  # Runs the block with the fight menu opened for action, as the kit's pbFightMenu passes it, then puts back the one
  # noted before and the fight line the move panel keeps from the menu's reads.
  def with_special(action)
    was = PokeAccess::Battle.special_action
    line = PokeAccess::BattleScene.instance_variable_get(:@fight_line)
    PokeAccess::Battle.note_special_action(action)
    yield
  ensure
    PokeAccess::Battle.note_special_action(was)
    PokeAccess::BattleScene.instance_variable_set(:@fight_line, line)
  end
end
