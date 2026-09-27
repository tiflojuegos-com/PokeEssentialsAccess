# Load order of the Pokemon Fire Ash modules (no .rb), after core; Fire Ash is Essentials v19, so core/v21
# covers its vanilla screens. Plugins by hand: ZUD's summary marks (dynamax) and Multiple save (v.19).
{
  :modules => %w[
    records
    gc_card
    enemy_buffs
    fishing_speed
    summary_ivs
    passability
  ],
  :plugins => %w[dynamax multi_save_v19 zud_raid_database]
}
