# Every pb-prefixed API name shared core calls that some surveyed source lacks (era_census.txt) is a ladder to the
# other era's spelling, a guard, or explained in KNOWN; a name that stops being partial leaves KNOWN too.
Suite.define("static: every shared-core call to an API only some games define is a ladder, a guard or explained") do
  path = File.join(File.dirname(__FILE__), "era_census.txt")
  head = File.read(path).split("\n").select { |l| l =~ /\A#/ }.join(" ")
  total = head[/names called from shared core: (\d+)/, 1].to_i
  truthy "the era census saw a realistic number of API names (#{total})", total > 30
  truthy "and was built from all twenty-two sources", head =~ /surveyed sources \(22\)/

  rows = {}
  PokeAccess::KVFile.each(path) { |k, v| rows[k] = v }

  KNOWN = {
    # Ladders: the gen-6 spelling is tried and the modern one follows (or the other way round).
    "pbIsImportantItem?" => "gen-6 bag predicate; GameData::Item#is_important? follows (menus.rb bag_hides_qty?)",
    "pbIsRegistered?" => "one of the five registration shapes bag_registered? tries, after the modern registered?",
    "pbIsMachine?" => "gen-6 branch of machine_move; GameData::Item#move follows (contextual.rb)",
    "pbQuantity" => "gen-6 bag count, asked where the bag has no modern quantity (engine.rb bag_quantity)",
    "pbLoadMapInfos" => "tried through respond_to?; pbLoadRxData is the other rung (locator_naming.rb)",
    "pbLoadRxData" => "the modern rung of the same ladder",
    "pbSideSize" => "the modern answer to doubles?; gen-6's doublebattle flag is the other rung (battle.rb)",
    "pbGetMonthName" => "the full month name where the game has one; pbGetAbbrevMonthName is the rung every game has (player.rb start_date_text)",
    "pbGetStartExperience" => "gen-6's PBExperience table, asked only where the Pokemon has no growth_rate object (summary.rb exp_to_next)",
    "pbDirectOpposing" => "reached only for the two named v20+ function codes, which gen-6's numeric codes never match, and rescued (move_info.rb target_category)",
    "pbTypes" => "the modern battler's types in battle; gen-6's type1/type2 is the other rung (battle.rb shown_types)",
    # Guards: asked only where the game has it, and its absence is the right answer there.
    "pbCanRegisterItem?" => "the games without it draw no registrable mark either (menus.rb bag_registrable?)",
    "pbGetMetadata" => "behind defined?(pbGetMetadata); the modern era answers through GameData::PlayerMetadata",
    "pbBallTypeToBall" => "the gen-6 ball number turned into its item, asked only for a Pokemon with no poke_ball, which every game without it has (summary.rb ball_name)",
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
    # In every fangame but not the stock v21.1 tree, which reworked those screens and no surveyed game runs.
    "pbGetHealingSpot" => "all fifteen games; the stock tree dropped the name (town_map.rb healing_spot)",
    "pbGetMapDetails" => "all fifteen games; the stock tree dropped the name (region_map.rb)",
    "pbHeldPokemon" => "all fifteen games; the stock tree calls it held_pokemon (party_storage.rb)",
    # The summary's own inner loops, hooked :optional so a game without one binds nothing.
    "pbMoveSelection" => "the summary's move cursor, in every fangame; the stock tree reworked it (summary.rb forget_page)",
    "pbRibbonSelection" => "the ribbon grid, in the games that have one (summary.rb forget_page)",
    "pbCheckMove" => "gen-6's own finder of a party member knowing a move, behind respond_to?; v19+ get_pokemon_with_move is the rung before it (field_moves.rb knows?)",
    # Not calls at all: patterns matched against event-script text to classify an event.
    "pbHealAll" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbHealParty" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbNurseHeal" => "script-text pattern for a healing event (locator_naming.rb)",
    "pbPokemonPC" => "script-text pattern for a PC event (locator_naming.rb)",
    "pbEventItem" => "script-text pattern for an item event (locator_naming.rb)",
    "pbCallBub" => "script-text pattern for a page that talks (event_pages.rb TALK_SCRIPT)",
    "pbHasItem" => "script-text pattern for a bag condition an event page asks, as $PokemonBag.pbHasItem? (event_pages.rb)",
    "pbMoverEstatuas" => "script-text pattern for a statue an event pushes (route_gates.rb PUSH_SCRIPTS)",
    "pbBridgeOn" => "script-text pattern for the height a bridge ramp's page sets (event_pages.rb ramp)",
    "pbBridgeOff" => "script-text pattern for a bridge ramp's page that lowers it (event_pages.rb ramp)",
    # Absent from Reborn alone, which has no Bug Catching Contest and no Triple Triad.
    "pbBugContestState" => "the contest status for the field key, rescued where the game has no contest (battle.rb field_event_text)",
    "pbBuyTriads" => "the Triple Triad card shop, wrapped by name where the minigame exists (minigame_text.rb)",
    "pbSellTriads" => "the same shop's selling half, wrapped by name (minigame_text.rb)"
  }

  unexplained = rows.keys.reject { |k| KNOWN.has_key?(k) }.sort.map { |k| "#{k} (#{rows[k]})" }
  eq "every partially defined API name the shared core calls is explained", unexplained, []

  stale = KNOWN.keys.reject { |k| rows.has_key?(k) }.sort
  eq "and no explanation outlives the call it explains", stale, []
end
