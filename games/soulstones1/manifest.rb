# Load order for the Pokemon Soulstones modules (no .rb), after core. Soulstones is Essentials v17.2 (gen-6) on its own
# mkxp-z 1.3.0 (Game-z.exe), with the v17 screen names alone (no v16 aliases). FL's Advanced Pokedex, Marin's Easy
# Questing, the Gen 8 item-found popup, FL's Set the Controls and Reborn SWM's Item Radar Mod are read from plugins/;
# its copy of raZ's encounter list, its bag, its edit of FL's HMs as Items and the quick save pasted into its map
# scene are its own, so their readers are here.
{
  :modules => %w[
    summary
    encounter_list
    bag
    field_moves
    quicksave
  ],
  :plugins => %w[advanced_pokedex easy_questing item_find fl_set_controls item_radar]
}
