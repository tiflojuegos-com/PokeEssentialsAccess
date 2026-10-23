# The bag's rows as its list says them (the Window_PokemonBag reader): through the choose-item filter (v21) a row is
# the item its real index holds, the row after the last one shown closes the bag, and the info key follows the row.

# The bag's item list under the name the bag reader binds, as Essentials defines it.
Window_PokemonBag = Class.new(Window_DrawableCommand) unless defined?(Window_PokemonBag)

# v21's bag list: the pocket on show, read through @filterlist's real indices while a filter is set, then the row
# that closes the bag; item is nil past the last row.
class BagFilterWindow < Window_PokemonBag
  attr_reader :pocket

  def initialize(bag, filterlist, pocket, adapter)
    super()
    @bag = bag
    @filterlist = filterlist
    @pocket = pocket
    @adapter = adapter
  end

  def itemCount
    (@filterlist ? @filterlist[@pocket].length : @bag.pockets[@pocket].length) + 1
  end

  def item
    return nil if @filterlist && !@filterlist[@pocket][index]
    row = @filterlist ? @bag.pockets[@pocket][@filterlist[@pocket][index]] : @bag.pockets[@pocket][index]
    row ? row[0] : nil
  end
end

# A bag list that does not name its focused item, so the reader maps the filter itself.
class BagFilterUnnamedWindow < BagFilterWindow
  undef_method :item
end

# Gen-6's bag list (Pokemon Z): the pocket's own rows, and item 0, not nil, past the last one.
class BagFilterG6Window < Window_PokemonBag
  attr_reader :pocket

  def initialize(bag, pocket, adapter)
    super()
    @bag = bag
    @pocket = pocket
    @adapter = adapter
  end

  def itemCount
    @bag.pockets[@pocket].length + 1
  end

  def item
    row = @bag.pockets[@pocket][index]
    row ? row[0] : 0
  end
end

