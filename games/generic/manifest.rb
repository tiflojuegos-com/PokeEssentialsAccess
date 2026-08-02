# Load order for the generic game modules (no .rb), loaded after core. Edit to add/reorder.
# Crafting, the challenge rule editor and the secret bases are third-party plugins: their readers live in
# plugins/ and are declared here. This profile is also the fallback for games with no profile of their own,
# so a declaration here is what gives an unknown game those screens for free.
{
  :modules => %w[
    constants
    pausemenu
  ],
  :plugins => %w[item_crafting challenge_rules secret_bases regicode rse_starters hgss_dexlist quest_ui]
}
