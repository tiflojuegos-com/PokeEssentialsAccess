# Load order for the opalo game modules (no .rb), loaded after core. Edit to add/reorder.
# The egg incubator is a THIRD-PARTY plugin this game shares with another fangame -- the same file, byte for
# byte -- so its reader lives in plugins/ and is declared below. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    puzzles
    picture_cues
    location_banner
    trainer_card
  ],
  :plugins => %w[incubator]
}
