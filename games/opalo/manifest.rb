# Load order for the opalo game modules (no .rb), loaded after core and the commons it imports, and the plugin
# readers it takes from plugins/.
{
  :imports => %w[lostie_common],
  :modules => %w[
    constants
    puzzles
    floor_traps
    picture_cues
    painted_pictures
    starters
    looks
    photos
    location_banner
    trainer_card
  ],
  :plugins => %w[incubator luka_title spin_tiles fancy_badges]
}
