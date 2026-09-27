module PokeAccess
  # Rejuvenation's favourite items, as a bag decorator: Z stars the focused item (favicon_on beside its name, painted
  # by the game's own edit of the bag, PokemonBag#isFavorite?) and the favourites pocket gathers the starred ones.
  module RejuvenationFavourites
    def self.name(_ad, _itemid); nil; end

    def self.marks(bag, itemid)
      (bag.respond_to?(:isFavorite?) && bag.isFavorite?(itemid)) ? [:mb_favourite] : []
    rescue StandardError
      []
    end
  end
end

decorators = PokeAccess::Menus.bag_decorators
decorators.push(PokeAccess::RejuvenationFavourites) unless decorators.include?(PokeAccess::RejuvenationFavourites)
