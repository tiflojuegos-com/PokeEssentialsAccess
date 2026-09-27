# Soulstones' own bag (Window_PokemonBag#drawItem in 0152_PScreen_Bag.rb) draws only the registered icon: the frame
# for an item that could be registered sits behind a test comparing pbCanRegisterItem?'s true or false with the item's
# number, so it never shows, and no row is said as registrable.
PokeAccess::Game.define("soulstones1") do
  override("PokeAccess::Menus", :bag_registrable?) { |_mod, _original, _args| false }
end
