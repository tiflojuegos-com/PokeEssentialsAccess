# Load order for the worldfrontier game modules (no .rb), loaded after core and the commons it imports: skyflyer_common
# for what Skyflyer's games share, royal_common for the code it took from Pokemon Royal. :plugins names the third-party
# plugin readers (plugins/manifest.rb) this game loads; its [WF] and [ROYAL] plugins are its own, read here.
{
  :imports => %w[skyflyer_common royal_common],
  :modules => %w[
    constants
    passability
    pause_menu
    album
    player_cards
    island_map
    starter_team
    shops
    rental
    roulette
    pwt
    temple
    battle_history
    estadisticas
    battle_ui
    damage_cap
    hall_of_fame
    credits
    visual25d
  ],
  :plugins => %w[bag_screen_party bag_search_entry better_summary bw_key_items dbk_battle dbk_enhanced_ui dynamax
                 encounter_list_ui enhanced_pokemon_ui fl_pokegear_watch hall_of_fame_bw hatcher improved_mementos
                 item_find logros marin_side_stairs modular_title multi_save pokegear_themes rotation_battle sky_bag
                 slide_banners storage_utilities text_log tip_cards]
}
