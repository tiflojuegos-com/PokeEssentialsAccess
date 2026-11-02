# Load order for the Pokemon Dark Horizon modules (no .rb), loaded after core. Dark Horizon is Essentials v21.1 on
# mkxp-z with Ruby 3.1. Its own screens (new game, TV, CP move shop, Trainer Abilities, the Bike and Submarine
# Gallops, Phantom Path) and the copies it edited of Instant Messages, Sea Gallop, Type Match-up UI, the BW Pokedex and
# DiegoWT's Starter Selection are read here; the third-party plugins it ships unedited, and its edit of the BW Gender
# Selector, which paints what Vitro's copy does, are read by plugins/ (under :plugins).
{
  :modules => %w[
    constants
    passability
    field_moves
    new_game
    pokedex
    gallops
    cp_moves
    instant_messages
    type_match
    trainer_abilities
    starter_selection
    phantom_path
  ],
  :plugins => %w[bag_screen_party bw_gender_selector bw_key_items bw_summary ebdx ev_allocator fl_diploma hidden_power_type
                 marin_side_stairs modular_title quest_ui tip_cards voltseon_pausemenu wardrobe]
}
