# The fight line said as the fight cursor moves, and BattleScene.unheard: a move panel under it (the Deluxe Battle
# Kit's, Soulstones 2's edited copy) adds only what that line has not said; its first line since shut says it all.
class MovePanelUnheardGdTest < PokeAccessTest
  BS = PokeAccess::BattleScene
  # A move as the fight menu lists it.
  MOVE = Struct.new(:name, :type, :pp, :total_pp, :power, :accuracy, :category)
  # The battler choosing: its index and its moves.
  USER = Struct.new(:index, :moves)
  # What a panel shows of a move beyond the fight line.
  EXTRAS = ["prioridad +1", "Eficaz contra Rattata"]

  # The v21 fight menu, answering the battler whose moves it lists.
  class Menu < ::Battle::Scene::FightMenu
    attr_accessor :user
    def battler; @user; end
  end

  test "moving the fight cursor says the move it lands on, cutting in" do
    menu = Menu.new
    menu.user = USER.new(0, [tackle, ember])
    menu.index = 1
    t = PokeAccess::I18n
    line = [ember.name, type_of(ember), t.t(:cat_special), t.t(:mv_power, :p => 40), t.t(:mv_acc, :a => 100),
            t.t(:mv_pp, :pp => 25, :tot => 25)].join(". ")
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "under a moved cursor the panel adds only what the fight line did not say" do
    menu = moved_menu
    assert_equal EXTRAS, BS.unheard(menu.user, 1, panel(ember))
  end

  test "a repaint of the same move adds nothing" do
    menu = moved_menu
    BS.unheard(menu.user, 1, panel(ember))
    assert_equal [], BS.unheard(menu.user, 1, panel(ember))
  end

  test "a mechanic staged on the same move adds only what it changed" do
    menu = moved_menu
    BS.unheard(menu.user, 1, panel(ember))
    staged = panel(ember).map { |p| p == type_of(ember) ? "Tipo Dragon" : p }
    assert_equal ["Tipo Dragon"], BS.unheard(menu.user, 1, staged)
  end

  test "the fight line said again for the same move starts over, and the panel adds its own again" do
    menu = moved_menu
    BS.unheard(menu.user, 1, panel(ember))
    BS.read_menu(menu)
    assert_equal EXTRAS, BS.unheard(menu.user, 1, panel(ember))
  end

  test "the panel's first line since it was shut says it all" do
    menu = moved_menu
    BS.unheard(menu.user, 1, panel(ember))
    BS.panel_shut
    assert_equal panel(ember), BS.unheard(menu.user, 1, panel(ember))
  end

  test "a panel on a move the fight line has not said says it all" do
    menu = moved_menu
    assert_equal panel(tackle), BS.unheard(menu.user, 0, panel(tackle))
  end

  test "the same slot of another battler is another move" do
    menu = moved_menu
    foe = USER.new(1, menu.user.moves)
    assert_equal panel(ember), BS.unheard(foe, 1, panel(ember))
  end

  test "the panels of two moves the fight line has not said each say all of theirs" do
    menu = moved_menu
    foe = USER.new(1, menu.user.moves)
    BS.unheard(foe, 0, panel(tackle))
    assert_equal panel(ember), BS.unheard(foe, 1, panel(ember))
  end

  private

  # The battler's two moves, as the fight menu lists them.
  def tackle; MOVE.new("Placaje", :NORMAL, 35, 35, 40, 100, 0); end

  def ember; MOVE.new("Ascuas", :FIRE, 25, 25, 40, 100, 1); end

  # The type phrase the fight line says of a move.
  def type_of(move)
    PokeAccess::I18n.t(:mv_type, :t => "Type#{move.type}")
  end

  # What a panel paints of a move: the phrases the fight line also says (name, type, power, accuracy, PP), then its
  # own.
  def panel(move)
    t = PokeAccess::I18n
    [move.name, type_of(move), t.t(:mv_power, :p => move.power), t.t(:mv_acc, :a => move.accuracy),
     t.t(:mv_pp, :pp => move.pp, :tot => move.total_pp)] + EXTRAS
  end

  # A fight menu whose panel opened under Tackle (its first line since shut) before the cursor moved on to Ember,
  # saying Ember's fight line.
  def moved_menu
    menu = Menu.new
    menu.user = USER.new(0, [tackle, ember])
    BS.panel_shut
    BS.read_menu(menu)
    BS.unheard(menu.user, 0, panel(tackle))
    menu.index = 1
    menu
  end
end
