# Load order for the emerald game modules (no .rb), loaded after core and after the plugins it declares.
#
# Almost everything this game needs beyond core comes from third-party plugins, and the profile exists to
# declare exactly which ones. It ran on the generic profile until now, and that was wrong: generic is the
# FALLBACK for games nobody has written a profile for, so putting emerald's plugins there told every unknown
# fangame it had them.
{
  :modules => %w[
    battle_point_mart
  ],
  :plugins => %w[bag_screen_party bw_mystery_gift challenge_rules encounter_list_ui hgss_dexlist item_crafting item_find multi_save quest_ui regicode rse_starters secret_bases video_poker wardrobe dbk_battle dbk_enhanced_ui]
}
