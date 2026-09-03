# Load order for the pokemon_z game modules (no .rb), loaded after core. Edit to add/reorder.
# The item crafting screen is a THIRD-PARTY plugin shared with other fangames, so its reader lives in
# plugins/ and is declared below instead of being copied into this profile. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    puzzles
    battle_bag
    pokedex
    character_guide
    picture_cues
  ],
  :plugins => %w[incubator item_crafting logros summary_habilidades dp_pausemenu simple_encounter_list bag_search_entry slide_banners]
}
