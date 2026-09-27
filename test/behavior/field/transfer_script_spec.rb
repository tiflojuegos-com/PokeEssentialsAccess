# The script-transfer registry under the gen-6 stubs (cases in transfer_script_cases.rb), plus two gen-6-only suites:
# Reminiscencia's door pattern and the summary pages.
require File.expand_path("transfer_script_cases", File.dirname(__FILE__))
define_transfer_script_suites

# Reminiscencia's constants.rb (this repo's own file, evaluated as is) declares its getToDungeon(<map>) pattern, so
# the sprite-less tile becomes an exit, named and pinged as a door; everything the file touches is restored.
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

# Summary pages two to five are each read as the player turns to them, and none of their hooks sits in Hooks.missing,
# the typo list.
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
