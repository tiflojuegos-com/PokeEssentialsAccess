# Load order for the emerald game modules (no .rb), loaded after core, and the plugin readers it takes from plugins/,
# which cover most of what it adds.
{
  :modules => %w[
    battle_point_mart
    passability
    puzzles/common
    puzzles/mossdeep_gym
    puzzles/mauville_gym
    puzzles/sootopolis_gym
    puzzles/lavaridge_gym
    puzzles/aqua_hideout
    puzzles/legend_sites
    puzzles/story_switches
    puzzles/crumbling_floors
    puzzles/navel_rock
    puzzles/desert_underpass
    puzzles/baobab_lab
    puzzles/trick_house
    puzzles/seafoam_islands
    puzzles/sky_base
  ],
  :plugins => %w[bag_screen_party bw_mystery_gift challenge_rules encounter_list_ui enhanced_pokemon_ui event_indicators hgss_dexlist pwt item_crafting item_find multi_save quest_ui regicode rse_starters secret_bases video_poker wardrobe dbk_battle dbk_enhanced_ui modular_title sv_summary_prompts]
}
