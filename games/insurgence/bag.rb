module PokeAccess
  # Insurgence's bag rows (Window_PokemonBag#drawItem, 100_PokemonBag.rb) badge an item registered to one of its five
  # keys with that key's letter (registeredItem to registeredItem5: Q, W, E, T, Y) and a piece of clothing worn
  # ($Trainer.clothes 0 to 4) with its slot's icon; and a mega stone shows its count, important item though it is.
  module InsurgenceBag
    KEYS = [[:registeredItem, "Q"], [:registeredItem2, "W"], [:registeredItem3, "E"], [:registeredItem4, "T"],
            [:registeredItem5, "Y"]]

    # The name stands as the game gives it.
    def self.name(_ad, _itemid)
      nil
    end

    # The row's badges as bag marks: the key it is registered to, and worn.
    def self.marks(bag, itemid)
      out = []
      KEYS.each { |slot, letter| out.push([:ins_bag_key, { :key => letter }]) if (bag.send(slot) rescue nil) == itemid }
      worn = ($Trainer.clothes rescue nil)
      out.push(:shop_worn) if worn.is_a?(Array) && worn[0, 5].include?(itemid)
      out
    rescue StandardError
      []
    end

    # Runs a bag row's build, inside which a mega stone keeps its count.
    def self.in_row
      @in_row = true
      yield
    ensure
      @in_row = false
    end

    # Whether the row being built is a mega stone's, whose count the bag paints.
    def self.counted?(itemid)
      @in_row && (pbIsMegaStone?(itemid) rescue false) ? true : false
    end
  end
end

unless PokeAccess::Menus.bag_decorators.include?(PokeAccess::InsurgenceBag)
  PokeAccess::Menus.bag_decorators.push(PokeAccess::InsurgenceBag)
end

# The key badges stand for the core's single registered mark; the item storage, which paints no mega stone's count,
# keeps the core's rule.
PokeAccess::Game.define("insurgence") do
  override("PokeAccess::Menus", :bag_registered?) { |_m, _original, _a| false }
  override("PokeAccess::Menus", :bag_row) { |_m, original, _a| PokeAccess::InsurgenceBag.in_row { original.call } }
  override("PokeAccess::Menus", :bag_hides_qty?) do |_m, original, args|
    PokeAccess::InsurgenceBag.counted?(args[0]) ? false : original.call
  end
end
