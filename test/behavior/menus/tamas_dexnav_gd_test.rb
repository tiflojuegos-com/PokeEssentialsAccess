# Tamas's DexNav (plugins/tamas_dexnav.rb): the species screen as it paints it, and the search on the map, whose grass and
# overlay show only by sight.

# The column's labels, as the plugin's table holds them.
module Constant
  TEXTS_SMALL = { :Level => { :text => "Search Level" }, :Method => { :text => "Method" },
                  :Ability => { :text => "Abilities" }, :Item => { :text => "Item" } }.freeze
end

# The screen: updateInfoBox paints what the test hands it.
class PokemonDexNav_Scene
  attr_accessor :rows

  def initialize(state, rows)
    state.each { |k, v| instance_variable_set("@#{k}", v) }
    @rows = rows
  end

  def updateInfoBox
    pbDrawTextPositions(nil, @rows)
    :painted
  end

  def pbEndScene; end
end

# The overlay's module, and the search's functions as the plugin defines them.
module MyOverlayModule
  def self.pbShowMyOverlay(_info, _viewport = nil); end
end

class DexNavSearchState
  attr_accessor :coords, :finds, :active
  def is_active?; @active; end
end

$tamas_dexnav_state = DexNavSearchState.new

def safeAccessDexNav
  $tamas_dexnav_state
end

def showGrassShaking(_x, _y, _first, _is_grass); end

def pbDexNavSearchEvent
  MyOverlayModule.pbShowMyOverlay($tamas_dexnav_state.finds) if $tamas_dexnav_state.finds
  :searched
end

begin
  path = File.join(Harness::ROOT, "plugins", "tamas_dexnav.rb")
  src = Harness.source(path)
  hooks = src.index('PokeAccess::Hooks.around_hook("PokemonDexNav_Scene"')
  eval(src[hooks..-1], TOPLEVEL_BINDING, path, src[0, hooks].count("\n") + 1)
end

