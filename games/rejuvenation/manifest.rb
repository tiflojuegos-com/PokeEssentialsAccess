# Load order for the Pokemon Rejuvenation 14 modules (no .rb), after core; what its engine shares with Reborn and
# Desolation comes from rv_common. It ships the Modern Quest System, edited, and FL's Roulette.
{
  :imports => %w[rv_common],
  :modules => %w[
    constants
    own_voice
    level_up
    used_items
    quests
    achievements
    blessings
    luck_swap
    pokedex
    region_map
    text_entry
    inspect
    encounters
    passwords
    move_tutor
    zygarde
    trainer_card_gbc
    bag_favourites
    voltorb_flip
  ],
  :plugins => %w[quest_ui fl_roulette]
}
