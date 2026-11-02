# Load order for the Pokemon Desolation 6.0.0 modules (no .rb), after core; what its engine shares with Reborn and
# Rejuvenation comes from rv_common. Of plugins/ it carries FL's Roulette and FL's Advanced Pokedex in the version
# Pokemon Z and Essentials BES ship.
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    quest_log
    jinx_scent
  ],
  :plugins => %w[fl_roulette advanced_pokedex_v16]
}
