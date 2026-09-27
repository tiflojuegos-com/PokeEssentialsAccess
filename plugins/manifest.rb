# Third-party plugin readers, loaded by the profiles that declare them (:plugins in their manifest.rb). This
# table maps each name to the class or "Class#method" that gives the plugin away, so the diagnostic can report
# one a profile never declared. Adding a plugin: a file here, a line here, its name in each profile shipping it.
{
  # Movement plugins read by the route finder, probed by a method since none brings a class.
  :marin_side_stairs   => "Game_Character#on_middle_of_stair?",
  :directional_sliding => "GameData::TerrainTag#slide_up",
  :spin_tiles          => "PokemonGlobalMetadata#spinning",
  :item_crafting     => "ItemCraft_Scene",
  :gender_selection  => "PokemonGenderSelection",
  :text_log          => "Log",
  :incubator         => "Incubadora",
  :challenge_rules   => "Window_CommandPokemon_Challenge",
  :hall_of_fame_bw   => "HallOfFameViewerScene",
  :photo_album       => "AlbumFotos_Scene",
  :party_picture     => "PartyPicture",
  :berrydex          => "Window_Berrydex",
  :secret_bases      => "Window_BasePocketsList",
  :regicode          => "RC",
  :rse_starters      => "RSESTarterChoice",
  :hgss_dexlist      => "PokedexListSprite",
  # A method probe: the stock card is the same class, and only this one has a back.
  :hgss_trainer_card => "PokemonTrainerCard_Scene#pbDrawTrainerCardBack",
  :summary_habilidades => "PokemonSummaryScene#Habilidades",
  :book_scene        => "BookScene",
  :bag_search_entry  => "WindowTextEntryKeyboardPerKey",
  # A method probe on an engine class: the fork adds favourite? to the bag every game has.
  :sky_bag           => "PokemonBag#favourite?",
  :pokegear_themes   => "PokemonPokegearTheme_Scene",
  :hatcher           => "Hatcher",
  :better_region_map => "BetterRegionMap",
  :dp_pausemenu      => "DP_PauseMenu",
  :voltseon_pausemenu => "VoltseonsPauseMenu",
  :simple_encounter_list => "EncounterListUI",
  :magic_gachapon    => "GachaScene",
  :slide_banners     => "Scene_Map#addSprite",
  # The DBK readers probe a method the kit adds to a vanilla battle class, which alone would match every game.
  :dbk_battle        => "Battle#pbToggleSpecialActions",
  # Probed by pbGetFinalModifiers, not pbUpdateBattlerInfo: the older 1.1.2 (Soulstones 2) has the same method
  # names with other arities, which this reader, written for the current release, must not bind to.
  :dbk_enhanced_ui   => "Battle::Scene#pbGetFinalModifiers",
  :quest_ui          => "Window_Quest",
  :logros            => "Logros_Scene",
  # A method probe: another game defines an unrelated Questlog class; the method the reader hooks tells them apart.
  :easy_questing     => "Questlog#pbMain",
  :tip_cards         => "TipCard_Scene",
  :bag_screen_party  => "PokemonBagPartyPanel",
  :item_find         => "PokemonItemFind_Scene",
  :advanced_items    => "SelectMoveMenu_Scene",
  :misc_scripts_anil => "StarterMenu_Scene",
  :encounter_list_ui => "EncounterList_Scene",
  # Probes the [SV] Summary Screen's optional egg-move learner, the part this reader covers, which not every
  # game with the plugin ships.
  :sv_summary_screen => "EggMoveLearner_Scene",
  # A method probe: the plugin adds no class, only this method on the engine's save scene.
  :multi_save        => "PokemonSave_Scene#pbUpdateSlotInfo",
  :multi_save_v19    => "ScreenChooseFileSave",
  :party_showcase    => "PokemonPartyShowcase_Scene",
  # A method probe: the class is the vanilla summary; the plugin adds the allocation mode.
  :ev_allocator      => "PokemonSummary_Scene#pbEVAllocation",
  :bw_mystery_gift   => "WonderCardAlbumScene",
  :wardrobe          => "Window_Wardrobe",
  :better_summary    => "PokemonSummary_Scene#showAbilityDescription",
  # A method probe: the SV Summary Screen's two panels, which a game can ship without the egg-move learner
  # sv_summary_screen keys on.
  :sv_summary_prompts => "PokemonSummary_Scene#pbAbilityPrompt",
  :hidden_power_type => "Pokemon#hptype",
  # A method probe: Enhanced Pokemon UI adds no class. Soulstones 2's edited copy has no legacy data and turns
  # off every setting read here.
  :enhanced_pokemon_ui => "Pokemon#legacy_data",
  :improved_mementos => "MementoSprite",
  # A method probe: the two Dynamax plugins (ZUD, the Deluxe Battle Kit's) add no class the summary uses,
  # and the level is the one question both ask the Pokemon by the same name.
  :dynamax           => "Pokemon#dynamax_lvl",
  :storage_utilities => "StorageGrabber",
  :pwt               => "AdvancedWorldTournament",
  :advanced_pokedex  => "PokemonPokedexInfo_Scene#displaySubPage",
  :arcky_region_map  => "PokemonRegionMap_Scene#updateSpeciesInfo",
  # The payout-table window, not the scene, which the census would key on a bare "Scene"; written qualified
  # for the runtime gate, which resolves it segment by segment.
  :video_poker       => "VideoPoker::Window_Combination",
  :ekans_snake       => "Ekans_Interface_Main",
  :bw_key_items      => "GetKeyItemScene",
  :luka_title        => "GenOneStyle",
  :modular_title     => "ModularTitleScreen",
  :zud_raid_database => "RaidDataScene",
  :starter_selection => "PokemonStarterSelection",
  :pokemon_achievements => "Pokemon_Achievements_Scene",
  # A method probe: HallOfFameScene is also the stock gen-6 scene; only the BW rework paints a PC card.
  :hall_of_fame_bw_gen6 => "HallOfFameScene#writePokemonDataPC",
  # The v16/v17 script's scene: the v19+ plugin renames it PokemonControls_Scene, and Soulstones 2 ships only an
  # inert override of that one's window. Z and Reminiscencia keep their copies inside =begin/=end.
  :fl_set_controls   => "PokemonControlsScene",
  :punch_bag         => "PunchBagScene",
  :quest_marker      => "Quest_Marker",
  # A top-level function probe: the autosave brings no class of its own.
  :kyu_autosave      => "Object#autosaveAnim",
  # A top-level function probe: the script copies bring no class, and the v20+ plugin's FancyBadges module holds only
  # the names.
  :fancy_badges      => "Object#renderBadgeAnimation",
  # A method probe: the radar adds its methods to the engine's Game_Screen and brings no class of its own.
  :item_radar        => "Game_Screen#aUpdateRadar",
  # A method probe: Relict ships the older 1.1.1, edited (its own visibility rule, an "itemGive" marker), which lacks
  # this method and whose markers mean something else.
  :event_indicators  => "EventIndicator#can_vertical_move?",
  :fl_roulette       => "RouletteScene"
}
