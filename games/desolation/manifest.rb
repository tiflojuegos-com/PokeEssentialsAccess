# Load order for the Pokemon Desolation 6.0.0 modules (no .rb), after core. What its engine shares with Reborn and
# Rejuvenation (the $cache data, map names, the field notes, the summary pages, the Pokedex pages, the passwords menu)
# comes from rv_common; this profile holds what is Desolation's own. The game carries no screen reader of its own, and
# of the plugins in plugins/ only FL's Roulette; its Advanced Pokedex is FL's in the version Pokemon Z ships.
{
  :imports => %w[rv_common],
  :modules => %w[
    advanced_dex
    quest_log
    jinx_scent
  ],
  :plugins => %w[fl_roulette]
}
