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

# The four pages beyond the first, which every one of the fifteen surveyed games has -- the one that redrew
# its summary as a single page reopened the class and left the old page methods standing, so they are there
# too. The stub used to carry page one alone, which made these four readers untestable and parked their
# names in Hooks.missing, the list that by contract holds only typos.
#
# Asserted against the builders rather than against words, so the spec holds in whatever language is loaded.
Suite.define("summary pages: each page of the summary is read as the player turns to it") do
  s6 = PokeAccess::SummaryGen6
  scene = PokemonSummaryScene.new
  pk = Poke.build(:name => "Chispa", :level => 25)
  scene.pbStartScene([pk], 0)

  want = { 2 => s6.memo_text(pk), 3 => s6.stats_text(pk),
           4 => PokeAccess::Summary.moves_text(pk), 5 => s6.ribbons_text(pk) }
  want.keys.sort.each do |page|
    truthy "page #{page} has something to say at all", !want[page].to_s.strip.empty?
    SpeakCapture.clear
    scene.drawPage(page)
    eq "page #{page} speaks it when the player turns to it", SpeakCapture.lines, [want[page]]
  end

  ghosts = PokeAccess::Hooks.missing.select { |m| m.to_s =~ /drawPage(Two|Three|Four|Five)\z/ }
  eq "and none of the four sits in the typo list", ghosts, []
end
