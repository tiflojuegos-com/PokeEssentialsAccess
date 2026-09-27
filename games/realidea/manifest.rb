# Load order for the Realidea modules (no .rb), loaded after core, and the plugin readers it takes from plugins/.
{
  :modules => %w[
    constants
    quest_markers
    system_scene
    album
    minigames
    shipwreck
    porygon_ray
    mouse_minigames
    story_minigames
    lasers
    jade_screens
    scenes
    encounters
    hall_of_fame
    pause_overlay
    gacha
    bag_qty
    quiet_search
    spin_stop
    slides
  ],
  :plugins => %w[easy_questing gender_selection text_log book_scene hatcher simple_encounter_list luka_title marin_side_stairs spin_tiles hall_of_fame_bw_gen6 quest_marker fancy_badges]
}
