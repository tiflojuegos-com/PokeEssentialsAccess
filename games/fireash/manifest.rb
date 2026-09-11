# Load order for the Pokemon Fire Ash game modules (no .rb), loaded after core. Fire Ash is Essentials v19
# on a modern mkxp-z, so core/v21 covers everything vanilla; only the screens the fork ADDS need readers.
#
# The plugin list is empty on purpose and not :auto. The game ships thirty-odd plugins of its own, none of
# them one the mod has a reader for: the detection table found no match in the whole tree. Naming none is
# the honest answer, and it costs nothing to fill in when a reader for one of them is written.
{
  :modules => %w[
    records
    gc_card
    enemy_buffs
    battle_swap
  ],
  :plugins => %w[]
}
