# The Berrydex (TDW's Berry Core and Dex): the detail screen's sections follow the optional pages this copy shows (an
# absent or failing predicate is a no), and the list says a berry by number and name once registered, by number before.
class BerrydexTest < PokeAccessTest
  # The list's rows as the plugin keeps them: [berry, name, dex number].
  ROWS = [[:ORANBERRY, "Baya Aranja", 1], [:SITRUSBERRY, "Baya Zidra", 2]]

  test "lists all four sections where the copy shows the battle and mutation pages" do
    assert_equal [info, plant, battle, mutations],
                 PokeAccess::BerryDex.sections(screen(:pbShowBattlePage? => true, :pbShowMutationsPage? => true))
  end

  test "leaves out a page the copy answers no to" do
    assert_equal [info, plant, battle],
                 PokeAccess::BerryDex.sections(screen(:pbShowBattlePage? => true, :pbShowMutationsPage? => false))
  end

  test "lists the two base sections for a copy with neither predicate" do
    assert_equal [info, plant], PokeAccess::BerryDex.sections(screen({}))
  end

  test "a predicate that raises counts as no" do
    failing = RuntimeError.new("the page is not built")
    assert_equal [info, plant, mutations],
                 PokeAccess::BerryDex.sections(screen(:pbShowBattlePage? => failing, :pbShowMutationsPage? => true))
  end

  test "a private predicate still counts" do
    scene = screen(:pbShowBattlePage? => true)
    scene.singleton_class.send(:private, :pbShowBattlePage?)
    assert_equal [info, plant, battle], PokeAccess::BerryDex.sections(scene)
  end

  test "says a registered berry by its number and name" do
    GameFunctions.with(:pbBerryRegistered? => lambda { |id| id == :ORANBERRY }) do
      assert_equal PokeAccess::I18n.t(:bdx_entry, :num => 1, :name => "Baya Aranja"),
                   PokeAccess::BerryDex.entry_text(list(ROWS), 0)
    end
  end

  test "says a berry the game has not registered by its number alone, not the dashes it paints" do
    GameFunctions.with(:pbBerryRegistered? => lambda { |id| id == :ORANBERRY }) do
      assert_equal PokeAccess::I18n.t(:bdx_unknown, :num => 2), PokeAccess::BerryDex.entry_text(list(ROWS), 1)
    end
  end

  test "says a berry by its number alone where the registry fails" do
    GameFunctions.with(:pbBerryRegistered? => lambda { |_id| raise "no save data" }) do
      assert_equal PokeAccess::I18n.t(:bdx_unknown, :num => 1), PokeAccess::BerryDex.entry_text(list(ROWS), 0)
    end
  end

  test "says nothing past the list, without one, or for a row whose number cannot be read" do
    { "an index past the list" => [list(ROWS), 9], "no row list" => [list(nil), 0],
      "an unreadable number" => [list([[:ORANBERRY, "Baya Aranja", Object.new]]), 0] }.each do |what, (win, i)|
      assert_nil PokeAccess::BerryDex.entry_text(win, i), what
    end
  end

  private

  def info; PokeAccess::I18n.t(:bdx_page_info); end
  def plant; PokeAccess::I18n.t(:bdx_page_plant); end
  def battle; PokeAccess::I18n.t(:bdx_page_battle); end
  def mutations; PokeAccess::I18n.t(:bdx_page_mut); end

  # A detail screen answering each predicate as given: true or false, or an exception it raises.
  def screen(predicates)
    scene = Object.new
    predicates.each do |name, answer|
      scene.define_singleton_method(name) { answer.is_a?(Exception) ? raise(answer) : answer }
    end
    scene
  end

  # The list window holding rows in @commands, as Window_Berrydex keeps them.
  def list(rows)
    win = Object.new
    win.instance_variable_set(:@commands, rows)
    win
  end
end
