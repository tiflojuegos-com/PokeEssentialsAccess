# Load order of the Pokemon Edas modules (no .rb), after core and the common it imports; Edas is gen-6, on Essentials
# BES. :plugins names the third-party plugin readers it loads from plugins/ (see plugins/manifest.rb); its autosave
# (kyu_autosave) has lost its only call, and its banner paints words the slide banners read anyway.
{
  :imports => %w[clara_common],
  :modules => %w[
    constants
    words
    passability
    field_moves
    lens
    pictures
    load_screen
    pause
    quests
    storage
    idol
    puzzles/nos_village
    puzzles/memory_mansion
    puzzles/carcitoma_crossroads
    puzzles/azure_lookout
  ],
  :plugins => %w[battle_lives book_scene boon_side_stairs easy_questing fancy_badges luka_title menu2_pausemenu slide_banners text_log]
}
