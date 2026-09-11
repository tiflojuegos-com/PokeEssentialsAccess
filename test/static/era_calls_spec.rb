# A method of ONE engine era, called from code that runs in both. Shared core asks the game for things under
# `rescue`, so such a call never fails: it answers nil in the other era, for ever, and the reader built on it
# is silent there without a trace. The spin-tile reader asked $game_player.pbTerrainTag, a modern method,
# and the two games with spin tiles are gen-6: it never named a direction anywhere.
#
# test/static/era_census.txt lists every pb-prefixed API name the shared core calls that some surveyed source
# lacks (regenerate with build_era_census.rb; the dumps live outside the repo, which is why the census is
# committed instead of scanned live). Each of those names is either a ladder to the other era's spelling, a
# guard, or a deliberate choice -- and a deliberate one is written here with its reason. A name that stops
# being partial has to leave this table too, so the reasons never outlive the calls they explain.
Suite.define("static: every shared-core call to an API only some games define is a ladder, a guard or explained") do
  path = File.join(File.dirname(__FILE__), "era_census.txt")
  head = File.read(path).split("\n").select { |l| l =~ /\A#/ }.join(" ")
  total = head[/names called from shared core: (\d+)/, 1].to_i
  truthy "the era census saw a realistic number of API names (#{total})", total > 30
  truthy "and was built from all sixteen sources", head =~ /surveyed sources \(16\)/

  rows = {}
  PokeAccess::KVFile.each(path) { |k, v| rows[k] = v }

  KNOWN = {
    # Ladders: the gen-6 spelling is tried and the modern one follows (or the other way round).
    "pbIsImportantItem?" => "gen-6 bag predicate; GameData::Item#is_important? follows (menus.rb bag_hides_qty?)",
    "pbIsRegistered?" => "one of the five registration shapes bag_registered? tries, after the modern registered?",
    "pbIsMachine?" => "gen-6 branch of machine_move; GameData::Item#move follows (contextual.rb)",
    "pbQuantity" => "gen-6 bag count; bag.quantity follows (ready_menu.rb item_quantity)",
    "pbLoadMapInfos" => "tried through respond_to?; pbLoadRxData is the other rung (locator_naming.rb)",
    "pbLoadRxData" => "the modern rung of the same ladder",
    "pbSideSize" => "the modern answer to doubles?; gen-6's doublebattle flag is the other rung (battle.rb)",
    # Guards: asked only where the game has it, and its absence is the right answer there.
    "pbCanRegisterItem?" => "the games without it draw no registrable mark either (menus.rb bag_registrable?)",
    "pbGetMetadata" => "behind defined?(pbGetMetadata); the modern era answers through GameData::PlayerMetadata",
    # Optional wraps of globals that only some games ship: wrap_global binds nothing where the name is absent.
    "pbDisplayText" => "HUD writer only Infinite Fusion ships, wrapped by name (hud_text.rb)",
    "pbClearText" => "the same HUD's repaint boundary, wrapped by name (hud_text.rb)",
    "pbShowCommandsRogue" => "Reminiscencia's rogue-mode command menu with help (0500 Messages.rb:877), wrapped by name (command_help.rb)",
    "pbShowCommandsWithHelpAndText" => "the ability changer of Pokémon Z (244_Cambia Habilidades.rb:59) and Añil's top-level shim over MessageUI (001_001_AbilityChanger.rb:223), wrapped by name (command_help.rb)",
    "pbDisplayBattlePointsWindow" => "money-window variant wrapped where it exists (money_window.rb)",
    "pbDisplayBattleFactoryPointsWindow" => "money-window variant wrapped where it exists (money_window.rb)",
    "pbDisplayHeartScalesWindow" => "money-window variant wrapped where it exists (money_window.rb)",
    "pbDisplayQuestPointsWindow" => "money-window variant wrapped where it exists (money_window.rb)",
    "pbDisplayAchievementPointsWindow" => "money-window variant wrapped where it exists (money_window.rb)",
    # Defined by all fifteen fangames and missing only from the stock v21.1 tree, which reworked those
    # screens (pbHeldPokemon became held_pokemon). No surveyed game is on that version; the rung is added
    # when one appears, and this row is what will say so.
    "pbGetHealingSpot" => "all fifteen games; the stock tree dropped the name (town_map.rb healing_spot)",
    "pbGetMapDetails" => "all fifteen games; the stock tree dropped the name (region_map.rb)",
    "pbHeldPokemon" => "all fifteen games; the stock tree calls it held_pokemon (party_storage.rb)",
    # Not calls at all: patterns matched against event-script text to classify an event.
    "pbHealAll" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbHealParty" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbNurseHeal" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbPokemonPC" => "script-text pattern for a PC event (locator_naming.rb)",
    "pbEventItem" => "script-text pattern for an item event (locator_naming.rb)"
  }

  unexplained = rows.keys.reject { |k| KNOWN.has_key?(k) }.sort.map { |k| "#{k} (#{rows[k]})" }
  eq "every partially defined API name the shared core calls is explained", unexplained, []

  stale = KNOWN.keys.reject { |k| rows.has_key?(k) }.sort
  eq "and no explanation outlives the call it explains", stale, []
end
