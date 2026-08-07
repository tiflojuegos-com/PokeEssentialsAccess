# v22 Poke Mart (Essentials v22: UI::MartVisuals for buying, UI::BagSellVisuals for selling, and
# UI::BPShopVisuals < UI::MartVisuals for the Battle Point shop). The buy list is a passive
# UI::MartVisualsList exposing the focused item via visuals.item; the price comes from the stock wrapper's
# buy_price_string so the unit is right ("$500" for a Mart, "100 BP" for the BP shop), and BPShopVisuals
# inherits MartVisuals' cursor callback, so this one hook covers it too.
#
# Selling needs NO hook: UI::BagSellVisuals subclasses UI::BagVisuals and its refresh_on_index_changed
# calls super, so the bag's hook already fires on the sell screen and reads the item. A registration on the
# subclass would speak the same line and start double-reading the moment the two diverged.
PokeAccess::V22.on_nav("UI::MartVisuals") do |vis|
  id = (vis.item rescue nil)
  if id
    data  = (GameData::Item.get(id) rescue nil)
    name  = data ? (data.display_name rescue (data.name rescue id).to_s) : id.to_s
    PokeAccess::Info.set_info(:item, id) if data
    price = ((vis.instance_variable_get(:@stock).buy_price_string(id)) rescue nil)
    price ? PokeAccess::I18n.t(:mart_item, :name => name, :price => price) : name
  else
    PokeAccess::I18n.t(:pc_cancel)
  end
end
