# Spin tiles and the Lens of Truth (FieldStates), which the games show only by animation: a spin is named by the
# player's facing as it starts, at each turn and as it stops; the lens is said as it takes effect and as it wears off.
class FieldStatesTest < PokeAccessTest
  FS = PokeAccess::FieldStates
  T = PokeAccess::I18n

  test "names a spin by the way the player faces as it starts, cutting in" do
    { 2 => :fs_spin_down, 4 => :fs_spin_left, 6 => :fs_spin_right, 8 => :fs_spin_up }.each do |dir, key|
      with_spin_tiles do
        FS.reset
        $game_player.direction = dir
        spin(true)
        assert_equal [[T.t(key), true]], SpeakCapture.log, "facing #{dir}"
      end
    end
  end

  test "names a spin with no facing it knows as a plain spin" do
    with_spin_tiles do
      $game_player.direction = 0
      spin(true)
      assert_equal [[T.t(:fs_spin_on), true]], SpeakCapture.log
    end
  end

  test "names a spin as a plain spin when there is no player to face a way" do
    with_spin_tiles do
      was = $game_player
      begin
        $game_player = nil
        spin(true)
      ensure
        $game_player = was
      end
      assert_equal [[T.t(:fs_spin_on), true]], SpeakCapture.log
    end
  end

  test "says nothing while no spin is under way" do
    with_spin_tiles do
      spin(false)
      assert_nothing_spoken
    end
  end

  test "says nothing in a game without spin tiles" do
    SpeakCapture.clear
    FS.spin_poll
    assert_nothing_spoken
  end

  test "names a spin once, not on every frame it lasts" do
    with_spin_tiles do
      $game_player.direction = 8
      spin(true)
      spin(true)
      assert_nothing_spoken
    end
  end

  test "names each turn the spin takes" do
    with_spin_tiles do
      $game_player.direction = 8
      spin(true)
      $game_player.direction = 6
      spin(true)
      assert_equal [[T.t(:fs_spin_right), true]], SpeakCapture.log
    end
  end

  test "says the stop once, queued after where the spin left the player, said the frame before" do
    with_spin_tiles do
      $game_player.direction = 8
      spin(true)
      spin(false)
      stop = SpeakCapture.log.dup
      spin(false)
      assert_equal [[[T.t(:fs_spin_stop), false]], []], [stop, SpeakCapture.log]
    end
  end

  test "after a reset, a spin still under way is named afresh" do
    with_spin_tiles do
      $game_player.direction = 8
      spin(true)
      FS.reset
      spin(true)
      assert_equal [T.t(:fs_spin_up)], SpeakCapture.lines
    end
  end

  test "after a reset, the end of the spin it forgot is not said" do
    with_spin_tiles do
      $game_player.direction = 8
      spin(true)
      FS.reset
      spin(false)
      assert_nothing_spoken
    end
  end

  test "announces the lens as it takes effect, cutting in, with any frames left" do
    [560, 1].each do |left|
      with_lens_scene do |lens|
        FS.reset
        SpeakCapture.clear
        lens.call(left)
        assert_equal [[T.t(:fs_lens_on), true]], SpeakCapture.log, "#{left} frames left"
      end
    end
  end

  test "keeps silent through the lens's countdown" do
    with_lens_scene do |lens|
      lens.call(560)
      lens.call(12)
      assert_nothing_spoken
    end
  end

  test "announces the lens wearing off, cutting in" do
    with_lens_scene do |lens|
      lens.call(560)
      lens.call(0)
      assert_equal [[T.t(:fs_lens_off), true]], SpeakCapture.log
    end
  end

  test "says nothing of a lens that is not running, or that it cannot read" do
    plain = Scene_Map.new
    { "no time left" => scene_with_timer(0), "a timer of nil" => scene_with_timer(nil),
      "a game without the lens" => plain, "a timer it cannot read" => scene_with_timer(Object.new),
      "another scene than the map" => scene_with_timer(100, Object.new) }.each do |what, scene|
      with_scene(scene) do
        FS.reset
        SpeakCapture.clear
        FS.lens_poll
        assert_nothing_spoken what
      end
    end
  end

  test "after a reset, a lens that ran out is not said to wear off" do
    with_lens_scene do |lens|
      lens.call(560)
      FS.reset
      lens.call(0)
      assert_nothing_spoken
    end
  end

  test "after a reset, a lens still running is announced again" do
    with_lens_scene do |lens|
      lens.call(560)
      FS.reset
      lens.call(300)
      assert_equal [[T.t(:fs_lens_on), true]], SpeakCapture.log
    end
  end

  test "a map change forgets a running lens: its end on the new map is not said" do
    with_lens_scene do |lens|
      lens.call(560)
      $game_map.map_id = 2
      PokeAccess::Locator.announce_map_change
      lens.call(0)
      assert_nothing_spoken
    end
  end

  test "every pulse polls the spin and the lens" do
    with_spin_tiles do
      with_lens_scene do |_lens|
        $game_player.direction = 4
        $PokemonGlobal.spinning = true
        @lens_left = 200
        SpeakCapture.clear
        PokeAccess::Frame.pulse
        assert_equal [[T.t(:fs_spin_left), true], [T.t(:fs_lens_on), true]], SpeakCapture.log
      end
    end
  end

  private

  # Sets the spin plugin's flag, clears the speech log and runs one spin poll.
  def spin(on)
    $PokemonGlobal.spinning = on
    SpeakCapture.clear
    FS.spin_poll
  end

  # Runs the block with $PokemonGlobal carrying the spin plugin's flag (off), as a game with spin tiles has it; the
  # flag goes and the player's facing is put back after.
  def with_spin_tiles
    dir = $game_player.direction
    def $PokemonGlobal.spinning; @pa_spin; end
    def $PokemonGlobal.spinning=(v); @pa_spin = v; end
    $PokemonGlobal.spinning = false
    yield
  ensure
    $game_player.direction = dir
    [:spinning, :spinning=].each do |m|
      $PokemonGlobal.singleton_class.send(:remove_method, m) if $PokemonGlobal.singleton_methods.include?(m)
    end
    $PokemonGlobal.send(:remove_instance_variable, :@pa_spin) if $PokemonGlobal.instance_variable_defined?(:@pa_spin)
  end

  # Runs the block on a map scene whose Lens of Truth has the frames left the test sets (@lens_left), yielding a
  # lambda that sets them, clears the speech log and runs one lens poll.
  def with_lens_scene
    @lens_left = 0
    test = self
    scene = Scene_Map.new
    scene.define_singleton_method(:eye_of_truth_time) { test.instance_variable_get(:@lens_left) }
    with_scene(scene) do
      yield lambda { |left|
        @lens_left = left
        SpeakCapture.clear
        FS.lens_poll
      }
    end
  end

  # A scene (a map scene unless one is given) whose eye_of_truth_time answers left.
  def scene_with_timer(left, scene = Scene_Map.new)
    scene.define_singleton_method(:eye_of_truth_time) { left }
    scene
  end

  # Runs the block with $scene set to scene, put back after.
  def with_scene(scene)
    was = $scene
    $scene = scene
    yield
  ensure
    $scene = was
  end
end
