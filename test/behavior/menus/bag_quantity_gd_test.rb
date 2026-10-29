# A bag row's count, said where the item data's show_quantity? says so (Anil's offerings too); its registrable mark on
# a hidden count (in Royal, on any item the quick menu takes); and the PC's item storage, counted by the same rule.

# Window_PokemonItemStorage as the PC's item storage holds its rows: @bag of [item, count], named by @adapter.
class Window_PokemonItemStorage
  attr_accessor :index

  def initialize(bag, adapter); @bag = bag; @adapter = adapter; @index = 0; end
end

class BagQuantityGdTest < PokeAccessTest
  T = PokeAccess::I18n
  ROWS = [[:KEYBIKE, 1], [:KEYQTY_OFFERING, 3], [:POTION, 5], [:REPEL, 2]]

  # Royal's bag_registrable?, from games/royal/bag_register.rb evaluated once per process: the core's, the overrides
  # and the profiles are put back at once, and as_royal installs this one for a test.
  def self.royal_registrable
    @royal_registrable ||= begin
      menus = PokeAccess::Menus
      core = menus.method(:bag_registrable?)
      overrides = PokeAccess::Hooks.overrides.length
      profiles = PokeAccess::Game.profiles.dup
      path = File.join(Harness::ROOT, "games", "royal_common", "bag_register.rb")
      eval(Harness.source(path), TOPLEVEL_BINDING, path)
      royal = menus.method(:bag_registrable?)
      menus.define_singleton_method(:bag_registrable?, core)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
      royal
    end
  end

  test "reads a key item without a count" do
    assert_equal "ItemKEYBIKE, #{list_place(1, 5)}", bag_row(0)
  end

  test "reads a key item that shows its count with it" do
    assert_equal "ItemKEYQTY_OFFERING: 3, #{list_place(2, 5)}", bag_row(1)
  end

  test "reads an ordinary item with its count" do
    assert_equal "ItemPOTION: 5, #{list_place(3, 5)}", bag_row(2)
  end

  test "reads the row past the last item as the close-bag label" do
    assert_equal "#{T.t(:mn_close_bag)}, #{list_place(5, 5)}", bag_row(4)
  end

  test "counts the rows itself in a window that has no itemCount" do
    rows = (3..4).map do |i|
      win = Struct.new(:pocket).new(1)
      win.instance_variable_set(:@bag, bag_of(ROWS))
      PokeAccess::Menus.bag_row(win, i)
    end
    assert_equal ["ItemREPEL: 2, #{list_place(4, 5)}", "#{T.t(:mn_close_bag)}, #{list_place(5, 5)}"], rows
  end

  test "names a row its adapter leaves blank from the item data" do
    adapter = Object.new
    def adapter.getDisplayName(_item); ""; end
    assert_equal "ItemPOTION: 5, #{list_place(3, 5)}", bag_row(2, [], adapter)
  end

  test "marks registrable an item with a hidden count that the game would register" do
    with_register_rule([:KEYBIKE, :POTION]) do
      assert_equal "ItemKEYBIKE, #{T.t(:bag_registrable)}, #{list_place(1, 5)}", bag_row(0)
    end
  end

  test "leaves unmarked an item with a count, though the game would register it" do
    with_register_rule([:KEYBIKE, :POTION]) do
      assert_equal "ItemPOTION: 5, #{list_place(3, 5)}", bag_row(2)
    end
  end

  test "marks a registered item registered and not registrable" do
    with_register_rule([:KEYBIKE]) do
      assert_equal "ItemKEYBIKE, #{T.t(:bag_registered)}, #{list_place(1, 5)}", bag_row(0, [:KEYBIKE])
    end
  end

  test "in Royal, marks an ordinary item the quick menu would take, its count kept beside the mark" do
    as_royal([:REPEL]) do
      assert_equal "ItemREPEL: 2, #{T.t(:bag_registrable)}, #{list_place(4, 5)}", bag_row(3)
    end
  end

  test "in Royal, an item already registered is marked registered and not registrable" do
    as_royal([:REPEL]) do
      assert_equal "ItemREPEL: 2, #{T.t(:bag_registered)}, #{list_place(4, 5)}", bag_row(3, [:REPEL])
    end
  end

  test "in Royal, an item the quick menu would not take carries no mark" do
    as_royal([:REPEL]) do
      assert_equal "ItemPOTION: 5, #{list_place(3, 5)}", bag_row(2)
    end
  end

  test "the PC's item storage counts an item as the bag does" do
    { 0 => "KEYBIKE", 1 => "KEYQTY_OFFERING: 3", 2 => "POTION: 5" }.each do |i, row|
      assert_equal row, storage_row(i), "row #{i}"
    end
  end

  test "the PC's item storage reads the row past its items as cancel" do
    assert_equal T.t(:pc_cancel), storage_row(3)
  end

  private

  # Row i of a one-pocket bag holding ROWS, its list registering the items given and no old slot, named by the
  # adapter given (none: by the item data).
  def bag_row(i, registered = [], adapter = nil)
    win = Struct.new(:pocket, :itemCount).new(1, ROWS.length + 1)
    win.instance_variable_set(:@bag, bag_of(ROWS, registered))
    win.instance_variable_set(:@adapter, adapter)
    PokeAccess::Menus.bag_row(win, i)
  end

  # A bag whose one pocket holds rows, its list registering the items given.
  def bag_of(rows, registered = [])
    bag = Object.new
    bag.define_singleton_method(:pockets) { { 1 => rows } }
    bag.define_singleton_method(:registered?) { |item| registered.include?(item) }
    bag
  end

  # The PC item storage's text with row i focused, its adapter naming each item by its id.
  def storage_row(i)
    adapter = Object.new
    def adapter.getDisplayName(item); item.to_s; end
    win = Window_PokemonItemStorage.new(ROWS.first(3), adapter)
    win.index = i
    PokeAccess::Menus.focused_text(win)
  end

  # Runs the block with the game's pbCanRegisterItem? taking only the items given, whatever was there put back after.
  def with_register_rule(takes, &blk)
    GameFunctions.with(:pbCanRegisterItem? => lambda { |item| takes.include?(item) }, &blk)
  end

  # Runs the block with Royal's bag_registrable? in the bag reader and the game's pbCanRegisterItem? taking only the
  # items given; the core's put back after.
  def as_royal(takes)
    menus = PokeAccess::Menus
    core = menus.method(:bag_registrable?)
    royal = self.class.royal_registrable
    with_register_rule(takes) do
      menus.define_singleton_method(:bag_registrable?, royal)
      yield
    end
  ensure
    menus.define_singleton_method(:bag_registrable?, core)
  end
end
