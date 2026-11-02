# Vitro's shop of Pokemon (PokemonCreaturesMart_Scene, 0341_PokeShop, map 122), a mart whose stock is species: core reads its rows, its
# coins and its messages, but would name an item for the info key, the one with that species' number. Its row keeps the Pokedex entry
# the panel paints.
module PokeAccess
  module VitroCreatureMart
    # A row of this shop as core words a shop's row, or nil for any other shop.
    def self.row(buy_adapter, species)
      adapter = PokeAccess.ivar(buy_adapter, :@adapter)
      return nil unless adapter.is_a?(::PokemonCreaturesMartAdapter)
      parts = [[PokeAccess.clean(adapter.getDisplayName(species).to_s), :brief], [adapter.getDisplayPrice(species).to_s, :brief]]
      whole = PokeAccess::Verbosity.full_line(parts)
      PokeAccess::Info.set_info(:text, PokeAccess.sentences([whole, PokeAccess.clean(adapter.getDescription(species).to_s)]), whole)
      PokeAccess::Verbosity.line(:shop_item, parts)
    end
  end
end

PokeAccess::Game.define("vitro") do
  override("PokeAccess::Menus", :mart_special) do |_mod, original, args|
    PokeAccess::VitroCreatureMart.row(args[0], args[1]) || original.call
  end
end
