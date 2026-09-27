# The v22 shops (UI::MartVisuals, UI::BPShopVisuals, UI::BagSellVisuals): the price and its unit come from the stock
# wrapper, and the sell screen speaks each entry once though both bag hooks fire. Gamedata pass.

Suite.define("v22 mart: the buy list reads the item with its price, and the exit row as cancel") do
  vis = UI::MartVisuals.new(UI::MartStockWrapper.new([:POTION, :ELIXIR]))

  vis.set_index(0)
  eq "the focused item is read with its money price", SpeakCapture.lines,
     [PokeAccess::I18n.t(:mart_item, :name => "ItemPOTION", :price => "$500")]

  SpeakCapture.clear
  vis.set_index(0)
  silent "a redraw on the same entry says nothing"

  SpeakCapture.clear
  vis.set_index(1)
  spoke_once "moving to the next item reads it", /ItemELIXIR/

  SpeakCapture.clear
  vis.set_index(2)
  eq "the row past the last item is the cancel label, not an item", SpeakCapture.lines,
     [PokeAccess::I18n.t(:pc_cancel)]
end

# UI::BPShopVisuals inherits MartVisuals' cursor callback, so the same hook covers it; its wrapper prices in BP.
Suite.define("v22 mart: the Battle Point shop is covered by the same hook and reads BP, not money") do
  vis = UI::BPShopVisuals.new(UI::BPShopStockWrapper.new([:POTION]))

  vis.set_index(0)
  eq "the BP shop reads the item priced in Battle Points", SpeakCapture.lines,
     [PokeAccess::I18n.t(:mart_item, :name => "ItemPOTION", :price => "12 BP")]
  not_spoke "and never quotes the money price of the same item", /500/
end

# UI::BagSellVisuals#refresh_on_index_changed calls super, so both bag hooks fire on one move; the [index, text]
# dedup on the shared instance speaks the entry once.
Suite.define("v22 mart: the sell screen fires both bag hooks but speaks the entry once") do
  bag = TestBag.new({ :Items => [[:POTION, 3], [:ELIXIR, 7]] }, :Items)
  potion = PokeAccess::I18n.t(:bag_item, :name => "ItemPOTION", :qty => 3)

  probe = UI::BagSellVisuals.new(bag)
  UI::BagVisuals.instance_method(:refresh_on_index_changed).bind(probe).call(nil)
  spoke_once "the parent bag hook is live on a sell-screen instance (so both hooks fire on one move)",
             /#{Regexp.escape(potion)}/

  SpeakCapture.clear
  vis = UI::BagSellVisuals.new(bag)
  vis.set_index(0)
  eq "one cursor move speaks exactly one line, not one per hook", SpeakCapture.lines, [potion]

  SpeakCapture.clear
  vis.set_index(1)
  spoke_once "the next entry is still read (the dedup mutes the repeat, not the screen)", /ItemELIXIR/
end
