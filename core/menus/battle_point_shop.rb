# Battle Point shop (Window_BattlePointShop), a Window_DrawableCommand whose entries are item ids in @stock
# with names/prices via its @adapter -- the generic reader would speak the raw id symbol instead ("PROTEIN",
# with no price). Nothing here is game-specific, so it registers once for every game: an extractor for a class
# the running game does not define is never reached (focused_text resolves the name through const_at and skips
# it), which is what makes a plain global registration safe. It used to be opt-in per profile, and the
# profiles that forgot to opt in shipped the raw ids for
# months -- an avoidable gap the class-existence gating already prevents.
#
# The "Battle Point Mart" variant (Window_PokemonMart_BattlePoints) is a second window with the very
# same shape -- @stock of item ids, an @adapter for name/price, and one extra row for cancel -- but it
# descends from Window_DrawableCommand instead of Window_PokemonMart, so the mart extractor never matched it
# (focused_text picks an extractor with win.is_a?). Registering the same reader under both names covers it.
["Window_BattlePointShop", "Window_PokemonMart_BattlePoints"].each do |cname|
  PokeAccess::Menus.def_extractor(cname) do |win, i|
    stock = win.instance_variable_get(:@stock)
    if stock.is_a?(Array) && i >= stock.length
      PokeAccess::I18n.t(:pc_cancel)
    elsif stock.is_a?(Array) && stock[i]
      item = stock[i]
      ad = win.instance_variable_get(:@adapter)
      name = (ad.getDisplayName(item) rescue nil) if ad
      name = (PokeAccess::Data.item_name(item) || item.to_s) if name.nil? || name.to_s.empty?
      price = (ad.getDisplayPrice(item) rescue nil) if ad
      (price && !price.to_s.empty?) ? "#{name}, #{price}" : name
    end
  end
end
