# Load order for the sevii game modules (no .rb), loaded after core, and the plugin readers it takes
# from plugins/.
{
  :modules => %w[
    constants
    contests
    party
    passability
    pokedex
    screens
    intro
    field_screens
    cycling_road
    berry_blender
    pokeblocks
    pictures
    chapters
    vending_machine
    battle_menus
    battle_bag
    summary
    puzzles/rocket_hq
    puzzles/spin_floors
    puzzles/warp_tiles
    puzzles/lost_cave
    puzzles/altering_cave
    puzzles/icefall_cave
    puzzles/regi_chambers
    puzzles/tanoby_key
    puzzles/trick_house
    puzzles/meteor_falls
    puzzles/sootopolis_plan
    puzzles/sootopolis_gym
    puzzles/sky_pillar
    puzzles/hoenn_field
    puzzles/fortree_plan
    puzzles/fortree_gym
    puzzles/distortion_world
  ],
  :plugins => %w[cable_club dp_pausemenu easy_questing ebs_scene ebs_ui fl_diploma fl_set_controls hatcher luka_title
                 simple_encounter_list summary_six_pages]
}
