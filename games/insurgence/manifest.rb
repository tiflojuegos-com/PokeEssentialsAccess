# Load order for the Pokemon Insurgence modules (no .rb), after core. Insurgence is gen-6 Essentials on the RPG Maker
# XP player, which the launcher converts to mkxp-z (catalog "convert"); its one plugin is FL's Set the Controls.
{
  :modules => %w[
    constants
    hm7
    soaring
    summary
    custom_move
    battle_marks
    water
    field_moves
    routes
    dex_forms
    naming
    lasers
    intro
    picture_cues
    certificate
    turbo
    bag
    mouse
    dexnav
    leaf_booklet
    challenges
    sponsor
    tournament
    base_upgrades
  ],
  :plugins => %w[fl_set_controls]
}
