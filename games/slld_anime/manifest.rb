# Load order for the Pokemon SL & LD - Anime Chronicles modules (no .rb), loaded after core. Essentials v21.1 on mkxp-z
# (Ruby 3.1), scripts packed in Game.rgssad. Its screens are stock or public plugins read by core and by plugins/; its
# own are the episode title cards, Dullfern Forest's spider webs and eight minigames, read as puzzles.
{
  :modules => %w[
    passability
    field
    episodes
    puzzles/mossy_town
    puzzles/serpentine_garden
    puzzles/serpentine_gym
    puzzles/dullfern_forest
    puzzles/blackleaf_woods
    puzzles/crestlight_police
    puzzles/crestlight_gym
    puzzles/route3_contest
    puzzles/serpentine_city
    puzzles/crestlight_fire
  ],
  :plugins => %w[berry_pots dbk_battle fancy_badges fl_daycare_checker fl_game_over multi_save multiple_protagonists pwt
                 quest_ui roei_badge_case voltseon_pausemenu]
}
