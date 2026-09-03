# The script-transfer registry under the gen-6 stubs; the shared cases live in transfer_script_cases.rb.
# Below, the two things that are gen-6 only: Reminiscencia's profile really declaring its door pattern, and
# the summary-page gate (both screens are gen-6 shapes).
require File.expand_path("transfer_script_cases", File.dirname(__FILE__))
define_transfer_script_suites

# The dungeon doors of Reminiscencia are sprite-less touch tiles whose only command is getToDungeon(<map>),
# so before the profile declared that pattern they were not exits, not pathfinder targets and, having no
# sprite to fall back on, not even a sonar ping: one verdict feeds all three. Driven through the REAL
# constants.rb, because the wiring is the thing that was missing, not the pattern's shape. Everything that
# file touches is restored, the pattern list included: leaked, it would rewrite what counts as a door for
# every suite after this one.
Suite.define("reminiscencia: a getToDungeon tile is an exit, is named, and pings as a door") do
  loc = PokeAccess::Locator
  patterns = TransferCases.snapshot
  parts = [PokeAccess::Config.trainer_parts.dup, PokeAccess::Info::TRAINER_PARTS.dup, PokeAccess::Config.money_label]
  tables = [PokeAccess::Config.status_names.dup, PokeAccess::Config.field_weather_names.dup]
  begin
    ev = TransferCases.script_tile("getToDungeon(319)")
    falsy "before the profile loads, the door is invisible to the locator", loc.transfer_event?(ev)
    eq "and to the soundscape", PokeAccess::Audio3D.type_of(ev), nil

    path = File.join(Harness::ROOT, "games", "reminiscencia", "constants.rb")
    # eval is the harness's own loading mechanism (test/support/harness.rb): this repo's file, by absolute path.
    eval(File.read(path), TOPLEVEL_BINDING, path)
    PokeAccess::Locator.clear_verdicts

    truthy "the profile declared a pattern", loc::TRANSFER_SCRIPTS.length > patterns.length
    eq "which reads the destination map out of the call", loc.transfer_script_dest(ev), 319
    truthy "so the tile is an exit", loc.transfer_event?(ev)
    truthy "the locator keys reach it in their starting category", loc.in_category?(ev, :all)
    match "it is spoken as an exit, not by its editor note size(3,1)", loc.target_name(ev).to_s, /salida/i
    eq "and the soundscape gives it the door channel", PokeAccess::Audio3D.type_of(ev), :door
  ensure
    TransferCases.restore(patterns)
    World.clear_events
    PokeAccess::Config.trainer_parts = parts[0]
    PokeAccess::Info::TRAINER_PARTS.clear; PokeAccess::Info::TRAINER_PARTS.merge!(parts[1])
    PokeAccess::Config.money_label = parts[2]
    PokeAccess::Config.status_names.clear; PokeAccess::Config.status_names.merge!(tables[0])
    PokeAccess::Config.field_weather_names.clear; PokeAccess::Config.field_weather_names.merge!(tables[1])
  end
end

# Hooks.missing is, by contract, the list of TYPOS. Reminiscencia replaced the summary with a single page, so
# pages two to five legitimately do not exist there and four permanent entries sat in that list on every
# session -- which is how a real typo stops being noticed. The gate asks the game, and only skips the whole
# set: a game carrying SOME of the pages keeps them all registered, so a name we got wrong still reports.
Suite.define("summary pages: the multi-page hooks are skipped only where the game has no multi-page summary") do
  s6 = PokeAccess::SummaryGen6
  made = []
  begin
    single = Class.new { def drawPageOne(pk = nil); end }
    Object.const_set(:PaTestSinglePage, single); made.push(:PaTestSinglePage)
    falsy "a summary with only page one is not multi-page", s6.multipage?("PaTestSinglePage")

    partial = Class.new { def drawPageOne(pk = nil); end; def drawPageThree(pk = nil); end }
    Object.const_set(:PaTestPartialPages, partial); made.push(:PaTestPartialPages)
    truthy "one sibling present means the game HAS the api, so the whole set stays registered", s6.multipage?("PaTestPartialPages")

    falsy "a class that does not exist is not multi-page either", s6.multipage?("PaTestNoSuchScene")
    falsy "and neither is the empty name an off-era scene resolves to", s6.multipage?("")

    ghosts = PokeAccess::Hooks.missing.select { |m| m.to_s =~ /drawPage(Two|Three|Four|Five)\z/ }
    eq "so none of the four sits in the typo list under this game's summary", ghosts, []
  ensure
    made.each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
  end
end
