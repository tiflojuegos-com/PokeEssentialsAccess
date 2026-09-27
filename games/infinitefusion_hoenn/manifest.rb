# Load order for the Pokemon Infinite Fusion 2 (Hoenn) modules (no .rb), after core; the game is Essentials v18
# (GameData, but still $Trainer and PokeBattle_Scene). What it shares with Kanto comes from infinitefusion_common.
{
  :imports => %w[infinitefusion_common],
  :modules => %w[
    starters
    color_door
    pokenav
    quests
    pokeblocks
    cursor_modes
    floor_holes
    acro_rails
    contests
    overworld
    region_map
    weather
    title
    fusion_quiz
    hall_of_fame
    fusion_family
  ],
  :plugins => %w[berrydex multi_save better_region_map luka_title]
}
