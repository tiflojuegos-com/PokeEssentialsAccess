# Soulstones' encounter list (games/soulstones1/encounter_list.rb): each encounter-type page read after getEncData,
# headed "map: type" as painted, every species by name as its colour icon shows it, the page's place among the types
# its arrows show, and the lone 7 the screen keeps for an area without encounters. The profile's module alone is
# loaded: its hook belongs to the Soulstones process.
unless defined?(PokeAccess::Soulstones1Encounters)
  path = File.join(Harness::ROOT, "games", "soulstones1", "encounter_list.rb")
  eval(File.read(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)
end

module Soulstones1EncountersSpec
  # Runs the block with the engine's encounter type names and a map called "Ruta 1", both put back afterwards.
  def self.world
    old_map = $game_map
    had_types = Object.const_defined?(:EncounterTypes)
    Object.const_set(:EncounterTypes, Module.new) unless had_types
    EncounterTypes.const_set(:Names, ["Land", "Cave", "Water"]) unless EncounterTypes.const_defined?(:Names)
    $game_map = Struct.new(:name).new("Ruta 1")
    yield
  ensure
    $game_map = old_map
    Object.send(:remove_const, :EncounterTypes) unless had_types
  end
end

Suite.define("soulstones1 encounters: a page says its map, type and every species by name; an empty area says so") do
  enc = PokeAccess::Soulstones1Encounters
  t = PokeAccess::I18n
  Soulstones1EncountersSpec.world do
    head = "Ruta 1: #{[EncounterTypes::Names].flatten[2]}"
    scene = World.stub_scene(:@encarray2 => [16, 19], :@type => [2], :@index => 0)
    eq "the header is the map and the page's encounter type, as painted", enc.header(scene), head

    names = [PokeAccess::Data.species_name(16), PokeAccess::Data.species_name(19)]
    SpeakCapture.clear
    enc.read(scene)
    eq "each species by its name, as its colour icon shows it, with no Pokedex state the page does not paint",
       SpeakCapture.last, "#{t.t(:enc_type, :type => head, :n => 2)}: #{names.join(', ')}"
    [:dex_unknown, :dex_seen, :dex_caught].each do |k|
      falsy "no species is said as #{t.t(k)}", SpeakCapture.last.include?(t.t(k))
    end

    SpeakCapture.clear
    enc.read(World.stub_scene(:@encarray2 => [7], :@type => [], :@index => 0))
    eq "the no-encounters sentinel says the area has none", SpeakCapture.last, t.t(:enc_none, :loc => "Ruta 1")
  end
end

Suite.define("soulstones1 encounters: a page of several says its place among them, as its arrows show") do
  enc = PokeAccess::Soulstones1Encounters
  t = PokeAccess::I18n
  Soulstones1EncountersSpec.world do
    scene = World.stub_scene(:@encarray2 => [16], :@type => [0, 2], :@index => 1)
    pos = t.t(:adv_dex_page, :n => 2, :m => 2)
    eq "the second of two types", enc.page(scene), pos
    SpeakCapture.clear
    enc.read(scene)
    truthy "said after the species", SpeakCapture.last.end_with?(", #{pos}")
    truthy "and kept whole for the info key", PokeAccess::Info.info_text.to_s.end_with?(", #{pos}")

    PokeAccess::Config.verbosity = :brief
    SpeakCapture.clear
    enc.read(scene)
    falsy "brief leaves the place out, a page being a position", SpeakCapture.last.include?(pos)
    PokeAccess::Config.verbosity = :full

    falsy "a lone type has no arrows and no place", enc.page(World.stub_scene(:@type => [0], :@index => 0))
  end
end

Suite.define("soulstones1 encounters: a form-aware id is named by its base species") do
  enc = PokeAccess::Soulstones1Encounters
  had = Object.method_defined?(:pbGetSpeciesFromFSpecies) || Object.private_method_defined?(:pbGetSpeciesFromFSpecies)
  unless had
    eq "without the engine's converter the id is the species", enc.species_of(25), 25
    Object.send(:define_method, :pbGetSpeciesFromFSpecies) { |fs| [fs % 1000, fs / 1000] }
    begin
      eq "with it, the base species of a form id", enc.species_of(2025), 25
    ensure
      Object.send(:remove_method, :pbGetSpeciesFromFSpecies)
    end
  end
end

Suite.define("encounter list: a species with no status is its name, at any level") do
  el = PokeAccess::EncounterList
  eq "the name alone at full", el.phrase("Pidgey", nil), "Pidgey"
  eq "and for the info key", el.phrase("Pidgey", nil, true), "Pidgey"
  eq "a status still says itself", el.phrase("Pidgey", :dex_seen, true), "Pidgey #{PokeAccess::I18n.t(:dex_seen)}"
end
