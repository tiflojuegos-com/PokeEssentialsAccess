# The free camera under the GameData era's engine: the game's input held while it is open, the direction too where
# dir4 takes an argument (La Base de Sky), and a step's line said there.
class CameraGdTest < PokeAccessTest
  Camera = PokeAccess::Camera
  ROOM = ['########',
          '#@.g...#',
          '########']

  test "holds the game's buttons and directions while open, dir4's argument too, and after a map change shuts it" do
    on_map do
      sc = Input.singleton_class
      sc.send(:alias_method, :camera_gd_saved_dir4, :dir4__access_orig)
      sc.send(:alias_method, :camera_gd_saved_trigger, :trigger__access_orig)
      begin
        Input.define_singleton_method(:dir4__access_orig) { |*_a| 4 }
        Input.define_singleton_method(:trigger__access_orig) { |*_a| true }
        Camera.open
        held = [Input.dir4(true), Input.dir4, Input.trigger?(Input::C)]
        Camera.reset
        after = Input.dir4(true)
        Camera.instance_variable_set(:@guard, false)
        free = [Input.dir4(true), Input.trigger?(Input::C)]
        assert_equal [[0, 0, false], 0, [4, true]], [held, after, free], "held while open and while the walk key is down"
      ensure
        sc.send(:alias_method, :dir4__access_orig, :camera_gd_saved_dir4)
        sc.send(:alias_method, :trigger__access_orig, :camera_gd_saved_trigger)
        sc.send(:remove_method, :camera_gd_saved_dir4)
        sc.send(:remove_method, :camera_gd_saved_trigger)
        Camera.reset
      end
    end
  end

  test "a step onto bare ground says nothing, and onto grass names the ground" do
    on_map do
      Camera.open
      SpeakCapture.clear
      Camera.move(6, :step)
      bare = [Camera.focus, SpeakCapture.lines]
      Camera.move(6, :step)
      label = PokeAccess::World::Terrain.label(3, 1)
      refute_nil label
      assert_equal [[[2, 1], []], [3, 1], [PokeAccess::I18n.t(label)]], [bare, Camera.focus, SpeakCapture.lines]
    end
  end

  private

  # Runs the block on a tile map with a trainer, whom control needs, the camera forgotten before and after.
  def on_map
    had = $Trainer
    $Trainer = Object.new
    with_tile_world(ROOM) do
      Camera.reset
      yield
    end
  ensure
    $Trainer = had
    Camera.reset
  end
end
