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
  :quest_ui          => "Window_Quest"
}
