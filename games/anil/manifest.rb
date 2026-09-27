# Load order for the anil game modules (no .rb), loaded after core and the commons it imports; :plugins names the
# third-party plugin readers (plugins/manifest.rb) this game loads.
{
  :imports => %w[skyflyer_common],
  :modules => %w[
    constants
    cableclub
    event_menus
    monotype
    ability_changer
    pc_search
    summary_happiness
    pause_menu
    punch_bag
    diploma
  ],
  :plugins => %w[advanced_items bag_screen_party better_summary challenge_rules encounter_list_ui enhanced_pokemon_ui hall_of_fame_bw storage_utilities item_find misc_scripts_anil multi_save photo_album party_picture sv_summary_screen sv_summary_prompts pokegear_themes hatcher dbk_battle dbk_enhanced_ui dp_pausemenu hgss_trainer_card bag_search_entry sky_bag bw_key_items modular_title marin_side_stairs fancy_badges]
}
