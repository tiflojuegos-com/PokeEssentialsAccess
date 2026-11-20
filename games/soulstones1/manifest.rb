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
    puzzles/sleeper_spire
    puzzles/abandoned_subway
    puzzles/sirius_sewers
    puzzles/carleton_facility
    puzzles/time_matrix
    puzzles/genesis_facility
    puzzles/agency_delta
    puzzles/fallen_tomb
    puzzles/power_plant
    puzzles/media_hq
    puzzles/mt_fhenzhu
    puzzles/realm_deception
    puzzles/beta_omicron
    puzzles/refugee_tunnels
    puzzles/ishizu
    puzzles/jenola_caves
    puzzles/side_quests
  ],
  :plugins => %w[advanced_pokedex easy_questing item_find fl_set_controls item_radar]
}
