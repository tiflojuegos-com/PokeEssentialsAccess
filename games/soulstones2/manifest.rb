# Load order for the Soulstones 2 game modules (no .rb), loaded after core. The game runs Essentials v20.1
# under the title "Time Wardens", so core/v21 covers the vanilla screens. The plugin list is what the
# detection census finds in its tree, checked against the copy it ships: three of them come from "[Edited] "
# folders (Voltseon's Pause Menu 1.8, ItemFind Description, Encounter List UI 1.0.2), which edited the
# drawing and not the surface the shared readers use. dbk_enhanced_ui is NOT among them on purpose: this
# game carries an older, edited Enhanced UI whose arities differ, read by enhanced_ui.rb here, and the same
# rule (an edited copy of a plugin is read from its game's profile) puts DBK Raid Battles in raid_cheer.rb
# and raid_den.rb.
{
  :modules => %w[enhanced_ui box_picker renamed_screens tutor_net own_tts type_chart raid_cheer raid_den notices],
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
  ]
}
