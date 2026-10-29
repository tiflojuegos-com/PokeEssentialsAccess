# Load order for the Grueling Gold modules (no .rb), loaded after core. Grueling Gold is Essentials v20.1 on mkxp-z with
# Ruby 3.1; most of its screens are stock or third-party plugins, read by core and by plugins/ (declared under
# :plugins). Its egg move tutor, a renamed copy of the stock relearner, and its mission reminder are its own, and its
# New DexNav a copy edited to the game, so their readers are here.
{
  :modules => %w[
    passability
    egg_relearner
    new_dexnav
    mission_log
  ],
  :plugins => %w[berry_pots dbk_battle dbk_enhanced_ui encounter_list_ui enhanced_pokemon_ui essentials_deluxe
                 hm_catalogue item_find marin_side_stairs modular_title quest_ui]
}
