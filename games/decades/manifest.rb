# Load order for the Pokémon Decades modules (no .rb), loaded after core. Decades is Essentials v21.1 on mkxp-z with Ruby
# 3.1; its screens are stock or public plugins, read by core and by plugins/ (declared under :plugins).
{
  :modules => %w[
    constants
    passability
  ],
  :plugins => %w[arcky_region_map bag_screen_party dbk_battle dbk_enhanced_ui dynamax encounter_list_ui enhanced_pokemon_ui
                 ev_allocator event_indicators fl_character_selection_v1 fl_set_controls_v2 hidden_power_type improved_mementos
                 modular_pokemon_selection modular_title multi_save quest_ui slide_banners storage_utilities tamas_dexnav
                 tip_cards type_match voltseon_pausemenu]
}
