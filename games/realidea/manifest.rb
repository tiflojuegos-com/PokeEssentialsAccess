# Load order for the Realidea modules (no .rb), loaded after core, and the plugin readers it takes from plugins/.
{
  :modules => %w[
    constants
    quest_markers
    system_scene
    album
    minigames
    puzzles/shipwreck
    porygon_ray
    mouse_minigames
    story_minigames
    puzzles/lasers
    puzzles/jade_screens
    puzzles/quartz_gym
    puzzles/agate_gym
    puzzles/berilo_basement
    puzzles/metis_labs
    puzzles/decidueye_hideout
    puzzles/abandoned_mansion
    puzzles/route17_lab
    puzzles/power_plant
    puzzles/electruby_cave
    puzzles/anatasa_gym
    scenes
    hall_of_fame
    pause_overlay
    gacha
    bag_qty
    passability
    spin_stop
    slides
    field_moves
    levers
    party
  ],
  :plugins => %w[easy_questing encounter_pages gender_selection text_log book_scene hatcher simple_encounter_list luka_title marin_side_stairs spin_tiles hall_of_fame_bw_gen6 quest_marker fancy_badges]
}
