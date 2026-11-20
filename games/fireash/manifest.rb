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
    field_moves
    striaton_leaders
    puzzles/pads
    puzzles/vermilion_gym
    puzzles/saffron_gym
    puzzles/cinnabar_mansion
    puzzles/cinnabar_gym
    puzzles/lavaridge_gym
    puzzles/mossdeep_gym
    puzzles/hearthome_gym
    puzzles/laverre_gym
    puzzles/nacrene_museum
    puzzles/snowbelle_route
    puzzles/wild_area
    puzzles/lumiose_gym
    puzzles/mauville_gym
    puzzles/twist_mountain
  ],
  :plugins => %w[dynamax multi_save_v19 zud_max_lair zud_raid_database zud_raid_dens]
}
