# Load order for what Clara Dragon's games share (no .rb), a base with no public source: the fishing minigame, the arcane
# clock, the summary's friendship, EVs and information page and the boss's battle box. Imported by each game, loaded
# before its own modules.
{
  :modules => %w[
    fishing
    arcane_clock
    summary_info
    boss_box
  ]
}
