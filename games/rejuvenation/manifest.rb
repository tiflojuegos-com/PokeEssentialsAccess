# Load order for the Pokemon Rejuvenation 14 modules (no .rb), after core. What its engine shares with Reborn and
# Desolation (the $cache data, the Inspect report, the field notes, the time and weather app, the summary's pages, the
# Move Tutor app, the Jukebox, the relay of the game's own reader) comes from rv_common; this profile holds what is
# Rejuvenation's own. It ships the Modern Quest System, edited, and FL's Roulette.
{
  :imports => %w[rv_common],
  :modules => %w[
    own_voice
    level_up
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
  ],
  :plugins => %w[quest_ui fl_roulette]
}
