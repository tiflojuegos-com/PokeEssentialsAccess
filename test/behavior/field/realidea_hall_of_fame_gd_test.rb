# Realidea's Hall of Fame PC viewer (games/realidea/hall_of_fame.rb, with plugins/hall_of_fame_bw_gen6.rb), through the
# viewer's own selection loop: the accept key clicks the front entrant and back the cancel button, only while it runs.

# The game's mouse (Raton): a click lands only on the object the player clicked; no area is ever clicked here.
class Game_Mouse
  attr_accessor :clicked

  def leftClick?(object = nil, _width = nil, _height = nil); !object.nil? && object.equal?(@clicked); end
  def inAreaLeft?(_x, _y, _w, _h); false; end
end

# Realidea's BW Hall of Fame (0319), down to the PC viewer's selection loop: with no record picked, left or a click on
# the left arrow shows the previous record and right or the right arrow the next (with more than one saved), a click
# on the cancel button leaves, and a click on an entrant picks the record (selectPokePC writes the front entrant's
# card); with one picked, back puts it down and a click on an entrant moves to it.
class HallOfFameScene
  def writePokemonDataPC(_pokemon, _hallNumber = -1); end

  def selectPokePC; writePokemonDataPC(@hallEntry[0]); end

  def pbPCSelection
    loop do
      Graphics.update
      Input.update
      if @selectedrecord
        @selectedrecord = false if Input.trigger?(Input::B)
        (0...@hallEntry.size).each do |i|
          selectPokePC if $mouse.inAreaLeft?(@positions[i][0] - 48, @positions[i][1] - 48, 96, 96)
        end
      else
        records = $PokemonGlobal.hallOfFame
        if records.size > 1 && (Input.trigger?(Input::LEFT) || $mouse.leftClick?(@sprites["arrowleft"]))
          @hallIndex = (@hallIndex - 1) % records.size
          @hallEntry = records[@hallIndex]
        elsif records.size > 1 && (Input.trigger?(Input::RIGHT) || $mouse.leftClick?(@sprites["arrowright"]))
          @hallIndex = (@hallIndex + 1) % records.size
          @hallEntry = records[@hallIndex]
        elsif $mouse.leftClick?(@sprites["cancelbuttom"])
          break
        end
        (0...@hallEntry.size).each do |i|
          next unless $mouse.inAreaLeft?(@positions[i][0] - 48, @positions[i][1] - 48, 96, 96)
          selectPokePC
          @selectedrecord = true
        end
      end
    end
  end
end

# Neither the scene nor the mouse exists when this engine's harness loads the plugin, so it is evaluated once more now
# that they do; the profile file loads here for the first time.
bw6 = File.join(Harness::ROOT, "plugins", "hall_of_fame_bw_gen6.rb")
eval(Harness.source(bw6), TOPLEVEL_BINDING, bw6)
rea_hof = File.join(Harness::ROOT, "games", "realidea", "hall_of_fame.rb")
eval(Harness.source(rea_hof), TOPLEVEL_BINDING, rea_hof)

