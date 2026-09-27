# Load order for the emerald game modules (no .rb), loaded after core, and the plugin readers it takes from plugins/,
# which cover most of what it adds.
{
  :modules => %w[
    battle_point_mart
  ],
  :plugins => %w[bag_screen_party bw_mystery_gift challenge_rules encounter_list_ui enhanced_pokemon_ui event_indicators hgss_dexlist pwt item_crafting item_find multi_save quest_ui regicode rse_starters secret_bases video_poker wardrobe dbk_battle dbk_enhanced_ui modular_title sv_summary_prompts]
}
