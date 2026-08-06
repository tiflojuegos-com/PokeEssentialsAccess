# Load order for the Pokemon Awakening game modules (no .rb), loaded after core. Awakening is Essentials
# v17.2 (gen-6), covered by the core gen-6 path; only its bespoke Fates screens need readers here.
# The item crafting screen is a THIRD-PARTY plugin shared with other fangames, so its reader lives in
# plugins/ and is declared below instead of being copied into this profile. See plugins/manifest.rb.
{
  :modules => %w[
    constants
    pausemenu
    dexnav
    glossary
    outfits
    compendium
    teleport
    extras
    fates_screens
    cmoon
    fates_extra
  ],
  :plugins => %w[easy_questing gender_selection item_crafting logros text_log]
}
