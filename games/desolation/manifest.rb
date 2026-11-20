# Load order for the Pokemon Desolation 6.0.13 modules (no .rb), after core; what its engine shares with Reborn and
# Rejuvenation comes from rv_common. Of plugins/ it carries FL's Roulette and FL's Advanced Pokedex in the version
# Pokemon Z and Essentials BES ship.
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    quest_log
    jinx_scent
    puzzles/celeste_gym
    puzzles/keneph
    puzzles/vejyr
    puzzles/silver_rise
    puzzles/black_fox_base
    puzzles/blackview
    puzzles/cellia
    puzzles/weeping_depths
    puzzles/redcliff_cave
    puzzles/arcanius
    puzzles/insight
    puzzles/elmora
    puzzles/serenity_photos
  ],
  :plugins => %w[fl_roulette advanced_pokedex_v16]
}
