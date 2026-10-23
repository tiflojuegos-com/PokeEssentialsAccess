# The v22 bag (UI::BagVisuals), whose item list is inactive: the focused item is read on the screen's cursor callback
# (refresh_on_index_changed) and a pocket change on set_pocket, which primes the callback so neither repeats the other.
class BagV22GdTest < PokeAccessTest
  T = PokeAccess::I18n
  ITEMS = [[:POTION, 3], [:REPEL, 2], [:TM01, 1], [:KEYCARD, 1]]
  MEDICINE = [[:ELIXIR, 7], [:REVIVE, 2]]

  test "reads the focused item with its count, interrupting" do
    bag_screen.set_index(0)
    assert_equal [[T.t(:bag_item, :name => "ItemPOTION", :qty => 3), true]], SpeakCapture.log
  end

  test "says nothing when the screen redraws the entry already read" do
    vis = bag_screen
    vis.set_index(0)
    SpeakCapture.clear
    vis.refresh_on_index_changed(0)
    assert_nothing_spoken
  end

  test "reads the entry the cursor moves to" do
    vis = bag_screen
    vis.set_index(0)
    SpeakCapture.clear
    vis.set_index(1)
    assert_equal [[T.t(:bag_item, :name => "ItemREPEL", :qty => 2), true]], SpeakCapture.log
  end

  test "a bag opened again reads the entry under its cursor again" do
    bag = TestBag.new({ :Items => ITEMS }, :Items)
    UI::BagVisuals.new(bag).set_index(0)
    SpeakCapture.clear
    UI::BagVisuals.new(bag).set_index(0)
    assert_equal [[T.t(:bag_item, :name => "ItemPOTION", :qty => 3), true]], SpeakCapture.log
  end

  test "reads a machine by the display name that carries the move it teaches" do
    bag_screen.set_index(2)
    assert_equal [[T.t(:bag_item, :name => "ItemTM01 MoveTHUNDERBOLT", :qty => 1), true]], SpeakCapture.log
  end

  test "reads an important item by name alone" do
    bag_screen.set_index(3)
    assert_equal [["ItemKEYCARD", true]], SpeakCapture.log
  end

  test "reads the row past the last item as the close-bag label" do
    bag_screen.set_index(4)
    assert_equal [[T.t(:mn_close_bag), true]], SpeakCapture.log
  end

  test "counts a single item as one, and reads one with none left by name alone" do
    lines = { [:POTION, 1] => T.t(:bag_item, :name => "ItemPOTION", :qty => 1), [:ELIXIR, 0] => "ItemELIXIR" }
    lines.each do |entry, line|
      SpeakCapture.clear
      UI::BagVisuals.new(TestBag.new({ :Items => [entry] }, :Items)).set_index(0)
      assert_equal [[line, true]], SpeakCapture.log, "for #{entry.inspect}"
    end
  end

  test "reads an item by name alone when the bag cannot count it" do
    bag = TestBag.new({ :Items => ITEMS }, :Items)
    def bag.quantity(_item); raise NoMethodError, "no quantity"; end
    UI::BagVisuals.new(bag).set_index(0)
    assert_equal [["ItemPOTION", true]], SpeakCapture.log
  end

  test "reads by name alone an item whose data cannot say whether it shows a count" do
    old = Object.new
    def old.display_name; "Pocion vieja"; end
    with_item_data(:OLDPOTION => old) do
      UI::BagVisuals.new(TestBag.new({ :Items => [[:OLDPOTION, 2]] }, :Items)).set_index(0)
    end
    assert_equal [["Pocion vieja", true]], SpeakCapture.log
  end

  test "reads an item the game data does not know by its id" do
    with_item_data(:MYSTERY => nil) do
      UI::BagVisuals.new(TestBag.new({ :Items => [[:MYSTERY, 2]] }, :Items)).set_index(0)
    end
    assert_equal [["MYSTERY", true]], SpeakCapture.log
  end

  test "leaves an item the game data does not know off the info key" do
    with_item_data(:MYSTERY => nil) do
      UI::BagVisuals.new(TestBag.new({ :Items => [[:MYSTERY, 2]] }, :Items)).set_index(0)
    end
    assert_nil PokeAccess::Info.info_text
  end

  test "puts the focused item on the info key, with the move a machine teaches" do
    bag_screen.set_index(2)
    assert_equal "ItemTM01. idescTM01. #{T.t(:it_teaches, :move => 'MoveTHUNDERBOLT')}. descTHUNDERBOLT",
                 PokeAccess::Info.info_text
  end

  test "a pocket change says the pocket and its focused item in one line, interrupting" do
    vis = bag_screen
    vis.set_index(3)
    SpeakCapture.clear
    vis.set_pocket(:Medicine)
    line = "#{T.t(:bag_pocket, :name => 'Medicine')}. #{T.t(:bag_item, :name => 'ItemELIXIR', :qty => 7)}"
    assert_equal [[line, true]], SpeakCapture.log
  end

  test "after a pocket change, the cursor callback on the same entry stays silent" do
    vis = bag_screen
    vis.set_pocket(:Medicine)
    SpeakCapture.clear
    vis.refresh_on_index_changed(3)
    assert_nothing_spoken
  end

  test "after a pocket change, a move inside the new pocket is read" do
    vis = bag_screen
    vis.set_pocket(:Medicine)
    SpeakCapture.clear
    vis.set_index(1)
    assert_equal [[T.t(:bag_item, :name => "ItemREVIVE", :qty => 2), true]], SpeakCapture.log
  end

  test "a pocket with no name says its focused item alone" do
    vis = UI::BagVisuals.new(TestBag.new({ :Items => ITEMS, "" => MEDICINE }, :Items))
    vis.set_pocket("")
    assert_equal [[T.t(:bag_item, :name => "ItemELIXIR", :qty => 7), true]], SpeakCapture.log
  end

  test "a pocket change onto an item with no name says the pocket alone" do
    blank = Object.new
    def blank.display_name; ""; end
    def blank.show_quantity?; false; end
    vis = UI::BagVisuals.new(TestBag.new({ :Items => ITEMS, :Medicine => [[:NAMELESS, 1]] }, :Items))
    with_item_data(:NAMELESS => blank) { vis.set_pocket(:Medicine) }
    assert_equal [[T.t(:bag_pocket, :name => "Medicine"), true]], SpeakCapture.log
  end

  private

  # A bag screen open on the Items pocket (a stackable item, another, a machine and an important item) with the
  # Medicine pocket beside it.
  def bag_screen
    UI::BagVisuals.new(TestBag.new({ :Items => ITEMS, :Medicine => MEDICINE }, :Items))
  end

  # Runs the block with GameData::Item answering each id of map with its value, raising for a nil one as for an id
  # the data lacks; every other id as the stub answers it.
  def with_item_data(map)
    real = GameData::Item.method(:get)
    GameData::Item.define_singleton_method(:get) do |id|
      next real.call(id) unless map.key?(id)
      map[id] || raise(KeyError, "no item #{id}")
    end
    yield
  ensure
    GameData::Item.define_singleton_method(:get, real)
  end
end