class RealideaHallOfFameGdTest < PokeAccessTest
  # Where the viewer draws its entrants; the front one, the first, is the one the accept key clicks.
  POSITIONS = [[256, 250, 100], [96, 190, 90]]

  test "accept on the record list clicks the front entrant once, whose card is read, and stays in the viewer" do
    in_viewer do |scene|
      refute play_frames([[], [Input::C], [], [Input::C]]) { scene.pbPCSelection }, "the viewer still runs"
      assert_spoken_once(/\AChispa\b/, "the front entrant's card, not read again while its record is picked")
      refute_spoken(/Rocoso/, "the entrant behind it is never clicked")
    end
  end

  test "back on the record list clicks the cancel button and leaves, past no arrow" do
    in_viewer do |scene|
      assert play_frames([[], [Input::B]]) { scene.pbPCSelection }, "the viewer's loop ends"
      assert_equal 0, scene.instance_variable_get(:@hallIndex), "no arrow was clicked: the first record still shows"
    end
  end

  test "from a picked record, the first back puts it down and the second leaves" do
    in_viewer do |scene|
      refute play_frames([[Input::C], [Input::B]]) { scene.pbPCSelection }, "one back stays in the viewer"
    end
    in_viewer do |scene|
      assert play_frames([[Input::C], [Input::B], [Input::B]]) { scene.pbPCSelection }, "the second back leaves"
    end
  end

  test "a real click on the cancel button still leaves" do
    in_viewer do |scene|
      $mouse.clicked = scene.instance_variable_get(:@sprites)["cancelbuttom"]
      assert play_frames([[]]) { scene.pbPCSelection }
    end
  end

  test "outside the viewer's loop accept and back click nothing" do
    in_viewer do |scene|
      play_frames([[], [Input::B]]) { scene.pbPCSelection }
      cancel = scene.instance_variable_get(:@sprites)["cancelbuttom"]
      clicks = with_keys([Input::C, Input::B]) { [$mouse.inAreaLeft?(208, 202, 96, 96), $mouse.leftClick?(cancel)] }
      assert_equal [false, false], clicks, "the front entrant's area and the cancel button, once the loop is over"
    end
  end

  test "counts the cancel button clicked only on back, with no record picked, while the viewer runs" do
    in_viewer do |scene|
      cancel = scene.instance_variable_get(:@sprites)["cancelbuttom"]
      picked = viewer([], :@selectedrecord => true)
      unpainted = viewer([], :@sprites => {})
      [["back on the cancel button", scene, cancel, [Input::B], true],
       ["no viewer in its loop", nil, cancel, [Input::B], false],
       ["another sprite", scene, Object.new, [Input::B], false],
       ["a record picked", picked, picked.instance_variable_get(:@sprites)["cancelbuttom"], [Input::B], false],
       ["accept, not back", scene, cancel, [Input::C], false],
       ["no cancel button painted, asked about none", unpainted, nil, [Input::B], false]].each do |what, s, obj, keys, want|
        assert_equal want, watching(s) { with_keys(keys) { PokeAccess::ReaHallOfFame.cancel?(obj) } }, what
      end
    end
  end

  test "a key read that fails counts as no click" do
    in_viewer do |scene|
      cancel = scene.instance_variable_get(:@sprites)["cancelbuttom"]
      broken = lambda { |_k| raise IOError, "no keyboard" }
      assert_equal false, watching(scene) { with_trigger(broken) { PokeAccess::ReaHallOfFame.cancel?(cancel) } }
    end
  end

  private

  # Runs the block with the game's mouse and two saved records in place (Chispa and Rocoso, then Brasa), both taken
  # back afterwards; yields a viewer on the first record.
  def in_viewer
    saved = $mouse
    $mouse = Game_Mouse.new
    records = [[Poke.build(:name => "Chispa", :species => 25, :level => 30), Poke.build(:name => "Rocoso", :level => 51)],
               [Poke.build(:name => "Brasa", :level => 40)]]
    $PokemonGlobal.define_singleton_method(:hallOfFame) { records }
    yield viewer(records[0])
  ensure
    $mouse = saved
    $PokemonGlobal.singleton_class.send(:remove_method, :hallOfFame) if $PokemonGlobal.singleton_methods.include?(:hallOfFame)
  end

  # A viewer showing entry with no record picked, built without its initializer, as its selection loop finds it; ivars
  # overrides any of its state.
  def viewer(entry, ivars = {})
    scene = HallOfFameScene.allocate
    sprites = { "cancelbuttom" => Object.new, "arrowleft" => Object.new, "arrowright" => Object.new }
    { :@hallIndex => 0, :@hallEntry => entry, :@positions => POSITIONS, :@selectedrecord => false,
      :@sprites => sprites }.merge(ivars).each { |k, v| scene.instance_variable_set(k, v) }
    scene
  end

  # Runs the block with scene as the viewer whose loop runs (none for nil), the watch dropped afterwards.
  def watching(scene)
    PokeAccess::ReaHallOfFame.watch(scene) if scene
    yield
  ensure
    PokeAccess::ReaHallOfFame.unwatch
  end

  # Runs the block over frames, one per Graphics.update, each holding its keys for Input.trigger?; true when the block
  # returned by itself, false when the frames ran out first, as a player who walks away.
  def play_frames(frames)
    queue = frames.dup
    held = []
    sc = Graphics.singleton_class
    sc.send(:alias_method, :pa_rea_hof_update, :update)
    sc.send(:define_method, :update) do
      throw :rea_hof_frames_out if queue.empty?
      held = queue.shift
      pa_rea_hof_update
    end
    with_trigger(lambda { |k| held.include?(k) }) do
      catch(:rea_hof_frames_out) do
        yield
        return true
      end
      false
    end
  ensure
    sc.send(:alias_method, :update, :pa_rea_hof_update)
    sc.send(:remove_method, :pa_rea_hof_update)
  end

  # Runs the block with these keys pressed this frame for Input.trigger?.
  def with_keys(keys, &blk)
    with_trigger(lambda { |k| keys.include?(k) }, &blk)
  end

  # Runs the block with Input.trigger? true for the keys answer accepts and, for any other, as the engine reads it; the
  # engine's own put back afterwards.
  def with_trigger(answer)
    sc = Input.singleton_class
    sc.send(:alias_method, :pa_rea_hof_trigger, :trigger?)
    sc.send(:define_method, :trigger?) { |k, *rest| answer.call(k) || pa_rea_hof_trigger(k, *rest) }
    yield
  ensure
    sc.send(:alias_method, :trigger?, :pa_rea_hof_trigger)
    sc.send(:remove_method, :pa_rea_hof_trigger)
  end
end
