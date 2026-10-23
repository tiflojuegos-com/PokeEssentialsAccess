# Anil's starter menu (plugins/misc_scripts_anil.rb): each redraw says the focused region and its starters; as the
# selection opens, after the caller's message, the title the menu painted comes first and the region queued behind it.

# The game's StarterMenu_Scene, reduced to the calls the menu makes: the build paints its title and redraws the list,
# and the selection redraws it on each move. Defined before the plugin is evaluated again over it (at boot it did not
# exist).
class StarterMenu_Scene
  # The regions the menu offers, each with its starters' ids.
  REGIONS =[["Kanto", [:BULBASAUR, :CHARMANDER, :SQUIRTLE]], ["Johto", [:CHIKORITA, :CYNDAQUIL, :TOTODILE]]]

  def initialize(options = REGIONS, title = "Elige tus Iniciales")
    @options_to_use = options
    @title = title
  end

  def pbStartScene
    @index = 0
    cursor_max_opcion
    pbRedrawList
  end

  def cursor_max_opcion
    @tam_menu = @options_to_use.length
    pbDrawTextPositions(nil, [[@title, 256, 26]])
    :title_drawn
  end

  # The selection loop, reduced to the moves it makes: each one redraws the list.
  def pbSelectElement(moves)
    moves.each do |i|
      @index = i
      pbRedrawList
    end
    @index
  end

  def pbRedrawList; :list_drawn; end
end

misc_scripts_anil = File.join(Harness::ROOT, "plugins", "misc_scripts_anil.rb")
eval(Harness.source(misc_scripts_anil), TOPLEVEL_BINDING, misc_scripts_anil)

class StartersAnilTest < PokeAccessTest
  # The title the menu paints as it builds.
  TITLE = "Elige tus Iniciales"
  # A species row as GameData::Species.get answers it.
  SpeciesRow = Struct.new(:name)

  test "the build's redraw says the focused region and its starters, interrupting" do
    StarterMenu_Scene.new.pbStartScene
    assert_equal [[kanto, true]], SpeakCapture.log
  end

  test "as the selection opens, the painted title interrupts and the region follows it, queued" do
    scene = opened
    scene.pbSelectElement([])
    assert_equal [[TITLE, true], [kanto, false]], SpeakCapture.log
  end

  test "a move in the selection says the new region, interrupting" do
    scene = opened
    scene.pbSelectElement([1])
    assert_equal [[TITLE, true], [kanto, false], [johto, true]], SpeakCapture.log
  end

  test "a redraw on the region just said says nothing" do
    scene = opened
    scene.pbSelectElement([0])
    assert_equal [[TITLE, true], [kanto, false]], SpeakCapture.log
  end

  test "a menu that painted no title opens on the region alone, queued" do
    scene = opened(StarterMenu_Scene::REGIONS, "")
    scene.pbSelectElement([])
    assert_equal [[kanto, false]], SpeakCapture.log
  end

  test "names a region with no starters, or no starter list, by its name alone" do
    [[], nil].each do |starters|
      SpeakCapture.clear
      StarterMenu_Scene.new([["Hoenn", starters]]).pbStartScene
      assert_equal [[PokeAccess::I18n.t(:starter_region_only, :region => "Hoenn"), true]], SpeakCapture.log,
                   "starters #{starters.inspect}"
    end
  end

  test "names each starter by its species where the engine keeps species data" do
    with_species(:BULBASAUR => "Bulbasaur", :CHARMANDER => "Charmander", :SQUIRTLE => "Squirtle") do
      StarterMenu_Scene.new.pbStartScene
    end
    assert_equal [[region("Kanto", "Bulbasaur, Charmander, Squirtle"), true]], SpeakCapture.log
  end

  test "leaves an empty starter slot out" do
    StarterMenu_Scene.new([["Kanto", [:BULBASAUR, nil, :SQUIRTLE]]]).pbStartScene
    assert_equal [[region("Kanto", "BULBASAUR, SQUIRTLE"), true]], SpeakCapture.log
  end

  test "a region whose starters are not a list leaves the menu running" do
    assert_equal :list_drawn, StarterMenu_Scene.new([["Kanto", :BULBASAUR]]).pbStartScene
  end

  test "says nothing for a cursor past the regions" do
    scene = opened
    scene.pbSelectElement([1, 2])
    assert_equal [[TITLE, true], [kanto, false], [johto, true]], SpeakCapture.log, "the move past the last adds nothing"
  end

  test "keeps the menu's own returns" do
    scene = StarterMenu_Scene.new
    assert_equal [:title_drawn, :list_drawn, 1], [scene.cursor_max_opcion, scene.pbStartScene, scene.pbSelectElement([1])]
  end

  private

  # A menu built and its first redraw said, the log cleared, as the caller's message then cuts that read.
  def opened(options = StarterMenu_Scene::REGIONS, title = TITLE)
    scene = StarterMenu_Scene.new(options, title)
    scene.pbStartScene
    SpeakCapture.clear
    scene
  end

  # A region's line, its starters named as the menu lists them (by their ids where the engine has no species data).
  def region(name, mons)
    PokeAccess::I18n.t(:starter_region, :region => name, :mons => mons)
  end

  # Runs the block on an engine that keeps species data, GameData::Species.get naming these ids and raising for any
  # other, as the engine's own does; the gen-6 engine's lack of it is put back after.
  def with_species(names)
    had = Object.const_defined?(:GameData, false) ? Object.send(:remove_const, :GameData) : nil
    Object.const_set(:GameData, Module.new)
    GameData.const_set(:Species, Module.new)
    GameData::Species.define_singleton_method(:get) { |id| SpeciesRow.new(names.fetch(id)) }
    yield
  ensure
    Object.send(:remove_const, :GameData) if Object.const_defined?(:GameData, false)
    Object.const_set(:GameData, had) if had
  end

  def kanto
    region("Kanto", "BULBASAUR, CHARMANDER, SQUIRTLE")
  end

  def johto
    region("Johto", "CHIKORITA, CYNDAQUIL, TOTODILE")
  end
end
