# Load order for the royal game modules (no .rb), loaded after core and the commons it imports. Edit to add/reorder.
# The screens of third-party plugins other fangames ship too are read by plugins/, declared under :plugins.
{
  :imports => %w[skyflyer_common royal_common],
  :modules => %w[
    constants
    currydex
    curry_select
    menu_parrilla
    tarjetas_liga
    tarjeta_entrenador
    mep_exp
    curry_result
    rhythm
    hall_of_fame
    zacian_battle
    secret_base_shop
    comba
    internet_date
    berry_flavors
    passability
  ],
  :plugins => %w[arcky_region_map bag_screen_party berrydex better_summary ekans_snake encounter_list_ui dynamax enhanced_pokemon_ui improved_mementos hall_of_fame_bw item_find logros multi_save photo_album party_picture secret_bases storage_utilities tip_cards pokegear_themes fl_pokegear_watch fl_tilt_labyrinth berry_pots hatcher dbk_battle dbk_enhanced_ui magic_gachapon bag_search_entry sky_bag slide_banners bw_key_items modular_title marin_side_stairs fancy_badges]
}
