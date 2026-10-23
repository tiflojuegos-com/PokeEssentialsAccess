# Infinite Fusion's clothes shops on the plain mart window: an action row (a bare symbol in the stock) reads its
# adapter's caption, the worn item says it is worn, and the info key and Ctrl+T get the row and its description.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

class MartSpecialRowsTest < PokeAccessTest
  # Infinite Fusion's clothes-shop adapter: names, prices and the special rows' captions; whether an item is worn is
  # answered by the adapter it wraps, whose worn hat is the top hat.
  class ClothesAdapter
    WornHat = Struct.new(:hat) do
      def isWornItem?(item); item == hat; end
    end

    def initialize(description = nil); @description = description; end
    def getAdapter; WornHat.new(:TOPHAT); end
    def getSpecialItemCaption(s); { :REMOVE_HAT => "Remove hat", :BLANK => "" }[s]; end
    def getDisplayName(item); { :TOPHAT => "Chistera", :CAP => "Gorra", :BLANK => "Nada" }[item]; end
    def getDisplayPrice(_item); "$500"; end
    def getDescription(_item); @description; end
  end

  # A clothes-shop adapter that gives no descriptions.
  class NoDescriptionsAdapter < ClothesAdapter
    undef_method :getDescription
  end

  # Forgets the description a shop noted last, module state the per-test reset leaves alone.
  def setup
    super
    PokeAccess::Info.note_item_desc(nil, nil)
  end

  test "an action row is read by the caption its adapter paints" do
    assert_equal "Remove hat", row(:REMOVE_HAT)
  end

  test "the info key says an action row's caption" do
    row(:REMOVE_HAT)
    assert_equal "Remove hat", PokeAccess::Info.info_text
  end

  test "the worn item says it is worn" do
    assert_equal "Chistera, $500, #{PokeAccess::I18n.t(:shop_worn)}", row(:TOPHAT)
  end

  test "any other item is an ordinary row" do
    assert_equal "Gorra, $500", row(:CAP)
  end

  test "a symbol whose caption is empty is an ordinary row" do
    assert_equal "Nada, $500", row(:BLANK)
  end

  test "the worn state is asked of the adapter itself before the one it wraps" do
    ad = ClothesAdapter.new
    def ad.isWornItem?(item); item == :CAP; end
    assert_equal "Gorra, $500, #{PokeAccess::I18n.t(:shop_worn)}", row(:CAP, ad), "its own yes"
    assert_equal "Chistera, $500", row(:TOPHAT, ad), "its own no, not asked again of the one it wraps"
  end

  test "the row past the stock is cancel" do
    assert_equal PokeAccess::I18n.t(:pc_cancel), row(:CANCEL_ROW)
  end

  test "Ctrl+T repeats an item's whole row" do
    row(:TOPHAT)
    assert_equal "Chistera, $500, #{PokeAccess::I18n.t(:shop_worn)}", PokeAccess::Info.row_text
  end

  test "the info key reads the description the shop shows, its question marks as unknown" do
    { "Un sombrero de copa." => "Un sombrero de copa.", "???" => PokeAccess::I18n.t(:pdx_unknown_short) }.each do |shown, said|
      row(:TOPHAT, ClothesAdapter.new(shown))
      assert_equal "ItemTOPHAT. #{said}", PokeAccess::Info.info_text, "the shop shows #{shown.inspect}"
    end
  end

  test "a shop that gives no descriptions leaves the info key to the item's description in the game data" do
    row(:TOPHAT, NoDescriptionsAdapter.new)
    said = with_data_description("Sombrero de fieltro.") { PokeAccess::Info.info_text }
    assert_equal "ItemTOPHAT. Sombrero de fieltro.", said
  end

  private

  # The focused row of a mart window over the shop's stock, with the cursor on item (:CANCEL_ROW is past the stock).
  def row(item, adapter = ClothesAdapter.new)
    stock = [:REMOVE_HAT, :TOPHAT, :CAP, :BLANK]
    win = Window_PokemonMart.new
    win.instance_variable_set(:@stock, stock)
    win.instance_variable_set(:@adapter, adapter)
    win.instance_variable_set(:@i, stock.index(item) || stock.length)
    def win.index; @i; end
    PokeAccess::Menus.focused_text(win)
  end

  # Runs the block with the game data describing every item as desc; the data's own lookup is put back after.
  def with_data_description(desc)
    data = PokeAccess::Data
    saved = data.method(:item_description)
    data.define_singleton_method(:item_description) { |_id| desc }
    yield
  ensure
    data.define_singleton_method(:item_description, saved)
  end
end
