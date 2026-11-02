# Vitro's shortcuts (clFastKeys, 0283_Atajos Teclado, on the map and in the pause menu, unless its option turns them off) read
# letters by mkxp-z's names for the keys: T saves, B the bag, J the quests, P the party, Y the Pokegear, M the map. Three of
# them are where the mod's keys ship, so those ship on Alt plus their letter.
PokeAccess::Game.define("vitro") do
  remap_extra(:vitro_save, :T, :vitro_key_t)
  remap_extra(:vitro_bag, :B, :vitro_key_b)
  remap_extra(:vitro_quests, :J, :vitro_key_j)
  remap_extra(:vitro_party, :P, :vitro_key_p)
  remap_extra(:vitro_gear, :Y, :vitro_key_y)
  remap_extra(:vitro_map, :M, :vitro_key_m)
  key_defaults(:vitro_save => "Alt+T", :vitro_quests => "Alt+J", :vitro_map => "Alt+M")
end
