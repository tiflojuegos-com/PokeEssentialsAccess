# SceneWatcher.reader: the holder it builds says the held screen's entry when its key changes, the first read after
# watching queued and the later ones cutting in, and survives a frame with nothing to read or a reader that fails.

# A game screen with a blocking loop: main shows the entry it is handed and ticks the frame pollers once, as the
# engine's Input.update does, then closes.
class SwReaderLoopScene_pa
  def main(entry)
    @v = entry
    PokeAccess::Frame.run_pollers
    :closed
  end
end

class SceneWatcherReaderTest < PokeAccessTest
  def teardown
    (@holders || []).each { |h| h.unwatch }
    super
  end

  test "calls its block only while it holds a scene" do
    calls = 0
    holder = reader(:sw_probe) { |_s| calls += 1; nil }
    holder.poll
    holder.watch(World.stub_scene)
    holder.poll
    holder.unwatch
    holder.poll
    assert_equal 1, calls
  end

  test "its first read after watching is queued, the later ones cut in" do
    scene = World.stub_scene(:@v => 1)
    holder = item_reader(:sw_order)
    holder.watch(scene)
    holder.poll
    scene.instance_variable_set(:@v, 2)
    holder.poll
    assert_equal [["item 1", false], ["item 2", true]], SpeakCapture.log
  end

  test "a frame with nothing readable says nothing and leaves the first read queued" do
    scene = World.stub_scene
    holder = item_reader(:sw_nothing)
    holder.watch(scene)
    holder.poll
    assert_nothing_spoken "nothing readable yet"
    scene.instance_variable_set(:@v, 1)
    holder.poll
    assert_equal [["item 1", false]], SpeakCapture.log
  end

  test "an unchanged key says nothing" do
    scene = World.stub_scene(:@v => 1)
    holder = item_reader(:sw_same)
    holder.watch(scene)
    holder.poll
    SpeakCapture.clear
    3.times { holder.poll }
    assert_nothing_spoken
  end

  test "a key with no text says nothing, and back on the key read before it, that one is read again" do
    scene = World.stub_scene(:@v => 1)
    holder = item_reader(:sw_mute)
    holder.watch(scene)
    holder.poll
    SpeakCapture.clear
    scene.instance_variable_set(:@v, :mute)
    holder.poll
    assert_nothing_spoken "the key with no text"
    scene.instance_variable_set(:@v, 1)
    holder.poll
    assert_equal [["item 1", true]], SpeakCapture.log
  end

  test "a key whose text comes late is read once the text arrives, still as the first read" do
    scene = World.stub_scene(:@v => :late)
    holder = reader(:sw_late) { |s| [s.instance_variable_get(:@v), s.instance_variable_get(:@late_text).to_s] }
    holder.watch(scene)
    holder.poll
    assert_nothing_spoken "an empty text"
    scene.instance_variable_set(:@late_text, "late row")
    holder.poll
    assert_equal [["late row", false]], SpeakCapture.log
  end

  test "unwatched, it says nothing" do
    scene = World.stub_scene(:@v => 1)
    holder = item_reader(:sw_unwatch)
    holder.watch(scene)
    holder.poll
    holder.unwatch
    SpeakCapture.clear
    scene.instance_variable_set(:@v, 3)
    holder.poll
    assert_nothing_spoken
  end

  test "watching a scene again reads the key it last read, on the same scene or another" do
    [:same, :other].each do |which|
      scene = World.stub_scene(:@v => 2)
      holder = item_reader(:"sw_rewatch_#{which}")
      holder.watch(scene)
      holder.poll
      holder.unwatch
      SpeakCapture.clear
      holder.watch(which == :same ? scene : World.stub_scene(:@v => 2))
      holder.poll
      assert_equal [["item 2", false]], SpeakCapture.log, "watching the #{which} scene"
    end
  end

  test "watching another scene while one is held reads the new one's entry, on the same key too, as a first read" do
    holder = item_reader(:sw_swap)
    holder.watch(World.stub_scene(:@v => 2))
    holder.poll
    holder.poll
    SpeakCapture.clear
    holder.watch(World.stub_scene(:@v => 2))
    holder.poll
    assert_equal [["item 2", false]], SpeakCapture.log
  end

  test "a queued reader never cuts in, its later reads included" do
    scene = World.stub_scene(:@v => 1)
    holder = reader(:sw_queued, :queued => true) do |s|
      v = s.instance_variable_get(:@v)
      v ? [v, "desc #{v}"] : nil
    end
    holder.watch(scene)
    holder.poll
    scene.instance_variable_set(:@v, 2)
    holder.poll
    assert_equal [["desc 1", false], ["desc 2", false]], SpeakCapture.log
  end

  test "builds a callable text only on the frames that speak" do
    builds = 0
    scene = World.stub_scene(:@v => 1)
    holder = reader(:sw_lazy) do |s|
      v = s.instance_variable_get(:@v)
      [v, lambda { builds += 1; "item #{v}" }]
    end
    holder.watch(scene)
    holder.poll
    5.times { holder.poll }
    assert_equal 1, builds, "sitting on one entry builds its text once"
    scene.instance_variable_set(:@v, 2)
    holder.poll
    assert_equal 2, builds, "moving builds the next one once"
    assert_equal [["item 1", false], ["item 2", true]], SpeakCapture.log
  end

  test "a callable text that raises says nothing and is logged under the reader's slot" do
    holder = reader(:sw_lazy_boom) { |_s| [:k, lambda { raise "texto roto" }] }
    holder.watch(World.stub_scene)
    holder.poll
    assert_nothing_spoken
    assert_match(/texto roto/, PokeAccess.logged["cursor_sw_lazy_boom"].to_s)
  end

  test "a reader that raises says nothing that frame and is logged under its slot" do
    holder = reader(:sw_block_boom) { |_s| raise "lector roto" }
    holder.watch(World.stub_scene)
    holder.poll
    assert_nothing_spoken
    assert_match(/lector roto/, PokeAccess.logged["scene_watcher_sw_block_boom"].to_s)
  end

  test "the frame after a reader raised is read, still as the first read" do
    calls = 0
    holder = reader(:sw_block_once) do |_s|
      calls += 1
      raise "lector roto" if calls == 1
      [:k, "item 1"]
    end
    holder.watch(World.stub_scene)
    holder.poll
    holder.poll
    assert_equal [["item 1", false]], SpeakCapture.log
  end

  test "wired to a screen, it reads the entry while the screen's loop runs and lets go when the loop ends" do
    reader_on("SwReaderLoopScene_pa", :main, :sw_loop) do |s|
      v = s.instance_variable_get(:@v)
      v ? [v, "entry #{v}"] : nil
    end
    scene = SwReaderLoopScene_pa.new
    assert_equal :closed, scene.main(1), "the screen's loop keeps its value"
    assert_equal [["entry 1", false]], SpeakCapture.log, "read during the loop"
    SpeakCapture.clear
    scene.instance_variable_set(:@v, 2)
    PokeAccess::Frame.run_pollers
    assert_nothing_spoken "after the loop"
  end

  test "an optional reader binds nothing where the screen lacks its loop, and reports nothing missing" do
    before = PokeAccess::Hooks.missing.dup
    reader_on("SwReaderLoopScene_pa", :no_such_loop, :sw_optional, :optional => true) { |_s| nil }
    assert_equal before, PokeAccess::Hooks.missing
  end

  private

  # A reader on a class the game lacks, so only the test drives it; unwatched after the test.
  def reader(slot, opts = {}, &blk)
    reader_on("SwReaderNoSuchScene_pa", :main, slot, opts, &blk)
  end

  # A reader on cls#meth, unwatched after the test.
  def reader_on(cls, meth, slot, opts = {}, &blk)
    holder = PokeAccess::SceneWatcher.reader(cls, meth, slot, opts, &blk)
    (@holders ||= []).push(holder)
    holder
  end

  # A reader whose scene's @v is the key and "item <v>" its text: :mute has no text, and nil nothing to read.
  def item_reader(slot)
    reader(slot) do |s|
      v = s.instance_variable_get(:@v)
      if v.nil? then nil
      elsif v == :mute then [v, nil]
      else [v, "item #{v}"]
      end
    end
  end
end
