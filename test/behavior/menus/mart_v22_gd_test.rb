# The v22 shops (UI::MartVisuals, UI::BPShopVisuals, UI::BagSellVisuals): the focused item with the price its stock
# wrapper writes, unit included, the exit row as cancel, and the sell screen read through the bag's own callback.
class MartV22GdTest < PokeAccessTest
  test "the buy list says the focused item with its price, interrupting" do
    UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR])).set_index(0)
    assert_equal [[item_line("ItemPOTION", "$500"), true]], SpeakCapture.log
  end

  test "a redraw on the same entry says nothing" do
    vis = UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR]))
    vis.set_index(0)
    SpeakCapture.clear
    vis.set_index(0)
    assert_nothing_spoken
  end

  test "moving says the next item" do
    vis = UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR]))
    vis.set_index(0)
    SpeakCapture.clear
    vis.set_index(1)
    assert_equal [[item_line("ItemELIXIR", "$500"), true]], SpeakCapture.log
  end

  test "the row past the last item is cancel" do
    UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR])).set_index(2)
    assert_equal [[PokeAccess::I18n.t(:pc_cancel), true]], SpeakCapture.log
  end

  test "an item is said by the name the list paints, a machine with its move" do
    UI::MartVisuals.new(UI::MartStockWrapper.new([:TM01])).set_index(0)
    assert_equal [[item_line("ItemTM01 MoveTHUNDERBOLT", "$500"), true]], SpeakCapture.log
  end

  test "the info key answers for the focused item" do
    UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR])).set_index(1)
    assert_match(/\AItemELIXIR\. idescELIXIR\./, PokeAccess::Info.info_text)
  end

  test "a stock that writes no price says the name alone" do
    UI::MartVisuals.new([:POTION]).set_index(0)
    assert_equal [["ItemPOTION", true]], SpeakCapture.log
  end

  test "an item the game data does not know is said by its id alone, the info key left alone" do
    with_unknown_item(:NOSUCHITEM) { UI::MartVisuals.new(UI::MartStockWrapper.new([:NOSUCHITEM])).set_index(0) }
    assert_equal [["NOSUCHITEM", true]], SpeakCapture.log
    assert_nil PokeAccess::Info.info_text
  end

  test "the Battle Point shop, through the same hook, says the price in Battle Points" do
    UI::BPShopVisuals.new(UI::BPShopStockWrapper.new([:POTION])).set_index(0)
    assert_equal [[item_line("ItemPOTION", "12 BP"), true]], SpeakCapture.log
  end

  test "the sell screen says each entry with its count, through the bag's own callback" do
    vis = UI::BagSellVisuals.new(TestBag.new({ :Items => [[:POTION, 3], [:ELIXIR, 7]] }, :Items))
    vis.set_index(0)
    assert_equal [[bag_line("ItemPOTION", 3), true]], SpeakCapture.log
    SpeakCapture.clear
    vis.set_index(1)
    assert_equal [[bag_line("ItemELIXIR", 7), true]], SpeakCapture.log
  end

  private

  # A mart row as the reader says it.
  def item_line(name, price)
    PokeAccess::I18n.t(:mart_item, :name => name, :price => price)
  end

  # A bag row as the reader says it.
  def bag_line(name, qty)
    PokeAccess::I18n.t(:bag_item, :name => name, :qty => qty)
  end

  # Runs the block with GameData::Item.get raising for id, as the game data does for an id it lacks; the stub's own
  # get is put back after.
  def with_unknown_item(id)
    items = GameData::Item
    saved = items.method(:get)
    items.define_singleton_method(:get) { |i| i == id ? raise(KeyError, "unknown item #{i}") : saved.call(i) }
    yield
  ensure
    items.define_singleton_method(:get, saved)
  end
end
