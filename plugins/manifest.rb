# Readers for THIRD-PARTY plugins: screens a fangame installs, not screens Essentials ships. Each PROFILE
# declares which ones it loads in its own manifest.rb ({:modules => [...], :plugins => [...]}), because two
# games can ship the same plugin CLASS with different internals; every reader here was written against BOTH
# copies of its plugin and its header records where they diverge. This file is also a detection table
# (name => the class whose presence gives the plugin away), always read even when no reader is loaded, so
# the diagnostic can report a known plugin the profile never declared.
#
# Adding a plugin: one file here, one line in this table, and the name in each profile that ships it.
{
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
  :summary_habilidades => "PokemonSummaryScene#Habilidades",
  :book_scene        => "BookScene",
  :bag_search_entry  => "WindowTextEntryKeyboardPerKey",
  # A METHOD probe on an engine class: the fork adds favourite? to the bag every game has.
  :sky_bag           => "PokemonBag#favourite?",
  :pokegear_themes   => "PokemonPokegearTheme_Scene",
  :hatcher           => "Hatcher",
  :better_region_map => "BetterRegionMap",
  :dp_pausemenu      => "DP_PauseMenu",
  :voltseon_pausemenu => "VoltseonsPauseMenu",
  :simple_encounter_list => "EncounterListUI",
  :magic_gachapon    => "GachaScene",
  :slide_banners     => "Scene_Map#addSprite",
  # The DBK files hook vanilla battle classes with :optional gates, so each probes the METHOD the kit
  # adds there -- the class alone would match every modern game.
  :dbk_battle        => "Battle#pbToggleSpecialActions",
  # The probe is pbGetFinalModifiers and NOT pbUpdateBattlerInfo, which both releases of Enhanced UI
  # have. The reader is written against the current one; an older release (v1.1.2 for v20.1, which
  # Soulstones 2 ships) keeps the same class and method names but renames the toggles and changes the
  # arities, so the reader binds perfectly and never fires. Detecting by the shared name made the
  # diagnostic report a screen as covered that says nothing.
  :dbk_enhanced_ui   => "Battle::Scene#pbGetFinalModifiers",
  :quest_ui          => "Window_Quest",
  :logros            => "Logros_Scene",
  # A METHOD probe, and it has to be: one more game defines a class called Questlog for a quest system of
  # its own, rewritten from scratch, sharing nothing with this plugin but the name. Probing the bare class
  # made the census record that game as shipping the plugin, the declaration check then REQUIRED it to
  # declare a reader that can bind to none of its methods, and the diagnostic reported the screen as
  # covered. The method the reader actually hooks is what tells the two apart.
  :easy_questing     => "Questlog#pbMain",
  :tip_cards         => "TipCard_Scene",
  :bag_screen_party  => "PokemonBagPartyPanel",
  :item_find         => "PokemonItemFind_Scene",
  :advanced_items    => "SelectMoveMenu_Scene",
  :misc_scripts_anil => "StarterMenu_Scene",
  :encounter_list_ui => "EncounterList_Scene",
  # Named for the plugin but probing one of its optional files: two games ship [SV] Summary Screen and only
  # one of them includes the egg-move learner, which is the part this reader covers. The probe matches what
  # is read, not what is installed -- so a game with the plugin but without that file correctly does not
  # declare this reader.
  :sv_summary_screen => "EggMoveLearner_Scene",
  # A METHOD probe, not a class: this plugin ships under two names and adds no class of its own -- it
  # reopens the engine's save scene. The method it adds there is what gives it away.
  :multi_save        => "PokemonSave_Scene#pbUpdateSlotInfo",
  :party_showcase    => "PokemonPartyShowcase_Scene",
  # A METHOD probe: the class is the vanilla summary, which every game of the era has. What only this
  # plugin adds is the allocation mode.
  :ev_allocator      => "PokemonSummary_Scene#pbEVAllocation",
  :bw_mystery_gift   => "WonderCardAlbumScene",
  :wardrobe          => "Window_Wardrobe",
  :better_summary    => "PokemonSummary_Scene#showAbilityDescription",
  :arcky_region_map  => "PokemonRegionMap_Scene#updateSpeciesInfo",
  # The payout-table window rather than the scene: the census indexes a class by its LAST namespace segment,
  # so the scene would key on the bare "Scene" -- a name three of the surveyed games define for something
  # else entirely. Written qualified because BOTH readers of this table need it that way: the census still
  # keys it on Window_Combination, and the runtime gate resolves it segment by segment, which the bare name
  # cannot do for a class that lives inside a module.
  :video_poker       => "VideoPoker::Window_Combination",
  :ekans_snake       => "Ekans_Interface_Main",
  :bw_key_items      => "GetKeyItemScene",
  :luka_title        => "GenOneStyle",
  :modular_title     => "ModularTitleScreen"
}
