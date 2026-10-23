# The Battle Point shop and the mart (core/menus/shops.rb): a row says the item and its price in its window's
# currency; while the screen is open, the bag count and what there is to spend are read when they change.
class BpShopGdTest < PokeAccessTest
  # A shop window as Shops.row reads it: the stock, the adapter and, in Soulstones 2's Achievement Points shop, the
  # currency it sells in (@useBP, kept only there).
  class RowWindow
    def initialize(stock, adapter, use_bp = nil)
      @stock = stock
      @adapter = adapter
      @useBP = use_bp unless use_bp.nil?
    end
  end

  # Soulstones 2's adapter: the price in Battle Points or, with use_bp false, in Achievement Points; a sale is priced
  # apart.
  class TwoCurrencyAdapter
    def getDisplayName(item); item.to_s; end

    def getDisplayPrice(_item, selling = false, use_bp = true)
      return "2 BP" if selling
      use_bp ? "4 BP" : "3 AP"
    end
  end

  # A one-currency shop's adapter, whose price takes two arguments: its name, price and description as given (a price
  # that is an exception is raised).
  class Adapter
    def initialize(name, price, desc = nil); @name = name; @price = price; @desc = desc; end
    def getDisplayName(_item); @name; end
    def getDisplayPrice(_item, _selling = false); @price.is_a?(Exception) ? raise(@price) : @price; end
    def getDescription(_item); @desc; end
  end

  test "a row says the item and its price in the currency its window sells for" do
    { RowWindow.new([:MASTERBALL], TwoCurrencyAdapter.new, false) => "MASTERBALL, 3 AP",
      RowWindow.new([:MASTERBALL], TwoCurrencyAdapter.new, true) => "MASTERBALL, 4 BP",
      RowWindow.new([:PROTEIN], Adapter.new("Protein", "12 BP")) => "Protein, 12 BP" }.each do |win, row|
      assert_equal row, PokeAccess::Shops.row(win, 0), "for #{win.inspect}"
    end
  end

  test "the row past the stock is Cancel" do
    win = RowWindow.new([:PROTEIN], Adapter.new("Protein", "12 BP"))
    assert_equal PokeAccess::I18n.t(:pc_cancel), PokeAccess::Shops.row(win, 1)
  end

  test "a window without stock, or an empty slot of it, says nothing" do
    assert_nil PokeAccess::Shops.row(RowWindow.new(nil, Adapter.new("Protein", "12 BP")), 0), "no stock"
    assert_nil PokeAccess::Shops.row(RowWindow.new([nil], Adapter.new("Protein", "12 BP")), 0), "an empty slot"
  end

  test "an item its adapter leaves unnamed is said by the data's name" do
    { Adapter.new("", "12 BP") => "ItemPROTEIN, 12 BP", Adapter.new(nil, "12 BP") => "ItemPROTEIN, 12 BP",
      nil => "ItemPROTEIN" }.each do |adapter, row|
      assert_equal row, PokeAccess::Shops.row(RowWindow.new([:PROTEIN], adapter), 0), "adapter #{adapter.inspect}"
    end
  end

  test "a row without a price says the item alone" do
    [Adapter.new("Protein", ""), Adapter.new("Protein", nil),
     Adapter.new("Protein", RuntimeError.new("no price"))].each do |ad|
      assert_equal "Protein", PokeAccess::Shops.row(RowWindow.new([:PROTEIN], ad), 0), "adapter #{ad.inspect}"
    end
  end

  test "the info key reads the focused item with the description the shop gives" do
    PokeAccess::Shops.row(RowWindow.new([:PROTEIN], Adapter.new("Protein", "12 BP", "Raises Attack.")), 0)
    assert_equal "ItemPROTEIN. Raises Attack. #{stub_teaches}", PokeAccess::Info.info_text
  ensure
    PokeAccess::Info.note_item_desc(nil, nil)
  end

  test "landing on an item in the open shop says the bag count and the points left, queued" do
    bp_shop.focus(:PROTEIN, 2, 120)
    PokeAccess::InfoWindow.tick
    assert_equal [["In Bag:, 2", false], ["Battle Points:, 120", false]], SpeakCapture.log
  end

  test "standing on the same item says nothing more" do
    scene = bp_shop
    scene.focus(:PROTEIN, 2, 120)
    PokeAccess::InfoWindow.tick
    SpeakCapture.clear
    PokeAccess::InfoWindow.tick
    assert_nothing_spoken
  end

  test "a purchase says the new count and points" do
    scene = bp_shop
    scene.focus(:PROTEIN, 2, 120)
    PokeAccess::InfoWindow.tick
    SpeakCapture.clear
    scene.focus(:PROTEIN, 3, 100)
    PokeAccess::InfoWindow.tick
    assert_equal [["In Bag:, 3", false], ["Battle Points:, 100", false]], SpeakCapture.log
  end

  test "on Cancel the hidden bag box is not read, and unchanged points say nothing" do
    scene = bp_shop
    scene.focus(:PROTEIN, 2, 120)
    PokeAccess::InfoWindow.tick
    SpeakCapture.clear
    scene.focus(nil, 5, 120)
    PokeAccess::InfoWindow.tick
    assert_nothing_spoken
  end

  test "closing the shop ends the watch" do
    scene = bp_shop
    scene.pbEndScene
    scene.focus(:PROTEIN, 2, 120)
    PokeAccess::InfoWindow.tick
    assert_nothing_spoken
  end

  test "at brief, the bag count is left to Ctrl+T while what there is to spend is still said" do
    PokeAccess::Config.verbosity = :brief
    [[:bp_shop, "Battle Points:, 120"], [:buy_mart, "Money:, $120"]].each do |opened, spend|
      SpeakCapture.clear
      scene = send(opened)
      PokeAccess::Shops.row(RowWindow.new([:PROTEIN], Adapter.new("Protein", "12 BP")), 0)
      scene.focus(:PROTEIN, 2, 120)
      PokeAccess::InfoWindow.tick
      assert_equal [[spend, false]], SpeakCapture.log, "#{scene.class}: said"
      assert_equal "Protein, 12 BP. In Bag:, 2", PokeAccess::Info.row_text, "#{scene.class}: Ctrl+T"
    end
  end

  test "the mart's buy and sell scenes each open the watch on the bag count and the money" do
    [:pbStartBuyScene, :pbStartSellScene].each do |opener|
      SpeakCapture.clear
      scene = PokemonMart_Scene.new
      scene.focus(:POTION, 3, 12500)
      scene.send(opener, [], nil)
      PokeAccess::InfoWindow.tick
      assert_equal [["In Bag:, 3", false], ["Money:, $12500", false]], SpeakCapture.log, "after #{opener}"
    end
  end

  test "a purchase at the mart says the new count and money" do
    scene = buy_mart
    scene.focus(:POTION, 3, 12500)
    PokeAccess::InfoWindow.tick
    SpeakCapture.clear
    scene.focus(:POTION, 2, 12300)
    PokeAccess::InfoWindow.tick
    assert_equal [["In Bag:, 2", false], ["Money:, $12300", false]], SpeakCapture.log
  end

  test "both shop scenes bind an opener, so the diagnostic lists neither as never entered" do
    %w[BattlePointShop_Scene PokemonMart_Scene].each do |scene|
      refute_includes PokeAccess::InfoWindow.unentered, scene
    end
  end

  test "closing either mart scene ends the watch" do
    { :pbStartBuyScene => :pbEndBuyScene, :pbStartSellScene => :pbEndSellScene }.each do |opener, closer|
      scene = mart(opener)
      scene.send(closer)
      scene.focus(:POTION, 9, 99999)
      PokeAccess::InfoWindow.tick
      assert_nothing_spoken "after #{closer}"
    end
  end

  private

  # What the info key adds for every item of the stub's data, which names Thunderbolt as each one's move.
  def stub_teaches
    "#{PokeAccess::I18n.t(:it_teaches, :move => 'MoveTHUNDERBOLT')}. descTHUNDERBOLT"
  end

  # The Battle Point shop, opened.
  def bp_shop
    scene = BattlePointShop_Scene.new
    scene.pbStartScene
    scene
  end

  # The mart, opened by opener.
  def mart(opener)
    scene = PokemonMart_Scene.new
    scene.send(opener, [], nil)
    scene
  end

  # The mart, opened to buy.
  def buy_mart
    mart(:pbStartBuyScene)
  end
end
