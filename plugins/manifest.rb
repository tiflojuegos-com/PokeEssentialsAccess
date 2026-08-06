# Readers for THIRD-PARTY plugins: screens a fangame installs, not screens Essentials ships. They are not
# core (the core is what any Essentials game has) and they are not one game's own (the same plugin, with the
# same classes, turns up in several fangames), so they live here and each PROFILE declares which ones it
# loads, in its own manifest.rb as {:modules => [...], :plugins => [...]}.
#
# Declaring rather than auto-loading is deliberate: two games can ship the same plugin CLASS with different
# internals, so a reader must only run where somebody checked that it fits. Every reader here was written
# against BOTH copies of its plugin, and each file's header records where they diverge -- that is the
# working record of the check, and the reason a few of them ask the scene what it has instead of assuming.
#
# This file is BOTH the file list and a detection table: name => the class whose presence gives the plugin
# away. It is tiny and always read, even when no reader is loaded, so the diagnostic can tell the player
# "this game has a plugin we know about and this profile never declared it" -- which turns the one weak
# spot of declaring by hand (forgetting) into something visible in any recording, including on games we
# have no script dump for.
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
  :berrydex          => "Window_Berrydex",
  :secret_bases      => "Window_BasePocketsList",
  :regicode          => "RC",
  :rse_starters      => "RSESTarterChoice",
  :hgss_dexlist      => "PokedexListSprite",
  :music_book        => "Window_MusicBook",
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
  :ekans_snake       => "Ekans_Interface_Main"
}
