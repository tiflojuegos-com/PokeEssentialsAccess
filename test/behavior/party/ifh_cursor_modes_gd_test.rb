# Infinite Fusion Hoenn's PC cursor modes (pbSetCursorMode), shown only by the arrow's picture: a change is said in
# the core's words for PC modes; setting the mode the scene is already in is not.

# The method as the game's scene has it: the mode kept in @cursormode, which starts at "default".
class PokemonStorageScene
  def pbSetCursorMode(value); @cursormode = value; end
end

# Hooks bind at load to the methods that exist then: the profile's file is evaluated once over the method above, and
# its profile name taken back out.
ifh_modes_path = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "cursor_modes.rb")
ifh_modes_profiles = PokeAccess::Game.profiles.dup
ifh_modes_name = PokeAccess::Game.instance_variable_get(:@profile_name)
begin
  eval(Harness.source(ifh_modes_path), TOPLEVEL_BINDING, ifh_modes_path)
ensure
  PokeAccess::Game.profiles.replace(ifh_modes_profiles)
  PokeAccess::Game.instance_variable_set(:@profile_name, ifh_modes_name)
end

class IfhCursorModesGdTest < PokeAccessTest
  T = PokeAccess::I18n

  test "says each mode the cursor turns to, interrupting" do
    { "multiselect" => :pc_mode_multi, "quickswap" => :pc_mode_quick }.each do |mode, key|
      assert_equal [[T.t(key), true]], set_modes(scene_in("default"), [mode]), mode
    end
  end

  test "says the normal mode on the way back, and for a mode it has no word of its own for" do
    assert_equal [[T.t(:pc_mode_multi), true], [T.t(:pc_mode_normal), true]],
                 set_modes(scene_in("default"), ["multiselect", "default"]), "back to the default"
    assert_equal [[T.t(:pc_mode_normal), true]], set_modes(scene_in("multiselect"), ["fusion"]), "a mode of its own"
  end

  test "says nothing when the mode set is the one the scene is already in" do
    assert_equal [], set_modes(scene_in("multiselect"), ["multiselect"])
  end

  test "takes a scene with no mode yet as in the normal one" do
    assert_equal [], set_modes(scene_in(nil), ["default"]), "the default again"
    assert_equal [[T.t(:pc_mode_multi), true]], set_modes(scene_in(nil), ["multiselect"]), "another mode"
  end

  test "says nothing when the mode comes back to the last one said, though the scene left it silently in between" do
    scene = scene_in("default")
    set_modes(scene, ["multiselect"])
    scene.instance_variable_set(:@cursormode, "default")
    assert_equal [], set_modes(scene, ["multiselect"])
  end

  test "answers what the game's method answers" do
    assert_equal "multiselect", scene_in("default").pbSetCursorMode("multiselect")
  end

  private

  # A PC scene whose cursor is in mode (nil for a scene that never set one).
  def scene_in(mode)
    scene = PokemonStorageScene.new
    scene.instance_variable_set(:@cursormode, mode)
    scene
  end

  # What scene says as each mode is set in turn.
  def set_modes(scene, modes)
    SpeakCapture.clear
    modes.each { |m| scene.pbSetCursorMode(m) }
    SpeakCapture.log.dup
  end
end
