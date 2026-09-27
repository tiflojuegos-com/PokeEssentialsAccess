# Load order for the royal game modules (no .rb), loaded after core and the commons it imports. Edit to add/reorder.
# The screens of third-party plugins other fangames ship too are read by plugins/, declared under :plugins.
{
  :imports => %w[skyflyer_common],
  :modules => %w[
    constants
    key_hints
    selectors
    currydex
    curry_select
    menu_parrilla
    tarjetas_liga
    tarjeta_entrenador
    mep_exp
    curry_result
    iconos_leyenda
    puntos
    rhythm
    creador
    controles
    hall_of_fame
    zacian_battle
    dex_types
    bag_register
    borde_messages
    incubator_level
    egg_tutor
    relearner_labels
    stairs
    secret_base_shop
    comba
    internet_date
    tip_menu
    berry_flavors
    super_shiny
  ],
  :plugins => %w[arcky_region_map bag_screen_party berrydex better_summary ekans_snake encounter_list_ui dynamax enhanced_pokemon_ui improved_mementos hall_of_fame_bw item_find logros multi_save photo_album party_picture secret_bases storage_utilities tip_cards pokegear_themes hatcher dbk_battle dbk_enhanced_ui magic_gachapon bag_search_entry sky_bag slide_banners bw_key_items modular_title marin_side_stairs fancy_badges]
}
