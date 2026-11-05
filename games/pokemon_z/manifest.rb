# Load order for the pokemon_z modules (no .rb), loaded after core and the commons it imports, and the plugin readers
# it takes from plugins/.
{
  :imports => %w[lostie_common],
  :modules => %w[
    constants
    puzzles/sanctuary
    puzzles/ship
    puzzles/gym3
    puzzles/palace
    puzzles/riddle_island
    puzzles/hidden_spa
    puzzles/kitchen
    puzzles/wandering_forest
    puzzles/refulgent_cave
    puzzles/chateau_lanto
    puzzles/fort_leviathan
    puzzles/dark_tower
    puzzles/romantis
    puzzles/ultimate_weapon
    puzzles/dark_tangle
    puzzles/fractal_bastion
    puzzles/talasia_cave
    puzzles/pokeball_factory
    puzzles/ancient_forge
    battle_bag
    pokedex
    picture_cues
    ball_key
    damage_numbers
    turbo
    animated_pokemon
    trainer_sensor
    passability
  ],
  :plugins => %w[incubator item_crafting logros summary_habilidades dp_pausemenu simple_encounter_list bag_search_entry slide_banners luka_title fancy_badges]
}
