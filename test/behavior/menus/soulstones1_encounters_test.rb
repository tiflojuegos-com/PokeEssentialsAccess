# Soulstones' encounter list (games/soulstones1/encounter_list.rb): each encounter type's page as getEncData fills it,
# headed "map: type", its species by name, its place among the types, and the lone 7 of an area without encounters.

# Soulstones' encounter window: getEncData fills @encarray2 with the species of the encounter type the page shows
# (@type[@index]).
class EncounterListUI_withforms
  def initialize(list, types, index); @list = list; @type = types; @index = index; end
  def getEncData; @encarray2 = @list; :filled; end
end

# The profile file, evaluated over the window above under the game's name; the profile's name is taken back after.
encounters_profiles = PokeAccess::Game.profiles.dup
begin
  encounters_path = File.join(Harness::ROOT, "games", "soulstones1", "encounter_list.rb")
  eval(Harness.source(encounters_path), TOPLEVEL_BINDING, encounters_path)
ensure
  PokeAccess::Game.profiles.replace(encounters_profiles)
end

class Soulstones1EncountersTest < PokeAccessTest
  Encounters = PokeAccess::Soulstones1Encounters

  test "reads a page as getEncData fills it, every species by its name, interrupting" do
    assert_equal :filled, on_route { window([16, 19], [2], 0).getEncData }, "the window fills as it would"
    assert_equal [["#{type_line('Ruta 1: Water', 2)}: #{species(16)}, #{species(19)}", true]], SpeakCapture.log
  end

  test "heads a page whose encounter type has no name with the map alone" do
    { [1] => "a blank name", [5] => "none" }.each do |types, what|
      on_route { assert_equal "Ruta 1", Encounters.header(window([16], types, 0)), what }
    end
  end

  test "at brief, says the species without their count, while the info key keeps the whole page" do
    PokeAccess::Config.verbosity = :brief
    on_route { window([16, 19], [2], 0).getEncData }
    assert_equal [["Ruta 1: Water: #{species(16)}, #{species(19)}", true]], SpeakCapture.log
    assert_equal "#{type_line('Ruta 1: Water', 2)}: #{species(16)}, #{species(19)}", PokeAccess::Info.info_text
  end

  test "says the page's place among the area's types after its species" do
    on_route { window([16], [0, 2], 1).getEncData }
    assert_equal [["#{type_line('Ruta 1: Water', 1)}: #{species(16)}, #{place(2, 2)}", true]], SpeakCapture.log
  end

  test "keeps the page's place for the info key while brief leaves it out of the line" do
    PokeAccess::Config.verbosity = :brief
    on_route { window([16], [0, 2], 1).getEncData }
    assert_equal [["Ruta 1: Water: #{species(16)}", true]], SpeakCapture.log
    assert_equal "#{type_line('Ruta 1: Water', 1)}: #{species(16)}, #{place(2, 2)}", PokeAccess::Info.info_text
  end

  test "numbers a page among the area's types, and gives a lone type or none no place" do
    pages = { [[0, 2], 0] => place(1, 2), [[0, 1, 2], 2] => place(3, 3), [[2], 0] => nil, [nil, 0] => nil }
    pages.each do |(types, i), want|
      got = Encounters.page(window([16], types, i))
      want ? assert_equal(want, got, "types #{types.inspect} at #{i}") : assert_nil(got, "types #{types.inspect}")
    end
  end

  test "says the area has none for the screen's lone 7, an empty list or no list" do
    [[7], [], nil].each do |list|
      SpeakCapture.clear
      on_route { window(list, [], 0).getEncData }
      assert_equal [[PokeAccess::I18n.t(:enc_none, :loc => "Ruta 1"), true]], SpeakCapture.log, "for #{list.inspect}"
    end
  end

  test "says a form-aware id by its base species' name" do
    with_form_ids { on_route { window([2025], [2], 0).getEncData } }
    assert_equal [["#{type_line('Ruta 1: Water', 1)}: #{species(25)}", true]], SpeakCapture.log
  end

  test "a species the list marks with no status is its name at any level, while a status still says itself" do
    PokeAccess::Config.verbosity = :brief
    list = PokeAccess::EncounterList
    assert_equal "Pidgey", list.phrase("Pidgey", nil), "the name alone"
    assert_equal "Pidgey", list.phrase("Pidgey", nil, true), "and for the info key"
    assert_equal "Pidgey #{PokeAccess::I18n.t(:dex_seen)}", list.phrase("Pidgey", :dex_seen, true), "a status"
  end

  private

  # An encounter window that fills a page with its species ids, the area's encounter types and the one it shows.
  def window(list, types, index)
    EncounterListUI_withforms.new(list, types, index)
  end

  # The block's value on a map called "Ruta 1" whose engine names the encounter types Land and Water, and leaves the
  # second blank.
  def on_route
    held = Object.const_defined?(:EncounterTypes) ? Object.const_get(:EncounterTypes) : nil
    Object.send(:remove_const, :EncounterTypes) if held
    Object.const_set(:EncounterTypes, Module.new)
    EncounterTypes.const_set(:Names, ["Land", "", "Water"])
    $game_map.define_singleton_method(:name) { "Ruta 1" }
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :name) if $game_map.singleton_methods.include?(:name)
    Object.send(:remove_const, :EncounterTypes) if Object.const_defined?(:EncounterTypes)
    Object.const_set(:EncounterTypes, held) if held
  end

  # Runs the block with the engine's pbGetSpeciesFromFSpecies, which splits a form id (form * 1000 + species), and puts
  # back after it whatever stood under that name.
  def with_form_ids(&block)
    GameFunctions.with({ :pbGetSpeciesFromFSpecies => lambda { |fs| [fs % 1000, fs / 1000] } }, &block)
  end

  # A species' name as the engine's data gives it.
  def species(id)
    PokeAccess::Data.species_name(id)
  end

  # The header of a page of n species.
  def type_line(head, n)
    PokeAccess::I18n.t(:enc_type, :type => head, :n => n)
  end

  # A page's place among the area's types.
  def place(n, m)
    PokeAccess::I18n.t(:adv_dex_page, :n => n, :m => m)
  end
end
