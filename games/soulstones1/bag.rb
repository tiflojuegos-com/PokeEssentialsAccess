# Soulstones' own bag (Window_PokemonBag#drawItem in 0152_PScreen_Bag.rb) draws only the registered icon: the frame
# for an item that could be registered sits behind a test comparing pbCanRegisterItem?'s true or false with the item's
# number, so it never shows, and no row is said as registrable.
PokeAccess::Game.define("soulstones1") do
  override("PokeAccess::Menus", :bag_registrable?) { |_mod, _original, _args| false }

  # Shift, the mod's modifier, marks an item to move in its bag (Input::SHIFT, 0152_PScreen_Bag): that goes on Alt.
  remap_extra(:ss1_mark, 0x10, :ss1_key_shift, :button => :SHIFT)
  key_defaults(:ss1_mark => "Alt")
end
