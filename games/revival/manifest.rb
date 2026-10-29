# Load order for the Pokemon Revival modules (no .rb), loaded after core. Revival is Essentials v21.1 on La Base de Sky
# (mkxp-z, Ruby 3.1), in Spanish and English: its stock screens are core's and Sky's base's are skyflyer_common's,
# the third-party plugins other games ship too are read by plugins/ (declared under :plugins), and what the game wrote
# or edited is read here.
{
  :imports => %w[skyflyer_common],
  :modules => %w[
    constants
    passability
    field_moves
    phase_menu
    character_select
    pause_menu
    world_map
    splashes
    cards
  ],
  :plugins => %w[bag_screen_party bag_search_entry better_summary dbk_battle dbk_enhanced_ui encounter_list_ui
                 enhanced_pokemon_ui fl_pokegear_watch hatcher item_find modular_title pokegear_themes quest_ui
                 slide_banners storage_utilities tip_cards]
}
