# La Base de Sky's bag extras (anil, royal): machines keep their move name behind the mart adapter's
# getDisplayNameMachineName/Number, and PokemonBag#favourite? marks favourites. Vanilla Essentials has
# neither, so the row reader learns both from here, as decorators, rather than probing the fork from core.
module PokeAccess
  module SkyBag
    # "TM01 Focus Punch" for a machine, nil for anything else (the vanilla name stands). The gate is the
    # fork's own: for a plain item BOTH helpers answer the item's name, and the bag paints the two columns
    # only when they differ -- read without it, a Repel came out as "Repel Repel".
    def self.name(ad, itemid)
      return nil unless ad && ad.respond_to?(:getDisplayNameMachineName)
      mn = (ad.getDisplayNameMachineName(itemid) rescue nil).to_s
      num = (ad.getDisplayNameMachineNumber(itemid) rescue nil).to_s
      return nil if mn.empty? || num.empty? || num == mn
      "#{num} #{mn}"
    end

    def self.marks(bag, itemid)
      (bag.respond_to?(:favourite?) && bag.favourite?(itemid)) ? [:mb_favourite] : []
    rescue StandardError
      []
    end
  end
end

PokeAccess::Menus.bag_decorators.push(PokeAccess::SkyBag) unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::SkyBag)
