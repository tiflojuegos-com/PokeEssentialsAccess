# Load order for the Pokemon Awakening modules (no .rb), after core; Awakening is Essentials v17.2 (gen-6).
# :plugins names the third-party plugin readers it loads from plugins/ (see plugins/manifest.rb).
{
  :modules => %w[
    constants
    pausemenu
    glossary
    outfits
    compendium
    extras
    fates_screens
    cmoon
    fates_extra
    load_panel
    boss_box
    floor_trap
    quest_markers
    battle_info
    battle_hud
    quotes
    tea_time
    psyduck_hunt
    quests
    passability
    puzzles/statue_marks
    puzzles/turning_statues
    puzzles/tethys_statues
    puzzles/light_current
    puzzles/arrow_mazes
    puzzles/wind_shrine
    puzzles/empyrean
    puzzles/purgatory
    puzzles/desert_dungeon
    puzzles/pernettia
    puzzles/combretum
    puzzles/combretum_mines
    puzzles/edelweiss_oratory
  ],
  :plugins => %w[advanced_pokedex easy_questing gender_selection item_crafting logros text_log book_scene hatcher simple_encounter_list magic_gachapon slide_banners luka_title pokemon_achievements quest_marker kyu_autosave teleport_menu battle_lives multiple_protagonists]
}
