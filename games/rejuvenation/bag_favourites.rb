module PokeAccess
  # Rejuvenation's favourite items, as a bag decorator: Z stars the focused item (favicon_on beside its name, painted by
  # the game's own edit of the bag, PokemonBag#isFavorite?) and the favourites pocket gathers the starred ones. A star
  # taken off is said.
  module RejuvenationFavourites
    def self.name(_ad, _itemid); nil; end

    def self.marks(bag, itemid)
      (bag.respond_to?(:isFavorite?) && bag.isFavorite?(itemid)) ? [:mb_favourite] : []
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # Says a star taken off; bound once.
    def self.bind
      return if @bound
      @bound = true
      PokeAccess::Hooks.after_hook("PokemonBag", :removeFavorite, :optional => true) do |_bag, _r, _a|
        PokeAccess.speak(PokeAccess::I18n.t(:rj_favorite_removed), true)
      end
    end
  end

  # Rejuvenation's machines, as a bag decorator: the type icon the bag paints beside a TM (minitype), said as the type
  # of the move it teaches.
  module RejuvenationMachineTypes
    def self.name(_ad, _itemid); nil; end

    def self.marks(_bag, itemid)
      return [] unless (pbIsTM?(itemid) rescue false)
      type = PokeAccess::Data.type_name($cache.moves[pbGetTM(itemid)].type)
      type ? [[:bt_type, { :t => type }]] : []
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end
  end
end

decorators = PokeAccess::Menus.bag_decorators
[PokeAccess::RejuvenationFavourites, PokeAccess::RejuvenationMachineTypes].each do |d|
  decorators.push(d) unless decorators.include?(d)
end
PokeAccess::RejuvenationFavourites.bind
