# v22 Poke Mart buy list (UI::MartVisuals, and the BP shop that inherits it): the focused item with the stock's
# buy_price_string, which carries the unit. Selling needs no hook: UI::BagSellVisuals reuses the bag's callback.
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
