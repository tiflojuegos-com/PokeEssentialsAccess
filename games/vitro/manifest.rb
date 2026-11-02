# Load order of the Pokemon GS Vitro modules (no .rb), after core; GS Vitro is gen-6, on Essentials BES.
# :plugins names the third-party plugin readers it loads from plugins/ (see plugins/manifest.rb). Its berry pots, teleport
# menu and encounter list are other versions of those plugins, read here; its region map is the better one, so BES's never
# opens; and its autosave paints a banner, which slide_banners reads.
{
  :modules => %w[
    constants
    keys
    words
    lens
    passability
    field_moves
    pause
    summary
    party
    bag
    quests
    region_map
    encounters
    berry_pots
    teleport
    title
    controls
    hall_of_fame
    starter_selection
    battle_menus
    battle_box
    battle_bag
    ball_selector
    exp_panel
    contests
    berry_blender
    pokegear
    radio
    walker
    code_trade
    ev_redistributor
    selectors
    creature_mart
    pokedex_menu
    tarot
    wild_map
    map_objects
    rock_holes
    door_puzzle
    credits
    bug_contest
  ],
  :plugins => %w[advanced_pokedex_v16 alt_mystery_gift bes_bag bes_battle bes_battle_info bes_move_info bes_summary
                 better_region_map bloc_unown boon_side_stairs bw_gender_selector easy_unown_text fancy_badges incubator
                 item_find luka_title menu2_pausemenu quest_marker quest_ui slide_banners text_log tip_cards]
}
