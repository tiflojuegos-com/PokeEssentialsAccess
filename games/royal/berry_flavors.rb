# Royal's edited copy of TDW's Berry Core keys the flavours in Spanish ("Picante"...), which its Berrydex page maps to
# the plugin's sprite names itself; the same mapping lets the Berrydex reader name them in the mod's language.
module PokeAccess
  module RoyalBerryFlavors
    # Royal's flavour keys as the plugin's own, in the order of its drawPageInfo mapping.
    SPANISH = { "Picante" => :spicy, "Seco" => :dry, "Dulce" => :sweet, "Amargo" => :bitter, "Ácido" => :sour }
  end
end

PokeAccess::Game.define("royal") do
  override("PokeAccess::BerryDex", :flavor_key) do |_mod, original, args|
    plugin_key = PokeAccess::RoyalBerryFlavors::SPANISH[args[0].to_s]
    args[0] = plugin_key if plugin_key
    original.call
  end
end
