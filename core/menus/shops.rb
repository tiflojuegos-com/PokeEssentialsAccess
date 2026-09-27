# The mart and the Battle Point shop: rows say name and price, and the two windows beside the list (the focused
# item's count in the bag, what there is to spend) are watched; the info key reads the item's description.
module PokeAccess
  module Shops
    # The mart's openers and closers, named after the mode (it has no pbStartScene).
    MART_LIFECYCLE = { :open => [:pbStartBuyScene, :pbStartSellScene], :close => [:pbEndBuyScene, :pbEndSellScene] }

    # A Battle Point shop row (also emerald's Battle Point Mart): the @stock item named and priced through @adapter,
    # passing @useBP as the price's third argument where the window keeps one.
    def self.row(win, i)
      stock = win.instance_variable_get(:@stock)
      return nil unless stock.is_a?(Array)
      return PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      item = stock[i]
      return nil unless item
      ad = win.instance_variable_get(:@adapter)
      (PokeAccess::Info.note_item_desc(item, ad.getDescription(item)) rescue nil) if ad && ad.respond_to?(:getDescription)
      name = (ad.getDisplayName(item) rescue nil) if ad
      name = (PokeAccess::Data.item_name(item) || item.to_s) if name.nil? || name.to_s.empty?
      if ad
        use_bp = win.instance_variable_get(:@useBP)
        price = use_bp.nil? ? (ad.getDisplayPrice(item) rescue nil) : (ad.getDisplayPrice(item, false, use_bp) rescue nil)
      end
      row = (price && !price.to_s.empty?) ? "#{name}, #{price}" : name
      PokeAccess::Info.set_info(:item, item, row)
      row
    end

    # Watches the mart's quantity prompt (pbChooseNumber) while it runs, for the count in the bag its own window shows.
    def self.prompt_open(scene); @prompt = scene; end

    # Stops watching, dropping a count in the bag that no amount followed.
    def self.prompt_close
      @prompt = nil
      PokeAccess::NumberEntry.aside = nil
    end

    # A window's new text while the prompt runs: the first one of a window the prompt made itself (the question is in
    # one of the scene's sprites), shown and not the amount, is the count in the bag ("In Bag: 5", only when buying),
    # said after the amount.
    def self.prompt_text(win, raw)
      scene = @prompt
      return if scene.nil? || !(win.visible rescue true)
      sprites = PokeAccess.ivar(scene, :@sprites)
      return if sprites.is_a?(Hash) && sprites.values.any? { |s| s.equal?(win) }
      t = PokeAccess.clean(raw.to_s.gsub(PokeAccess::NumberEntry::LAYOUT, " "))
      return if t.empty? || t =~ PokeAccess::NumberEntry::LINE
      @prompt = nil
      PokeAccess::NumberEntry.aside = t
    rescue StandardError
      nil
    end
  end
end

# Global rather than per profile: an extractor for a class the running game lacks is never reached.
PokeAccess::Menus.def_extractor("Window_BattlePointShop") do |win, i|
  PokeAccess::Shops.row(win, i)
end

# The bag box is hidden on the Cancel row rather than cleared, so it is read only while shown.
PokeAccess::InfoWindow.watch("BattlePointShop_Scene", "qtywindow", :bp_shop_bag, :reading => [:shop_item, :medium])
PokeAccess::InfoWindow.watch("BattlePointShop_Scene", "battlepointwindow", :bp_shop_points)

# qtywindow exists only in the modern layout, hence optional; the money window everywhere. Up to v19 the count in the
# bag is instead a window of the quantity prompt's own, watched while pbChooseNumber, the prompt's loop, runs.
PokeAccess::Engine.scene_classes("PokemonMartScene", "PokemonMart_Scene").each do |cls|
  PokeAccess::InfoWindow.watch(cls, "qtywindow", :mart_bag,
                               PokeAccess::Shops::MART_LIFECYCLE.merge(:optional => true, :reading => [:shop_item, :medium]))
  PokeAccess::InfoWindow.watch(cls, "moneywindow", :mart_money, PokeAccess::Shops::MART_LIFECYCLE)
  PokeAccess::Hooks.around_hook(cls, :pbChooseNumber, :optional => true) do |scene, nxt, _a|
    PokeAccess::Shops.prompt_open(scene)
    begin
      nxt.call
    ensure
      PokeAccess::Shops.prompt_close
    end
  end
end
PokeAccess::Hooks.after_hook("Window_AdvancedTextPokemon", :text=, :optional => true) do |w, _r, args|
  PokeAccess::Shops.prompt_text(w, args[0])
end
