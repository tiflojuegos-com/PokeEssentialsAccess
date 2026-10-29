# Dark Horizon's Pokedex, its edited BW copy over the MUI Data Page: the list paints a species' caught ball by
# owned_shadow_pokemon? (the dex counts Shadow Pokemon caught), and the entry opens on page 4, the Data Page, without
# naming it in @page_id.
module PokeAccess
  module DarkHorizonDex
    # Whether the list paints the species' caught ball; nil when the player cannot answer.
    def self.caught?(species)
      pl = PokeAccess::Engine.player
      return nil unless pl && pl.respond_to?(:owned_shadow_pokemon?)
      pl.owned_shadow_pokemon?(species) ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # A list row as the BW list paints it: its number (one lower with a shift), its name and the caught ball's state.
    def self.row(c)
      caught = c.is_a?(Hash) ? caught?(c[:species]) : nil
      return nil if caught.nil?
      num = c[:number].to_i
      num -= 1 if c[:shift]
      PokeAccess::Menus.dex_row(num, c[:species], c[:name], nil, caught)
    end
  end
end

PokeAccess::Game.define("darkhorizon") do
  override("PokeAccess::Menus", :dex_list_row) do |_mod, original, args|
    PokeAccess::DarkHorizonDex.row(args[1]) || original.call
  end
  override("PokeAccess::PokedexInfoV21", :page_id) do |_mod, original, args|
    (args[1] == 4 && PokeAccess.ivar(args[0], :@page_id).nil?) ? :page_data : original.call
  end
end
