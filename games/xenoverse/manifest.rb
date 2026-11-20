# Load order for the Pokemon Xenoverse 1.5.5 modules (no .rb), after core, and the plugin readers it takes from plugins/.
# Xenoverse is Essentials v16 with the Elite Battle System and its own sprite screens, played on the mkxp-z that ships as
# snGame_n.exe; compat.rb is not a module: mkxp.json's preloadScript runs it before the game's scripts.
{
  :modules => %w[
    constants
    passability
    field_moves
    painted
    naming
    title
    game_modes
    fullbox
    gender
    starter
    menu
    bag
    mart
    battle_menus
    battle_bag
    caught_pokemon
    party
    summary
    controls
    badges
    storage
    pause_screens
    move_learner
    pokewes
    field_screens
    tournament
    puzzles/root_gym
    puzzles/tide_gym
    puzzles/rhythm_gym
    puzzles/shyleon_temple
    puzzles/purgatory
    puzzles/quasar_express
    puzzles/dimension_lair
    puzzles/eldiw_casino
    puzzles/nests
    puzzles/regi_tombs
    puzzles/altered_zodiac
    puzzles/dielebi_rooms
    puzzles/bunker
    puzzles/nest_trials
    puzzles/wandering_legends
  ],
  :plugins => %w[bes_region_map ebs_scene ebs_ui fancy_badges luka_title]
}
