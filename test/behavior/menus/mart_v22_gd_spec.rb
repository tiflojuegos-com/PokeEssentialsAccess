# The v22 shops (Essentials v22 UI::MartVisuals for buying, UI::BPShopVisuals for the Battle Point shop,
# UI::BagSellVisuals for selling). Two things had no assert at all. First, the price and its UNIT come from
# the stock wrapper, not the reader, and the BP shop is a bare subclass that must be covered by the SAME
# hook -- a shop that reads "500" when the price is 12 BP is worse than silence. Second, the sell screen is
# a UI::BagVisuals SUBCLASS whose cursor callback calls super, so ONE cursor move runs the bag hook AND the
# sell hook (the documented same-name onion in Hooks.wrap); only the reader's dedup keeps the entry from
# being spoken twice. Runs only in the gamedata pass.

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

# UI::BPShopVisuals adds no cursor callback of its own: it inherits MartVisuals', which is exactly why one
# hook registration must cover both. The unit is the discriminator -- the same item, the same reader, a
# different wrapper, and the money price must NOT appear.
Suite.define("v22 mart: the Battle Point shop is covered by the same hook and reads BP, not money") do
  vis = UI::BPShopVisuals.new(UI::BPShopStockWrapper.new([:POTION]))

  vis.set_index(0)
  eq "the BP shop reads the item priced in Battle Points", SpeakCapture.lines,
     [PokeAccess::I18n.t(:mart_item, :name => "ItemPOTION", :price => "12 BP")]
  not_spoke "and never quotes the money price of the same item", /500/
end

# The reentrancy case: UI::BagSellVisuals#refresh_on_index_changed calls super, so the child's hook runs the
# child's original, which reaches the PARENT's hooked method under the same method name -- the onion the
# guard deliberately lets through. Both readers therefore build the same line; only the [index, text] dedup
# on the shared instance stops the player hearing the item twice on every single cursor move.
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
