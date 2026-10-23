# PokéLiberty's icon pause menus (plugins/menu2_pausemenu.rb, Menu2): entries [icon, label, function] drawn as icons
# only; the focused one named by its icon (the grid's label fields are copies), the circular menu's by the formula it
# confirms with, and said again when an entry returns to the menu.
class Menu2PausemenuTest < PokeAccessTest
  ITEMS = [["bag", "Mochila", "openBag"], ["pokeball", "Equipo", "openParty"], ["trainer", "Mochila", "openTrainerCard"],
           ["save", "Mochila", "openSave"], ["exit", "Mochila", "exitMenu"]]

  test "the grid names the focused entry by its icon, not its copied label" do
    PokeAccess::Menu2Pause.focus(menu(2))
    assert_equal [[PokeAccess::I18n.t(:m2_trainer), true]], SpeakCapture.log
  end

  test "the circular menu names the entry it would confirm, also before the index wraps" do
    { 1 => :m2_exit, 0 => :m2_bag, -1 => :m2_party, 5 => :m2_bag }.each do |sel, key|
      SpeakCapture.clear
      PokeAccess::Menu2Pause.focus(menu(sel, :@angle_per_item => 72))
      assert_equal [PokeAccess::I18n.t(key)], SpeakCapture.lines, "@selected_item #{sel}"
    end
  end

  test "an icon the table does not know is named by its label" do
    PokeAccess::Menu2Pause.focus(World.stub_scene(:@items => [["quests", "Misiones", "openQuests"]], :@selected_item => 0))
    assert_equal ["Misiones"], SpeakCapture.lines
  end

  test "the same entry is said once until the cursor moves" do
    m = menu(0)
    2.times { PokeAccess::Menu2Pause.focus(m) }
    m.instance_variable_set(:@selected_item, 1)
    PokeAccess::Menu2Pause.focus(m)
    assert_equal [PokeAccess::I18n.t(:m2_bag), PokeAccess::I18n.t(:m2_party)], SpeakCapture.lines
  end

  test "back from an entry, the focused one is said again while the menu is up and still open" do
    m = menu(1)
    PokeAccess::Menu2Pause.focus(m)
    PokeAccess::Menu2Pause.watch(m)
    SpeakCapture.clear
    PokeAccess::Menu2Pause.returned
    assert_equal [PokeAccess::I18n.t(:m2_party)], SpeakCapture.lines
    SpeakCapture.clear
    m.instance_variable_set(:@exit, true)
    PokeAccess::Menu2Pause.returned
    PokeAccess::Menu2Pause.unwatch
    m.instance_variable_set(:@exit, false)
    PokeAccess::Menu2Pause.returned
    assert_nothing_spoken
  end

  private

  # A Menu2 with its cursor on sel and any extra ivars.
  def menu(sel, extra = {})
    World.stub_scene({ :@items => ITEMS, :@selected_item => sel }.merge(extra))
  end
end
