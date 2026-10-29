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
  ],
  :plugins => %w[cable_club dp_pausemenu easy_questing ebs_scene ebs_ui fl_diploma fl_set_controls hatcher luka_title
                 simple_encounter_list summary_six_pages]
}
