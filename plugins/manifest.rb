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
  # A method probe: the six-page summary extends the stock gen-6 scene, and only it draws a sixth page.
  :summary_six_pages => "PokemonSummaryScene#drawPageSix",
  :book_scene        => "BookScene",
  :bag_search_entry  => "WindowTextEntryKeyboardPerKey",
  # A method probe on an engine class: the fork adds favourite? to the bag every game has.
  :sky_bag           => "PokemonBag#favourite?",
  :pokegear_themes   => "PokemonPokegearTheme_Scene",
  :hatcher           => "Hatcher",
  :better_region_map => "BetterRegionMap",
  :dp_pausemenu      => "DP_PauseMenu",
  :voltseon_pausemenu => "VoltseonsPauseMenu",
  :modular_pokemon_selection => "ModularSelection_Scene",
  :simple_encounter_list => "EncounterListUI",
  :magic_gachapon    => "GachaScene",
  :slide_banners     => "Scene_Map#addSprite",
  # The DBK readers probe a method the kit adds to a vanilla battle class, which alone would match every game.
  :dbk_battle        => "Battle#pbToggleSpecialActions",
  # Probed by pbGetDisplayEffects, not pbUpdateBattlerInfo: the older 1.1.2 (Soulstones 2) has the same method
  # names with other arities, which this reader must not bind to; every later copy, 2.0.3 included, defines it.
  :dbk_enhanced_ui   => "Battle::Scene#pbGetDisplayEffects",
  # A method probe: Essentials Deluxe adds its midbattle name window to the vanilla battle scene.
  :essentials_deluxe => "Battle::Scene#pbUpdateNameWindow",
  :quest_ui          => "Window_Quest",
  :logros            => "Logros_Scene",
  # A method probe: another game defines an unrelated Questlog class; the method the reader hooks tells them apart.
  :easy_questing     => "Questlog#pbMain",
  :tip_cards         => "TipCard_Scene",
  :bag_screen_party  => "PokemonBagPartyPanel",
  :item_find         => "PokemonItemFind_Scene",
  :hm_catalogue      => "HM_Catalogue",
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
  # A method probe: the summary's IV grade method is Enhanced Pokemon UI's too, its EV bar method only this plugin's
  # (and the Mixed EV System's copy of it).
  :bw_summary        => "PokemonSummary_Scene#pbDisplayEVRating",
  :luka_title        => "GenOneStyle",
  # Luka's Elite Battle System as Uranium and Sevii ship it: its choice boxes, and a method probe on the engine's
  # scene, to which the system adds its ability strip.
  :ebs_ui            => "NewChoiceSel",
  :ebs_scene         => "PokeBattle_Scene#showAbilityMessage",
  # Elite Battle: DX, v19.1 and the v21 port alike, by its target window: ZUD's compatibility patch, which Fire Ash
  # ships without EBDX, reopens the fight, command and databox windows inside a check that never passes there.
  :ebdx              => "TargetWindowEBDX",
  :rotation_battle   => "Battle::Scene#pbCheckRotationInput",
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
  :fl_roulette       => "RouletteScene",
  # A method probe: the watch addon defines it on the Pokegear scene; Anil and Royal ship the addon without
  # registering the plugin, which leaves it undefined there until they do.
  :fl_pokegear_watch => "PokemonPokegear_Scene#initialize_watch",
  # A method probe: Uranium keeps an empty PokemonFamily so old saves load; only the plugin draws the page.
  :fl_family_tree    => "PokemonSummary_Scene#drawPageFamily",
  :fl_wall_clock     => "WallClockScene",
  :easy_unown_text   => "UnownMessage",
  # A method probe: Royal's edited grid menu is a Menu2 too, without the cursor redraw both clean menus have.
  :menu2_pausemenu   => "Menu2#redrawSelector",
  :menu_panels       => "MenuPanel1",
  # Awakening ships this menu as its carriage and replaces its pbStartScene with the fly map, so the list never shows.
  :teleport_menu     => "Teleport_Scene",
  :bloc_unown        => "BlocUnownScene",
  # Royal ships only TDW's patch for this plugin, inside a PluginManager.installed? check it never passes.
  :berry_pots        => "ItemBerryPots_Scene",
  :fl_diploma        => "DiplomaScene",
  # A method probe: Sevii's older script has a DayCareChecker class with no Scene, which a class probe would match.
  :fl_daycare_checker => "DayCareChecker::Scene#assign_pokemon_text",
  :fl_character_selection => "CharacterSelection",
  :fl_character_selection_v1 => "CharacterSelectionScene",
  :fl_type_quiz      => "TypeQuiz",
  # The script's own module, which Royal ships (its copy lost the Bridge module; the API is the same).
  :fl_tilt_labyrinth => "TiltLabyrinth",
  :fl_ball_catch     => "BallCatch",
  :fl_tetra          => "PokeTetra",
  # A method probe: other games define an unrelated TrainerCard; only this script's card has a front and a back.
  :bes_trainer_card  => "TrainerCard#dorso1",
  :character_profiles => "CharacterPageDisplayScene",
  :alt_mystery_gift  => "MysteryGiftScene",
  # A method probe, the waiting line the reader dedups: Sevii's v16 script and Anil's edited copy both have it.
  :cable_club        => "CableClub_Scene#pbDisplayDots",
  # Top-level function probes: the two scripts bring no class of their own.
  :bes_blackjack     => "Object#pbBlackJack",
  :bes_piano         => "Object#pbPiano",
  # ZUD's raid dens and Max Lair, beside its database: Fire Ash ships both unreached, Golden Crown reaches them.
  :zud_raid_dens     => "MaxRaidScene",
  :zud_max_lair      => "LairMapScene",
  # The script's module: its ContestHall::Show would count under the last segment, which another game's class shares.
  :contest_hall      => "ContestHall",
  :pokesearch        => "PokeSearch_Scene",
  :modular_menu      => "ModularMenu",
  :boons_phenomena   => "Phenomenon"
}
