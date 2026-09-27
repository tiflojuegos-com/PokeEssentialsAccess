# Load order for the Pokemon Reborn 19.5 modules (no .rb), after core. What its engine shares with Rejuvenation and
# Desolation (the $cache data, the Inspect report, the randomizer, the field notes, the time and weather app, the
# summary's pages, the passwords menu, the Move Tutor app, the Jukebox, the relay of the game's own reader) comes from
# rv_common; this profile holds what is Reborn's own. Of the plugins in plugins/ it ships FL's Roulette.
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
  ],
  :plugins => %w[fl_roulette]
}
