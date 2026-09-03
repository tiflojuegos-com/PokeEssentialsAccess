# Load order for the royal game modules (no .rb), loaded after core. Edit to add/reorder.
# Thirteen of this game's screens come from THIRD-PARTY plugins other fangames ship too, so their readers live
# in plugins/ and are declared below instead of being copied here. The declared list is the authority; this
# note only says why they are not in this folder. See plugins/manifest.rb.
{
  :modules => %w[
    constants
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
  ],
  :plugins => %w[arcky_region_map bag_screen_party berrydex better_summary ekans_snake encounter_list_ui hall_of_fame_bw item_find logros multi_save photo_album secret_bases tip_cards pokegear_themes hatcher dbk_battle dbk_enhanced_ui magic_gachapon bag_search_entry sky_bag slide_banners]
}
