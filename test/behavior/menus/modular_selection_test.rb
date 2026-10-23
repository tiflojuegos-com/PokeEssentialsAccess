# ChampChar13's Modular Pokemon Selection (plugins/modular_pokemon_selection.rb): the card drawPage paints for the
# focused Pokemon is said as the carousel opens and on each move, the name at every level, the types from Medium and
# what the card paints, in reading order, at Full.

# The scene as the plugin runs it, its card cut down to a few of the rows its drawPage paints.
class ModularSelection_Scene
  def initialize(list)
    @pokemonlist = list
    @index = 0
  end

  def drawPage
    @pokemon = @pokemonlist[@index]
    pbDrawTextPositions(nil, [[@pokemon.name, 46, 84, 0], ["5", 46, 114, 0], ["Species", 238, 158, 0],
                              [@pokemon.name, 435, 158, 2], ["Nature", 238, 190, 0], ["Hardy", 435, 190, 2]])
  end

  def move(index)
    @index = index
    drawPage
  end
end

MODULAR_SELECTION_HOOK = Harness.source(File.join(Harness::ROOT, "plugins", "modular_pokemon_selection.rb"))
                                .scan(/^PokeAccess::Hooks\.around_hook\("ModularSelection_Scene".*?^end\n/m)
MODULAR_SELECTION_HOOK.each { |hook| eval(hook, TOPLEVEL_BINDING, "plugins/modular_pokemon_selection.rb") }

class ModularSelectionTest < PokeAccessTest
  CARD = "5, Species, Bulbasaur, Nature, Hardy"

  test "says the focused Pokemon's card at each level as the carousel opens, queued" do
    said = vb_levels do
      SpeakCapture.clear
      scene.drawPage
      SpeakCapture.log.dup
    end
    assert_equal [[["Bulbasaur", false]], [["Bulbasaur", false]], [["Bulbasaur, #{CARD}", false]]], said
  end

  test "says the next Pokemon on a move, interrupting" do
    s = scene
    s.drawPage
    SpeakCapture.clear
    s.move(1)
    assert_equal [["Charmander", true]], SpeakCapture.log.map { |l, i| [l.split(",").first, i] }
  end

  test "keeps the whole card for the info key" do
    scene.drawPage
    assert_equal "Bulbasaur, #{CARD}", PokeAccess::Info.instance_variable_get(:@row)
  end

  private

  def scene
    mon = Struct.new(:name)
    ModularSelection_Scene.new([mon.new("Bulbasaur"), mon.new("Charmander")])
  end
end
