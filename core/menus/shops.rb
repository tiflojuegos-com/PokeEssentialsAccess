# The shop screens: the ordinary mart and the Battle Point shop, which is the same list with points for
# money. Their rows say name and price; the two number windows beside the list -- how many of the focused
# item are in the bag, and what there is to spend -- are watched here. The description box is not: the row
# files the item, so the info key reads it, as it always has in the mart.
module PokeAccess
  module Shops
    # The mart names both ends of its lifecycle after the mode, in all fifteen games, and has no pbStartScene.
    MART_LIFECYCLE = { :open => [:pbStartBuyScene, :pbStartSellScene], :close => [:pbEndBuyScene, :pbEndSellScene] }

    # A Battle Point shop row: the entries are item ids in @stock, named and priced through the @adapter
    # (the generic reader would say the bare id). Shared with emerald's Battle Point Mart, a second window of
    # the same shape under its own class name.
    def self.row(win, i)
      stock = win.instance_variable_get(:@stock)
      return nil unless stock.is_a?(Array)
      return PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      item = stock[i]
      return nil unless item
      ad = win.instance_variable_get(:@adapter)
      PokeAccess::Info.set_info(:item, item)
      (PokeAccess::Info.note_item_desc(item, ad.getDescription(item)) rescue nil) if ad && ad.respond_to?(:getDescription)
      name = (ad.getDisplayName(item) rescue nil) if ad
      name = (PokeAccess::Data.item_name(item) || item.to_s) if name.nil? || name.to_s.empty?
      price = (ad.getDisplayPrice(item) rescue nil) if ad
      (price && !price.to_s.empty?) ? "#{name}, #{price}" : name
    end
  end
end

# Global rather than per profile: an extractor for a class the running game lacks is never reached.
PokeAccess::Menus.def_extractor("Window_BattlePointShop") do |win, i|
  PokeAccess::Shops.row(win, i)
end

# The bag box is hidden on the Cancel row rather than cleared, so it is read only while shown.
PokeAccess::InfoWindow.watch("BattlePointShop_Scene", "qtywindow", :bp_shop_bag)
PokeAccess::InfoWindow.watch("BattlePointShop_Scene", "battlepointwindow", :bp_shop_points)

# qtywindow is the modern layout's (five of the fifteen); the money window is everywhere, and in
# Reminiscencia holds the Game Corner's coins under its own label.
PokeAccess::Engine.scene_classes("PokemonMartScene", "PokemonMart_Scene").each do |cls|
  PokeAccess::InfoWindow.watch(cls, "qtywindow", :mart_bag, PokeAccess::Shops::MART_LIFECYCLE.merge(:optional => true))
  PokeAccess::InfoWindow.watch(cls, "moneywindow", :mart_money, PokeAccess::Shops::MART_LIFECYCLE)
end
