# Load order for the Soulstones 2 modules (no .rb), after core (Essentials v20.1). Its "[Edited] " Pause Menu,
# ItemFind and Encounter List UI changed only their drawing, so shared readers serve them; its edited Enhanced
# UI and DBK Raid Battles are read by enhanced_ui, raid_cheer and raid_den, so dbk_enhanced_ui stays out.
{
  :modules => %w[enhanced_ui box_picker renamed_screens tutor_net own_tts type_chart raid_cheer raid_den notices
                 quests boss_shields battle_selectors battle_belt
                 summary_ivs egg_groups encounter_cursor intro_gender bag_sort raid_adventure styled_box
                 hall_of_fame chapters showcase battle_marks],
  :plugins => %w[
    voltseon_pausemenu
    item_crafting
    hatcher
    quest_ui
    bag_screen_party
    item_find
    encounter_list_ui
    multi_save
    party_showcase
    ev_allocator
    hidden_power_type
    storage_utilities
    directional_sliding
    item_radar
  ]
}
