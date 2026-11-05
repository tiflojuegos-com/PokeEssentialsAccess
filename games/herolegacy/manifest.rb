# Load order for the Pokémon Hero Legacy modules (no .rb), loaded after core. Hero Legacy is Essentials v21.1 on mkxp-z with
# Ruby 3.1; its screens are stock or public plugins, read by core and by plugins/ (declared under :plugins).
{
  :modules => %w[
    constants
    passability
  ],
  :plugins => %w[arcky_region_map berry_pots berrydex charm_case dbk_battle encounter_list_ui enhanced_pokemon_ui
                 event_indicators fl_diploma fl_pokegear_watch fl_set_controls_v2 item_crafting item_find mm3_achievements pokegear_themes
                 quest_ui result_panel rock_climb_ex type_match voltseon_pausemenu]
}
