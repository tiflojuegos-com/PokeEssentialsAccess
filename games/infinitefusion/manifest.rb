# Load order for the Pokemon Infinite Fusion (Kanto) modules (no .rb), after core; the game is Essentials v18
# (GameData, but still $Trainer and PokeBattle_Scene). What it shares with Hoenn comes from infinitefusion_common.
{
  :imports => %w[infinitefusion_common],
  :modules => %w[quest_branches],
  :plugins => %w[easy_questing multi_save better_region_map luka_title]
}
