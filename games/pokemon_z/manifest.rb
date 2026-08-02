# Load order for the pokemon_z game modules (no .rb), loaded after core. Edit to add/reorder.
# The item crafting screen is a THIRD-PARTY plugin shared with other fangames, so its reader lives in
# plugins/ and is declared below instead of being copied into this profile. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    puzzles
    pause_menu
    battle_bag
    pokedex
    recipe_infog
    picture_cues
    encounter_list
    summary_extra
  ],
  :plugins => %w[item_crafting incubator]
}
