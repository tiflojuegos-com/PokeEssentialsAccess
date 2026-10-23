# Load order for the Pokemon Desolation 6.0.0 modules (no .rb), after core; what its engine shares with Reborn and
# Rejuvenation comes from rv_common. Of plugins/ it carries only FL's Roulette; its Advanced Pokedex is FL's in the
# version Pokemon Z ships.
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    advanced_dex
    quest_log
    jinx_scent
  ],
  :plugins => %w[fl_roulette]
}
