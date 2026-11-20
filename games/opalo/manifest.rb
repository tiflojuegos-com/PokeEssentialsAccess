# Load order for the opalo game modules (no .rb), loaded after core and the commons it imports, and the plugin
# readers it takes from plugins/.
{
  :imports => %w[lostie_common],
  :modules => %w[
    constants
    puzzles/machine_gym
    puzzles/psychic_gym
    puzzles/earth_gym
    puzzles/water_gym
    puzzles/ghost_gym
    puzzles/charjabug_gym
    puzzles/ice_gym
    puzzles/voodoo_hall
    puzzles/maple_mansion
    puzzles/ancient_workshop
    puzzles/office_gym
    puzzles/galerna_house
    puzzles/route19_farms
    puzzles/rock_holes
    puzzles/boreal_sewers
    puzzles/spectre_village
    puzzles/golden_bug_casino
    puzzles/gatling_base
    puzzles/xatu_chest
    puzzles/romualdo_treasure
    puzzles/bayamo_police
    puzzles/delibird_cave
    puzzles/tourmaline_mine
    puzzles/area151
    floor_traps
    picture_cues
    painted_pictures
    starters
    looks
    photos
    location_banner
    trainer_card
    passability
  ],
  :plugins => %w[incubator luka_title spin_tiles fancy_badges]
}
