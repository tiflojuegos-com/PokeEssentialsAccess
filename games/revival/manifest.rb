# Load order for the Pokemon Revival modules (no .rb), loaded after core. Revival is Essentials v21.1 on La Base de Sky
# (mkxp-z, Ruby 3.1), in Spanish and English: its stock screens are core's, Sky's base's and the third-party
# plugins other games ship too are read by plugins/ (declared under :plugins), and what the game wrote or edited is read
# here.
{
  :modules => %w[
    constants
    passability
    field_moves
    character_obstacles
    phase_menu
    character_select
    pause_menu
    world_map
    splashes
    cards
    centers
    puzzles/avalon_castle
    puzzles/ranger_base
    puzzles/tunia_hack
    puzzles/sun_palace
    puzzles/black_rose_dungeon
  ],
  :plugins => %w[bag_screen_party bag_search_entry better_summary dbk_battle dbk_enhanced_ui encounter_list_ui
                 enhanced_pokemon_ui fl_pokegear_watch hatcher item_find modular_title pokegear_themes quest_ui
                 slide_banners storage_utilities tip_cards sky_base sky_trainer_sensor]
}
