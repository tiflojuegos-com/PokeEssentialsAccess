# A bag row's marks on the gen-6 engine, from medium: registered, in each shape a bag keeps the registration (list,
# old slot, both as in Pokemon Z, the fangames' others), only on an important item, the one its bag paints the icon on;
# and registrable on an important item the game would register.
class BagRegisteredMarkTest < PokeAccessTest
  T = PokeAccess::I18n
  ROWS = [[:BICI, 1], [:CANA, 1], [:POCION, 3]]
  NAMES = { :BICI => "Bici", :CANA => "Caña Vieja", :POCION => "Poción" }
  IMPORTANT = [:BICI, :CANA]

  test "marks an item the list registers" do
    assert_equal "Bici, #{T.t(:bag_registered)}, #{list_place(1, 4)}", row(double_bag, 0)
  end

  test "marks the item the old slot still points at, as the row paints it" do
    assert_equal "Caña Vieja, #{T.t(:bag_registered)}, #{list_place(2, 4)}", row(double_bag, 1)
  end

  test "leaves unmarked an item neither the list nor the slot holds" do
    assert_equal "Poción: 3, #{list_place(3, 4)}", row(double_bag, 2)
  end

  test "takes no mark from a slot that holds a list rather than one item" do
    assert_equal "Caña Vieja, #{list_place(2, 4)}", row(double_bag([:CANA]), 1)
  end

  test "takes no mark from an empty slot" do
    assert_equal "Caña Vieja, #{list_place(2, 4)}", row(double_bag(nil), 1)
  end

  test "a bag with the list alone answers by the list" do
    bag = list_bag
    assert_equal ["Bici, #{T.t(:bag_registered)}, #{list_place(1, 4)}", "Caña Vieja, #{list_place(2, 4)}"],
                 [row(bag, 0), row(bag, 1)]
  end

  test "a bag with the old slot alone answers by the slot" do
    bag = slot_bag
    assert_equal ["Bici, #{list_place(1, 4)}", "Caña Vieja, #{T.t(:bag_registered)}, #{list_place(2, 4)}"],
                 [row(bag, 0), row(bag, 1)]
  end

  test "marks the row in each other shape a fangame keeps the registration" do
    { "pbIsRegistered?" => bag_with { |b| b.define_singleton_method(:pbIsRegistered?) { |item| item == :CANA } },
      "registeredItems" => bag_with { |b| b.define_singleton_method(:registeredItems) { [:CANA] } },
      "@registeredItem" => bag_with { |b| b.instance_variable_set(:@registeredItem, :CANA) },
      "@registeredItems" => bag_with { |b| b.instance_variable_set(:@registeredItems, [:CANA]) } }.each do |shape, bag|
      assert_equal ["Bici, #{list_place(1, 4)}", "Caña Vieja, #{T.t(:bag_registered)}, #{list_place(2, 4)}"],
                   [row(bag, 0), row(bag, 1)], shape
    end
  end

  test "says the mark from medium" do
    marked = "Bici, #{T.t(:bag_registered)}, #{list_place(1, 4)}"
    assert_equal ["Bici", marked, marked], vb_levels { row(double_bag, 0) }
  end

  test "leaves unmarked a registered item that shows its count, on which the bag paints no icon" do
    bag = bag_with { |b| b.define_singleton_method(:pbIsRegistered?) { |item| item == :POCION } }
    assert_equal "Poción: 3, #{list_place(3, 4)}", row(bag, 2)
  end

  test "registering an item that shows its count leaves its row's witness as it was" do
    registered = []
    bag = bag_with { |b| b.define_singleton_method(:pbIsRegistered?) { |item| registered.include?(item) } }
    before = witness(bag, 2)
    registered.push(:POCION)
    assert_equal before, witness(bag, 2)
  end

  test "marks registrable an important item the game would register, never an item with a count" do
    rows = GameFunctions.with(:pbCanRegisterItem? => lambda { |item| [:BICI, :POCION].include?(item) }) do
      [row(slot_bag, 0), row(slot_bag, 2)]
    end
    assert_equal ["Bici, #{T.t(:bag_registrable)}, #{list_place(1, 4)}", "Poción: 3, #{list_place(3, 4)}"], rows
  end

  private

  # A bag holding ROWS with no registration of its own, yielded to be given one.
  def bag_with
    bag = Object.new
    bag.define_singleton_method(:pockets) { { 1 => ROWS } }
    yield bag
    bag
  end

  # A bag whose list registers the bike and whose old slot holds slot, as Pokemon Z's keeps both.
  def double_bag(slot = :CANA)
    bag = list_bag
    bag.define_singleton_method(:registeredItem) { slot }
    bag
  end

  # A bag whose list (registered?) registers the bike, with no old slot.
  def list_bag
    bag = Object.new
    bag.define_singleton_method(:pockets) { { 1 => ROWS } }
    bag.define_singleton_method(:registered?) { |item| item == :BICI }
    bag
  end

  # A bag with only the old slot, holding the rod.
  def slot_bag
    bag = Object.new
    bag.define_singleton_method(:pockets) { { 1 => ROWS } }
    bag.define_singleton_method(:registeredItem) { :CANA }
    bag
  end

  # The bag's window over its one pocket, its close row counted.
  def window(bag)
    adapter = Object.new
    adapter.define_singleton_method(:getDisplayName) { |item| NAMES[item] }
    win = Struct.new(:pocket, :itemCount).new(1, ROWS.length + 1)
    win.instance_variable_set(:@bag, bag)
    win.instance_variable_set(:@adapter, adapter)
    win
  end

  # Row i of the bag's one pocket, named as the bag paints its items, IMPORTANT being the game's important items.
  def row(bag, i)
    GameFunctions.with(:pbIsImportantItem? => lambda { |item| IMPORTANT.include?(item) }) do
      PokeAccess::Menus.bag_row(window(bag), i)
    end
  end

  # The change witness of row i, IMPORTANT being the game's important items.
  def witness(bag, i)
    GameFunctions.with(:pbIsImportantItem? => lambda { |item| IMPORTANT.include?(item) }) do
      PokeAccess::Menus.bag_witness(window(bag), i)
    end
  end
end
