# Load order for the Pokemon Solar Light & Lunar Dark 1.0.1 modules (no .rb), after core; it is Essentials v17.2
# (gen-6). :plugins names the third-party plugin readers it loads from plugins/ (see plugins/manifest.rb).
{
  :modules => %w[
    constants
    pause_menu
    passability
    currents
    jumps
    puzzles/waytide_gym
    puzzles/goldune_gym
    puzzles/highpoint_gym
    puzzles/subhail_gym
    puzzles/subhail_icecaps
    puzzles/temples
    puzzles/sario_gate
    puzzles/rustbolt_dancer
    puzzles/lake_bliss
    puzzles/victory_isle
  ],
  :plugins => %w[easy_questing fancy_badges starter_selection easy_badge_case]
}
