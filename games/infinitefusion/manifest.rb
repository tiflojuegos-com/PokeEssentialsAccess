# Load order for the Pokemon Infinite Fusion (Kanto) modules (no .rb), after core; the game is Essentials v18
# (GameData, but still $Trainer and PokeBattle_Scene). What it shares with Hoenn comes from infinitefusion_common.
{
  :imports => %w[infinitefusion_common],
  :modules => %w[startup_cache locked_doors ss_anne_waiter surf_race cloud_path magikarp_ride
                 puzzles/azalea_gym puzzles/goldenrod_gym puzzles/violet_gym
                 puzzles/slowpoke_well puzzles/rocket_hideout puzzles/blackthorn_gym puzzles/mahogany_gym
                 puzzles/burned_tower puzzles/ecruteak_gym puzzles/vermilion_gym puzzles/celadon_sewers
                 puzzles/silph_co puzzles/saffron_gym puzzles/pokemon_mansion puzzles/cinnabar_gym puzzles/mt_ember
                 puzzles/fuchsia_gym puzzles/viridian_gym puzzles/victory_road
                 puzzles/lake_of_rage puzzles/dragons_den puzzles/ice_mountains_peak puzzles/submerged_temple
                 puzzles/regi_chambers
                 puzzles/mt_moon_observatory puzzles/lavender_bell puzzles/route13_rhyhorn puzzles/creepy_house
                 puzzles/power_plant puzzles/seafoam_islands puzzles/vermilion_truck puzzles/bell_tower
                 puzzles/ruins_of_alph puzzles/cerulean_cave puzzles/berry_forest puzzles/old_shipwreck
                 puzzles/ruby_chamber puzzles/kindle_road puzzles/moonlit_forest
                 puzzles/ilex_forest puzzles/saffron_nightclub puzzles/cyberspace puzzles/chrono_warehouse
                 puzzles/nest_hats puzzles/sky_pillar puzzles/deep_sea],
  :plugins => %w[berrydex multi_save better_region_map luka_title]
}
