# Load order for the Pokemon Reborn 19.5 modules (no .rb), after core; what its engine shares with Rejuvenation and
# Desolation comes from rv_common. Of plugins/ it ships FL's Roulette.
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    own_voice
    fight_menu
    blindstep
    move_tutor
    credits
    battle_box
    documents
    theme_teams
    field_moves
  ],
  :plugins => %w[fl_roulette]
}
