# Load order for the Pokemon Soulstones modules (no .rb), after core: Essentials v17.2 (gen-6) on its own mkxp-z 1.3.0,
# with the v17 screen names alone (no v16 aliases). Its copy of raZ's encounter list, its bag, its edit of FL's HMs as
# Items and the quick save in its map scene are its own, read here; its other plugins are read from plugins/.
{
  :modules => %w[
    summary
    encounter_list
    bag
    field_moves
    quicksave
    passability
  ],
  :plugins => %w[advanced_pokedex easy_questing item_find fl_set_controls item_radar]
}
