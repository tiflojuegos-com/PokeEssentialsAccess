# Load order of the Pokemon Perseida modules (no .rb), after core and the common it imports; Perseida is gen-6, on
# Essentials BES. :plugins names the third-party plugin readers it loads from plugins/ (see plugins/manifest.rb); its
# autosave paints a banner, which slide_banners reads, so kyu_autosave would say it twice, and its books, gifts and
# encounter list are other versions of those plugins, read here or by encounter_pages.
{
  :imports => %w[clara_common],
  :modules => %w[
    constants
    words
    passability
    field_moves
    pause
    summary
    storage
    party
    bag
    books
    mystery_gift
    quests
    crafting
    quest_markers
    battle_box
    battle_scene
    battle_info
    raid
    tutorials
    pokegear
    type_choice
    gacha
    notices
    claw
    ghost_gym
    crossings
    title
  ],
  :plugins => %w[advanced_pokedex_v16 battle_lives bes_region_map boon_side_stairs encounter_pages fancy_badges
                 fl_roulette incubator item_crafting logros magic_gachapon menu2_pausemenu quest_marker quest_ui
                 slide_banners spin_tiles starter_selection text_log]
}