class BagFilterTest < PokeAccessTest
  NAMES = { :POTION => "Pocion", :REPEL => "Repelente", :RARECANDY => "Caramelo", :FULLHEAL => "Cura total" }
  POCKET = [[:POTION, 5], [:REPEL, 2], [:RARECANDY, 9], [:FULLHEAL, 1]]
  # The choose-item filter of pocket 1: its second and fourth items.
  FILTER = { 1 => [1, 3] }
  REPEL_DESC = "Ahuyenta a los Pokemon salvajes."
  # The Repel as the game's item data names it: what the info key says, and the row where no adapter names it.
  REPEL_DATA_NAME = "ItemREPEL"

  test "reads each filtered row as the item its real index holds" do
    win = window(bag, FILTER)
    { 0 => "Repelente: 2, #{list_place(1, 3)}", 1 => "Cura total: 1, #{list_place(2, 3)}" }.each do |row, said|
      assert_equal said, row_at(win, row), "filtered row #{row}"
    end
  end

  test "maps a filtered row to its real index itself when the list does not name its item" do
    win = BagFilterUnnamedWindow.new(bag, FILTER, 1, adapter)
    { 0 => "Repelente: 2, #{list_place(1, 3)}", 1 => "Cura total: 1, #{list_place(2, 3)}" }.each do |row, said|
      assert_equal said, row_at(win, row), "filtered row #{row}"
    end
  end

  test "reads each unfiltered row as the pocket's own, in v21 and in gen-6" do
    [window(bag, nil), BagFilterG6Window.new(bag, 1, adapter)].each do |win|
      said = (0..3).map { |row| row_at(win, row) }
      assert_equal ["Pocion: 5, #{list_place(1, 5)}", "Repelente: 2, #{list_place(2, 5)}",
                    "Caramelo: 9, #{list_place(3, 5)}", "Cura total: 1, #{list_place(4, 5)}"], said, win.class.name
    end
  end

  test "closes the bag on the row after the last one shown" do
    {
      [FILTER, 2]      => "past the filtered rows",
      [nil, 4]         => "past the pocket",
      [{ 1 => [] }, 0] => "under a filter that lists nothing"
    }.each do |(filter, row), what|
      assert_equal "#{PokeAccess::I18n.t(:mn_close_bag)}, #{list_place(row + 1, row + 1)}",
                   row_at(window(bag, filter), row), what
    end
  end

  test "closes gen-6's bag on the row after its last item, where the list answers item 0" do
    assert_equal "#{PokeAccess::I18n.t(:mn_close_bag)}, #{list_place(5, 5)}",
                 row_at(BagFilterG6Window.new(bag, 1, adapter), 4)
  end

  test "leaves the info key on the item of the filtered row, with the bag's own description" do
    row_at(window(bag, FILTER), 0)
    assert_equal "Repelente: 2, #{list_place(1, 3)}", PokeAccess::Info.row_text, "the row Ctrl+T says"
    assert_equal "#{REPEL_DATA_NAME}. #{REPEL_DESC}", PokeAccess::Info.info_text,
                 "the item T describes, with the description the bag shows"
  end

  test "reads a row through an adapter that gives no descriptions" do
    assert_equal "Repelente: 2, #{list_place(1, 3)}", row_at(BagFilterWindow.new(bag, FILTER, 1, adapter(false)), 0)
  end

  test "names a row as the game's item data does when the list has no adapter, or its adapter names nothing" do
    blank = Object.new
    def blank.getDisplayName(_id); ""; end
    { "no adapter" => nil, "a blank name" => blank }.each do |what, ad|
      assert_equal "#{REPEL_DATA_NAME}: 2, #{list_place(1, 3)}", row_at(BagFilterWindow.new(bag, FILTER, 1, ad), 0), what
    end
  end

  test "names gen-6's pocket before the first row read in it, not before the next" do
    with_pocket_names(:pocketNames => ["", "Objetos"]) do
      win = window(bag, nil)
      win.update
      win.index = 1
      win.update
      assert_equal [["Objetos. Pocion: 5, #{list_place(1, 5)}", false], ["Repelente: 2, #{list_place(2, 5)}", true]],
                   SpeakCapture.log
    end
  end

  test "names v21's pocket from pocket_names, which counts from the first pocket" do
    with_pocket_names(:pocket_names => ["Objetos", "Medicinas"]) do
      assert_equal "Objetos. Pocion: 5, #{list_place(1, 5)}", row_at(window(bag, nil), 0)
    end
  end

  test "says a filtered row again, at once, when its count changes under a still cursor with nothing said since" do
    held = bag
    win = window(held, FILTER)
    win.update
    win.update
    held.pockets[1][1][1] = 1
    win.update
    assert_equal [["Repelente: 2, #{list_place(1, 3)}", false], ["Repelente: 1, #{list_place(1, 3)}", true]],
                 SpeakCapture.log
  end

  private

  # A bag of one pocket, 1, holding a copy of POCKET's rows, which a test may change.
  def bag
    pockets = { 1 => POCKET.map { |r| r.dup } }
    b = Object.new
    b.define_singleton_method(:pockets) { pockets }
    b
  end

  # The bag screen's adapter: each item's display name from NAMES and, unless it gives no descriptions, the Repel's.
  def adapter(descriptions = true)
    a = Object.new
    def a.getDisplayName(id); NAMES[id] || id.to_s; end
    if descriptions
      def a.getDescription(id); id == :REPEL ? REPEL_DESC : ""; end
    end
    a
  end

  # v21's list over pocket 1 of the bag, under the filter given (nil for none).
  def window(held, filter)
    BagFilterWindow.new(held, filter, 1, adapter)
  end

  # What the bag reader says with the cursor on row.
  def row_at(win, row)
    win.index = row
    PokeAccess::Menus.focused_text(win)
  end

  # Runs the block with the game's PokemonBag naming its pockets through the class methods given (method => names);
  # a PokemonBag made for it is taken away afterwards, or the methods put back as they were.
  def with_pocket_names(methods)
    made = !Object.const_defined?(:PokemonBag)
    Object.const_set(:PokemonBag, Class.new) if made
    saved = methods.keys.map { |m| [m, PokemonBag.respond_to?(m) ? PokemonBag.method(m) : nil] }
    methods.each { |m, names| PokemonBag.define_singleton_method(m) { names } }
    yield
  ensure
    if made
      Object.send(:remove_const, :PokemonBag)
    else
      saved.each do |m, was|
        was ? PokemonBag.define_singleton_method(m, was) : PokemonBag.singleton_class.send(:remove_method, m)
      end
    end
  end
end
