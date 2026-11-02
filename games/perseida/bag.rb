module PokeAccess
  # Perseida's bag rows (Window_PokemonBag#drawItem, 0147_PScreen_Bag) mark an item registered to one of its three keys with
  # that key's name: registeredItem is a list, by Input::ITEMKEYS.
  module PerseidaBag
    # The name stands as the game gives it.
    def self.name(_ad, _itemid)
      nil
    end

    # The key the row is registered to, as a bag mark.
    def self.marks(bag, itemid)
      slot = bag.registeredItem.index(itemid)
      slot ? [[:ins_bag_key, { :key => Input::ITEMKEYSNAMES[slot] }]] : []
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end
  end
end

unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::PerseidaBag)
  PokeAccess::Menus.bag_decorators.push(PokeAccess::PerseidaBag)
end

# The key's mark stands for the core's plain registered one.
PokeAccess::Game.define("perseida") do
  override("PokeAccess::Menus", :bag_registered?) { |_m, _original, _a| false }
end
