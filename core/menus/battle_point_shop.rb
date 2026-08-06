module PokeAccess
  # Battle Point shop: a Window_DrawableCommand whose entries are item ids in @stock, with names and prices
  # reachable only through its @adapter -- the generic reader speaks the raw id symbol instead ("PROTEIN",
  # with no price).
  #
  # The row builder is a named method rather than an inline block because a second window with the very same
  # shape exists in one game under a different class name, and that game's profile registers this same
  # builder for it. Sharing the method keeps the two registrations from drifting apart.
  module BattlePointShop
    def self.row(win, i)
      stock = win.instance_variable_get(:@stock)
      return nil unless stock.is_a?(Array)
      return PokeAccess::I18n.t(:pc_cancel) if i >= stock.length
      item = stock[i]
      return nil unless item
      ad = win.instance_variable_get(:@adapter)
      name = (ad.getDisplayName(item) rescue nil) if ad
      name = (PokeAccess::Data.item_name(item) || item.to_s) if name.nil? || name.to_s.empty?
      price = (ad.getDisplayPrice(item) rescue nil) if ad
      (price && !price.to_s.empty?) ? "#{name}, #{price}" : name
    end
  end
end

# Registered globally, not per profile. What makes that safe is not that the class is universal -- it is in
# 4 of the 13 surveyed dumps -- but that an extractor for a class the running game does not define is never
# reached: focused_text resolves the name through const_at and skips it. This used to be opt-in per profile
# and the profiles that forgot to opt in shipped the raw ids for months, so scoping it a second time by
# profile only reintroduces that gap.
PokeAccess::Menus.def_extractor("Window_BattlePointShop") do |win, i|
  PokeAccess::BattlePointShop.row(win, i)
end
