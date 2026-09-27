# Load order for the pokemon_z modules (no .rb), loaded after core and the commons it imports, and the plugin readers
# it takes from plugins/.
{
  :imports => %w[lostie_common],
  :modules => %w[
    constants
    puzzles
    battle_bag
    pokedex
    picture_cues
    ball_key
    damage_numbers
    turbo
    animated_pokemon
    trainer_sensor
  ],
  :plugins => %w[incubator item_crafting logros summary_habilidades dp_pausemenu simple_encounter_list bag_search_entry slide_banners luka_title fancy_badges]
}
