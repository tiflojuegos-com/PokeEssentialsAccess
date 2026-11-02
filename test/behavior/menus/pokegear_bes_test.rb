# The Pokegear Essentials BES rebuilt on the old class name (Scene_Pokegear with the modern pbStartScene, pbScene and
# pbUpdate over PokegearButton sprites): the button focused is said by the buttons' own hook, and the dedup it keeps is
# reset as the Pokegear opens and as pbScene runs again on the same buttons, back from the map, the phone or the
# jukebox, which BES opens in place.

# The modern scene's methods on the stub scene, as BES defines them: the buttons are made as it opens, reselected on
# every update, and pbScene is one frame of its loop.
class Scene_Pokegear
  def pbStartScene(commands)
    @commands = commands
    @index = 0
    @buttons = commands.map { |name| PokegearButton.new(name) }
    pbUpdate
  end

  def pbUpdate
    @buttons.each_with_index { |button, i| button.selected = (i == @index) }
  end

  def pbScene
    pbUpdate
    @index
  end
end

# The resets as the core binds them on the scene class a fork names, bound now that the stub has the methods.
POKEGEAR_RESETS = Harness.source(File.join(Harness::ROOT, "core", "menus", "v21", "ui_v21.rb"))
                         .scan(/^PokeAccess::Engine\.scene_classes\("PokemonPokegear_Scene", "Scene_Pokegear"\)\.each.*?^end\n/m)
POKEGEAR_RESETS.each { |snippet| eval(snippet, TOPLEVEL_BINDING, "core/menus/v21/ui_v21.rb") }

class PokegearBesTest < PokeAccessTest
  BUTTONS = ["Mapa", "Teléfono", "Jukebox"]

  test "the core binds the resets on the old class name" do
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    assert_equal 1, POKEGEAR_RESETS.length
    assert_equal [true, true], ["Scene_Pokegear#pbStartScene", "Scene_Pokegear#pbScene"].map { |key| chains.key?(key) }
  end

  test "the Pokegear says the focused button as it opens" do
    open_gear
    assert_equal [["Mapa", true]], SpeakCapture.log
  end

  test "opening it again on the same button says it again" do
    open_gear
    open_gear
    assert_equal ["Mapa", "Mapa"], SpeakCapture.lines
  end

  test "back from an app it opened in place, the focused button is said again" do
    gear = open_gear
    gear.pbScene
    SpeakCapture.clear
    gear.pbScene
    assert_equal ["Mapa"], SpeakCapture.lines
  end

  test "its first pbScene call, which only runs the loop the opening began, says nothing more" do
    gear = open_gear
    SpeakCapture.clear
    gear.pbScene
    assert_nothing_spoken
  end

  private

  def open_gear
    gear = Scene_Pokegear.new
    gear.pbStartScene(BUTTONS)
    gear
  end
end
