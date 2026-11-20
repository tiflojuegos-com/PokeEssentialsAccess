# Load order for the Keishou modules (no .rb), loaded after core. Keishou is Essentials v20.1 on mkxp-z with Ruby 3.1; most
# of its screens are stock or public plugins, read by core and by plugins/ (declared under :plugins). Its tournament record
# and the timed or chased challenges of its temples and of Sakyu Valley are its own, and its Advanced Items and Event Indicators older copies with a Rock Climb, breakable ice and quest marks of
# their own.
{
  :modules => %w[
    constants
    passability
    rock_climb
    ice
    summary
    crafting
    aki_record
    quest_marks
    minigames
    puzzles/suna_beach
    puzzles/monkeys
    puzzles/noyanagi
    puzzles/shimo_mountain
    puzzles/kiri_forest
    puzzles/coastal_cave
    puzzles/kazan_mountain
    puzzles/sakyu_valley
    puzzles/road_of_ascension
    puzzles/yama_passage
    puzzles/haiiro_chamber
    puzzles/cavern_of_creation
    puzzles/hidden_seals
    puzzles/cavern_of_order
    puzzles/nightmare
    puzzles/bonding_dreams
    puzzles/temple_challenges
    puzzles/terastal_caves
  ],
  :plugins => %w[bag_screen_party berry_pots charm_case dynamax encounter_list_ui enhanced_ui_v1 essentials_deluxe
                 fl_tilt_labyrinth hacking_minigame item_crafting item_find multi_save punch_bag_v12 quest_ui
                 storage_utilities terastal_phenomenon voltseon_pausemenu zud_max_lair zud_raid_database zud_raid_dens]
}
