# Load order for the anil game modules (no .rb), loaded after core. Edit to add/reorder.
# The challenge rule editor, the Hall of Fame PC viewer and the photo album are THIRD-PARTY plugins shared
# with other fangames, so their readers live in plugins/ and are declared below. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    dppausemenu
    cableclub
    event_menus
    monotype
  ],
  :plugins => %w[advanced_items bag_screen_party better_summary challenge_rules encounter_list_ui hall_of_fame_bw item_find misc_scripts_anil multi_save photo_album sv_summary_screen]
}