class TamasDexnavGdTest < PokeAccessTest
  HEAD = [["DexNav", 4, 8], ["Land", 12, 220], ["Water - Action to change", 12, 44]].freeze
  WATER = [["DexNav", 4, 8], ["Water", 12, 44], ["Land - Action to change", 12, 220]].freeze
  LABELS = [["Search Level", 347, 96], ["Method", 347, 156], ["Abilities", 347, 215], ["Item", 347, 274],
            ["Chain: 2", 380, 8]].freeze
  # What the column paints for a species owned: name, method, level, ability, and two items with their chances.
  OWNED = [["Oddish", 424, 40], ["Walk", 347, 187], ["3", 347, 128], ["Use Ability Vial", 347, 243], ["Oranberry", 347, 302],
           ["50%", 501, 302], ["Rawstberry", 347, 327], ["5%", 501, 327]].freeze
  # And for one not seen yet: only marks, but for the level and the ability's line.
  UNSEEN = [["???", 424, 40], ["---", 347, 187], ["0", 347, 128], ["Use Ability Vial", 347, 243], ["---", 347, 302]].freeze
  Pokedex = Struct.new(:seen) do
    def seen?(_s); seen; end
  end
  Trainer = Struct.new(:pokedex)
  Info = Struct.new(:get_pkmn, :get_ability, :get_move, :overlay_item, :get_item, :get_ivs)
  Pkmn = Struct.new(:name)

  def setup
    super
    @player_was = $player
    $player = Trainer.new(Pokedex.new(true))
    $game_player.x = 10
    $game_player.y = 10
    $tamas_dexnav_state.coords = []
    $tamas_dexnav_state.finds = nil
    $tamas_dexnav_state.active = false
    PokeAccess::TamasDexNav.instance_variable_set(:@shown, nil)
  end

  def teardown
    $player = @player_was
    super
  end

  test "the screen opens queued, on its title, its grid and the key to the other, then the species and its column" do
    screen.updateInfoBox
    assert_equal [["DexNav. Land. Water - Action to change. #{oddish(1, 3)}. Search Level: 3. Method: Walk. " \
                   "Abilities: Use Ability Vial. Item: Oranberry 50%, Rawstberry 5%. Chain: 2", false]], SpeakCapture.log
  end

  test "moving cuts in with only the species and its column, and a repaint on it says nothing" do
    scene = screen
    scene.updateInfoBox
    SpeakCapture.clear
    scene.instance_variable_set(:@cursor, 1)
    2.times { scene.updateInfoBox }
    assert_equal 1, SpeakCapture.log.length
    assert_equal true, SpeakCapture.log[0][1]
    assert_match(/\A#{oddish(2, 3)}\. Search Level: 3\./, SpeakCapture.log[0][0])
  end

  test "changing grid says the new one and the key back, even on the same species" do
    scene = screen
    scene.updateInfoBox
    SpeakCapture.clear
    scene.instance_variable_set(:@is_grass, false)
    scene.rows = WATER + LABELS + OWNED
    scene.updateInfoBox
    assert_match(/\AWater\. Land - Action to change\. #{oddish(1, 3)}\./, SpeakCapture.log[0][0])
  end

  test "with hints left out the key to the other grid is not said" do
    PokeAccess::Config.verbosity = :brief
    screen.updateInfoBox
    assert_equal false, SpeakCapture.log[0][0].include?("Action to change")
  end

  test "a species not seen says its marks in words, no types, and leaves out what only has marks" do
    $player = Trainer.new(Pokedex.new(false))
    screen(UNSEEN).updateInfoBox
    unknown = PokeAccess::DexEntry.unknown_marks("???")
    assert_equal "DexNav. Land. Water - Action to change. #{unknown}, #{list_place(1, 3)}. Search Level: 0. " \
                 "Abilities: Use Ability Vial. Chain: 2", SpeakCapture.log[0][0]
  end

  test "a game whose player cannot say what has been seen reads the species without its types" do
    $player = nil
    screen.updateInfoBox
    assert_match(/\ADexNav\. Land\. Water - Action to change\. Oddish, #{list_place(1, 3)}\. Search Level: 3\./, SpeakCapture.log[0][0])
  end

  test "a map with no species says only the title and that" do
    scene = PokemonDexNav_Scene.new({ :active_species => nil, :is_grass => false, :cursor => 0, :act_list => [] },
                                    WATER + LABELS + [["No species in this area", 256, 192]])
    scene.updateInfoBox
    assert_equal [["DexNav. No species in this area", false]], SpeakCapture.log
  end

  test "the repaint keeps its value, and the info key the line until the screen closes" do
    scene = screen
    assert_equal :painted, scene.updateInfoBox
    assert_equal SpeakCapture.log[0][0], PokeAccess::Info.info_text
    scene.pbEndScene
    assert_nil PokeAccess::Info.info_text
  end

  test "the overlay says what was found and where its grass is from the player, queued" do
    $tamas_dexnav_state.coords = [7, 14]
    MyOverlayModule.pbShowMyOverlay(Info.new(Pkmn.new("Oddish"), "Run Away", "Giga Drain", :ORANBERRY, :ORANBERRY, 2))
    list = "Oddish, Run Away, Giga Drain, ItemORANBERRY, #{t(:tdn_ivs, :n => 2)}"
    where = PokeAccess::Locator.dir_phrase(-3, 4)
    assert_equal [["#{t(:tdn_found, :list => list)}. #{where}", false]], SpeakCapture.log
  end

  test "one perfect IV is said too" do
    $tamas_dexnav_state.coords = [13, 10]
    MyOverlayModule.pbShowMyOverlay(Info.new(Pkmn.new("Oddish"), "---", "---", nil, nil, 1))
    assert_match(/#{t(:tdn_ivs, :n => 1)}/, SpeakCapture.log[0][0])
  end

  test "what the overlay leaves as marks, no item and no perfect IVs are left out" do
    $tamas_dexnav_state.coords = [13, 10]
    MyOverlayModule.pbShowMyOverlay(Info.new(Pkmn.new("Oddish"), "---", "---", nil, nil, 0))
    assert_equal [["#{t(:tdn_found, :list => "Oddish")}. #{PokeAccess::Locator.dir_phrase(3, 0)}", false]], SpeakCapture.log
  end

  test "the info key on the map keeps what was found while the search runs, from where the player stands now" do
    assert_nil PokeAccess::TamasDexNav.map_line
    $tamas_dexnav_state.coords = [13, 10]
    $tamas_dexnav_state.active = true
    MyOverlayModule.pbShowMyOverlay(Info.new(Pkmn.new("Oddish"), "---", "---", nil, nil, 0))
    $game_player.x = 12
    found = t(:tdn_found, :list => "Oddish")
    assert_equal "#{found}. #{PokeAccess::Locator.dir_phrase(1, 0)}", PokeAccess::Info.map_text
    $tamas_dexnav_state.active = false
    assert_nil PokeAccess::TamasDexNav.map_line
  end

  test "each step's rustle says where the grass is now, cutting in, but not the search's first" do
    showGrassShaking(12, 9, true, true)
    assert_nothing_spoken
    showGrassShaking(12, 9, false, true)
    assert_equal [[PokeAccess::Locator.dir_phrase(2, -1), true]], SpeakCapture.log
  end

  test "a search that brings up no overlay says it found nothing, queued, with an older search's grass out or not" do
    assert_equal :searched, pbDexNavSearchEvent
    $tamas_dexnav_state.coords = [12, 9]
    pbDexNavSearchEvent
    assert_equal [[t(:tdn_nothing), false], [t(:tdn_nothing), false]], SpeakCapture.log
  end

  test "a search that brings up the overlay says only what it found" do
    $tamas_dexnav_state.coords = [13, 10]
    $tamas_dexnav_state.finds = Info.new(Pkmn.new("Oddish"), "---", "---", nil, nil, 0)
    pbDexNavSearchEvent
    assert_equal 1, SpeakCapture.log.length
    assert_match(/#{t(:tdn_found, :list => "Oddish")}/, SpeakCapture.log[0][0])
  end

  private

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  def oddish(i, n)
    "Oddish, #{list_place(i, n)}, #{oddish_types}"
  end

  def oddish_types
    GameData::Species.get(:ODDISH).types.map { |ty| PokeAccess::Data.type_name(ty) }.join("/")
  end

  def screen(column = OWNED)
    PokemonDexNav_Scene.new({ :active_species => :ODDISH, :is_grass => true, :cursor => 0,
                              :act_list => [:ODDISH, :PIDGEY, :RATTATA] }, HEAD + LABELS + column)
  end
end
