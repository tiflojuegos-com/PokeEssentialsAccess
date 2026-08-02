# Load order for the anil game modules (no .rb), loaded after core. Edit to add/reorder.
# The challenge rule editor, the Hall of Fame PC viewer and the photo album are THIRD-PARTY plugins shared
# with other fangames, so their readers live in plugins/ and are declared below. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    dppausemenu
    cableclub
    event_menus
    monotype
  ],
  :plugins => %w[challenge_rules hall_of_fame_bw photo_album music_book]
}
