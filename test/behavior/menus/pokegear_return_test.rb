# The RMXP-style Pokegear (Scene_Pokegear, gen-6) opens its map, phone and quest log in place and reselects the same
# button every frame after: back from one of them the focused button is said again; a return elsewhere leaves it.
class PokegearReturnTest < PokeAccessTest
  test "says the focused button once while the cursor stays on it" do
    on_pokegear { 2.times { gear_says("Quest Log") } }
    assert_equal [["Quest Log", true]], SpeakCapture.log
  end

  test "says the focused button again back from an app it opened in place" do
    on_pokegear do
      gear_says("Quest Log")
      back_from_app
      gear_says("Quest Log")
    end
    assert_equal [["Quest Log", true], ["Quest Log", true]], SpeakCapture.log
  end

  test "keeps the button said while a message inside the app closes, and says it again as the app closes" do
    on_pokegear do
      gear_says("Quest Log")
      PokeAccess::MenuReturn.enter!
      back_from_app
      gear_says("Quest Log")
      PokeAccess::MenuReturn.leave!
      gear_says("Quest Log")
    end
    assert_equal ["Quest Log", "Quest Log"], SpeakCapture.lines
  end

  test "leaves the button said after a return while another scene is up" do
    on_pokegear do
      gear_says("Quest Log")
      $scene = Object.new
      back_from_app
      gear_says("Quest Log")
    end
    assert_equal ["Quest Log"], SpeakCapture.lines
  end

  test "leaves the button said after a return in a game with no Scene_Pokegear" do
    on_scene(nil, Object.new) do
      gear_says("Quest Log")
      back_from_app
      gear_says("Quest Log")
    end
    assert_equal ["Quest Log"], SpeakCapture.lines
  end

  private

  # Runs the block on an RMXP-style Pokegear: a stand-in under the game's class name, as $scene.
  def on_pokegear(&blk)
    gear = Class.new
    on_scene(gear, gear.new, &blk)
  end

  # Runs the block with Scene_Pokegear standing for gear (absent when nil) and $scene set to scene, the return
  # nesting at rest; the game's own class, $scene and the nesting are put back afterwards.
  def on_scene(gear, scene)
    had_gear = Object.const_defined?(:Scene_Pokegear, false) ? Object.const_get(:Scene_Pokegear) : nil
    had_scene = $scene
    Object.send(:remove_const, :Scene_Pokegear) if had_gear
    Object.const_set(:Scene_Pokegear, gear) if gear
    $scene = scene
    PokeAccess::MenuReturn.reset_nesting
    yield
  ensure
    Object.send(:remove_const, :Scene_Pokegear) if Object.const_defined?(:Scene_Pokegear, false)
    Object.const_set(:Scene_Pokegear, had_gear) if had_gear
    $scene = had_scene
    PokeAccess::MenuReturn.reset_nesting
  end

  # The Pokegear's per-frame read of its focused button.
  def gear_says(text)
    PokeAccess::UIV21.speak_changed(:pokegear, text)
  end

  # Leaves a subscreen the Pokegear opened in place, as its fade does.
  def back_from_app
    PokeAccess::MenuReturn.enter!
    PokeAccess::MenuReturn.leave!
  end
end
