# The gen-6 Pokegear (Scene_Pokegear, read by core/menus/v21/ui_v21.rb) on its real path: opened from the map through
# pbLoadRpgxpScene, its update reselecting the buttons each frame and running update_command, which opens each app in
# place. The focused option is said on open and on each move, the apps' own readers speak inside it, and back from an
# app (or from the Pokegear to the pause menu) the focused option is said again.
class PokegearGen6Test < PokeAccessTest
  APPS = ["Map", "Storage", "Quest Log", "Online Play"].freeze

  test "says the first option once as the Pokegear opens" do
    play(gear, [nil])
    assert_equal ["Map"], SpeakCapture.lines
  end

  test "says the focused option on each move of the cursor" do
    play(gear, [1, 2, 3])
    assert_equal APPS, SpeakCapture.lines
  end

  test "the PC opened from the Pokegear speaks, and back from it the option is said again" do
    storage = lambda { pbFadeOutIn(99999) { PokemonStorageScene.new.pbDisplay("Bulbasaur is selected.") } }
    play(gear(1 => storage), [1, :C, nil])
    assert_equal ["Map", "Storage", "Bulbasaur is selected.", "Storage"], SpeakCapture.lines
  end

  test "the region map opened from the Pokegear reads its squares" do
    map = lambda do
      pbFadeOutIn(99999) do
        scene = PokemonRegionMapScene.new
        scene.pbStartScene
        scene.pbGetMapLocation(3, 4)
        scene.pbEndScene
      end
    end
    play(gear(0 => map), [:C])
    assert_equal ["Map", PokeAccess::I18n.t(:brm_square, :x => 3, :y => 4), "Map"], SpeakCapture.lines
  end

  test "the quest log opened from the Pokegear speaks, and back from it the option is said again" do
    quests = [Questlog.quests, Questlog.steps]
    Questlog.quests = []
    Questlog.steps = []
    play(gear(2 => lambda { pbQuestlog }), [2, :C])
    assert_equal ["Map", "Quest Log", "Activas: 0", "Quest Log"], SpeakCapture.lines
  ensure
    Questlog.quests, Questlog.steps = quests
  end

  test "closing the Pokegear with B, the pause menu says its option again" do
    menu = World.stub_scene(:@options => [["POKéGEAR"]], :@option => 0)
    PokeAccess::DPMenu.watch(menu)
    PokeAccess::DPMenu.read(menu)
    play(gear, [])
    PokeAccess::DPMenu.read(menu)
    entry = PokeAccess::Menus.button_label("POKéGEAR")
    assert_equal [entry, "Map", entry], SpeakCapture.lines
  ensure
    PokeAccess::DPMenu.unwatch
  end

  private

  # The Pokegear over APPS, the app at each index given (a block, run as C is pressed on it).
  def gear(apps = {})
    Scene_Pokegear.new(APPS, apps)
  end

  # Opens gear from the map as the pause menu does (pbLoadRpgxpScene), over one scripted frame per Input.update: an
  # Integer moves the cursor there, a Symbol presses that button, nil presses none; past the script B closes it.
  def play(gear, frames)
    trigger = Input.method(:trigger?)
    update = Input.method(:update)
    scene = $scene
    pressed = []
    left = 50
    Input.define_singleton_method(:update) do
      raise "the Pokegear did not close" if (left -= 1) < 0
      step = frames.empty? ? :B : frames.shift
      pressed = step.is_a?(Symbol) ? [Input.const_get(step)] : []
      gear.sprites["command_window"].index = step if step.is_a?(Integer)
    end
    Input.define_singleton_method(:trigger?) { |key, *_rest| pressed.include?(key) }
    PokeAccess::MenuReturn.reset_nesting
    $scene = Scene_Map.new
    pbLoadRpgxpScene(gear)
  ensure
    Input.define_singleton_method(:trigger?, trigger)
    Input.define_singleton_method(:update, update)
    $scene = scene
  end
end
