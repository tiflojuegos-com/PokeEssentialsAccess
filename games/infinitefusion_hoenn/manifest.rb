# Load order for the Pokemon Infinite Fusion 2 (Hoenn) modules (no .rb), after core; the game is Essentials v18
# (GameData, but still $Trainer and PokeBattle_Scene). What it shares with Kanto comes from infinitefusion_common.
{
  :imports => %w[infinitefusion_common],
  :modules => %w[
    starters
    color_door
    pokeblocks
    floor_holes
    acro_rails
    contests
    overworld
    market
    rival
    secret_base
    chair_clock
    weather
    title
    hall_of_fame
    clefairy_board
    time_trial
    bike_color
    wild_notice
    safari
    passability
    puzzles/mauville_gym
    puzzles/trick_house
    puzzles/illusion_grove
    puzzles/mud_slopes
    puzzles/side_stairs
    puzzles/route109_beach_ball
    puzzles/granite_cave
    puzzles/nest_hats
  ],
  :plugins => %w[berrydex multi_save better_region_map luka_title]
}
