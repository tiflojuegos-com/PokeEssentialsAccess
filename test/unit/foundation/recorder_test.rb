# The session recorder: while on, it writes what is said and what changed each frame (map, place, scene, selection,
# input) as tab-separated lines with tagged diag dumps; the speech observers it hears through; the Replay auditor.
class RecorderTest < PokeAccessTest
  Recorder = PokeAccess::Recorder
  Speech = PokeAccess::Speech
  START_SECTIONS = [:diag_focus, :diag_map, :diag_locator, :diag_pathfinder, :diag_surface, :diag_audio3d,
                    :diag_scene, :diag_runtime].freeze
  MAP_SECTIONS = [:diag_map, :diag_locator, :diag_pathfinder, :diag_surface].freeze
  SCENE_SECTIONS = [:diag_scene].freeze
  STATE = [:@on, :@lines, :@path, :@seen, :@count, :@pending, :@last_snap].freeze
  REAL_DIAG = PokeAccess::Keys.method(:diag_build)
  HEALTHY = "# pea-recording 1\tgen6\t16.0\n" \
            "1.00\tmap\t60\tCentro Pokemon\n" \
            "1.10\tsay\t1\tCentro Pokemon\n" \
            "2.00\tsel\t0\tenfermera\n" \
            "2.05\tsay\t1\tenfermera, a 3 pasos\n" \
            "3.00\tpos\t5\t8\n" \
            "3.10\tsay\t1\tenfermera, a 3 pasos\n"

  test "starts a recording in a new timestamped file headed by the engine it runs on" do
    with_recorder do
      name = Recorder.start
      engine = PokeAccess::Engine
      assert_match(/\Arec-\d{8}-\d{6}\.txt\z/, name)
      assert_equal [true, "#{Recorder::DIR}/#{name}"], [Recorder.recording?, Recorder.path]
      assert_equal "# pea-recording 1\t#{engine.kind}\t#{engine.version}\t#{engine.fork.inspect}", file_lines[0]
    end
  end

  test "dumps the start sections as it opens, without the diag's own header line" do
    with_recorder do
      Recorder.start
      assert_equal START_SECTIONS.map { |s| row("diag", "start", "#{s}: ok") }, file_lines[1..-1]
    end
  end

  test "writes each spoken line with its interrupt flag" do
    rows = recording do
      PokeAccess.speak("Centro Pokemon", true)
      PokeAccess.speak("enfermera", false)
    end
    assert_equal [row("say", 1, "Centro Pokemon"), row("say", 0, "enfermera")], rows
  end

  test "stamps each line with the session clock's seconds, to two decimals" do
    assert_equal ["3.14\tin\ttecla:info"], recording(3.14159) { Recorder.note_key("info") }
  end

  test "keeps a tab or a line break in a field from splitting its line" do
    rows = recording { Recorder.note("say", 0, "linea\tcon\ttabs\ny\r\nsalto") }
    assert_equal [row("say", 0, "linea con tabs y salto")], rows
  end

  test "writes its lines to the file every 120 noted, without waiting for the stop" do
    with_recorder do
      Recorder.start
      opened = file_lines.length
      119.times { |i| Recorder.note("say", 1, "linea #{i}") }
      assert_equal opened, file_lines.length, "119 lines wait"
      Recorder.note("say", 1, "linea 119")
      assert_equal opened + 120, file_lines.length, "the 120th writes them all"
    end
  end

  test "answers how many lines the session noted when it stops, those already written included" do
    with_recorder do
      Recorder.start
      125.times { |i| Recorder.note("say", 1, "linea #{i}") }
      assert_equal START_SECTIONS.length + 125, Recorder.stop
    end
  end

  test "writes nothing more once stopped, however much is said or noted" do
    with_recorder do
      Recorder.start
      Recorder.stop
      closed = file_lines
      PokeAccess.speak("ya nadie escucha", true)
      120.times { Recorder.note("in", "confirm") }
      Recorder.snapshot([:diag_map], "map")
      Recorder.sample
      assert_equal [false, closed], [Recorder.recording?, file_lines]
    end
  end

  test "answers 0 when stopped again, the recording already over" do
    with_recorder do
      Recorder.start
      Recorder.note("in", "confirm")
      Recorder.stop
      assert_equal 0, Recorder.stop
    end
  end

  test "does not start a second recording while one runs" do
    with_recorder do
      name = Recorder.start
      assert_nil Recorder.start
      assert_equal "#{Recorder::DIR}/#{name}", Recorder.path, "the first goes on in its file"
    end
  end

  test "answers 0 for a stop that fails partway, and is off" do
    with_recorder do
      Recorder.start
      stubbing(Speech, :unobserve, lambda { |_key| raise "unobserve failed" }) { assert_equal 0, Recorder.stop }
      assert_equal false, Recorder.recording?
    end
  end

  test "records on when its file cannot be written" do
    with_recorder do
      Recorder.start
      path = Recorder.path
      File.delete(path)
      Dir.mkdir(path)
      begin
        121.times { Recorder.note("in", "confirm") }
        assert_equal [true, START_SECTIONS.length + 121], [Recorder.recording?, Recorder.stop]
      ensure
        Dir.rmdir(path)
      end
    end
  end

  test "drops a line it fails to stamp, and records on" do
    rows = recording do
      stubbing(PokeAccess, :clock, lambda { raise "clock failed" }) { Recorder.note("in", "confirm") }
      Recorder.note("in", "cancel")
    end
    assert_equal [row("in", "cancel")], rows
  end

  test "answers nil and stays off when it cannot start" do
    with_recorder do
      stubbing(Speech, :observe, lambda { |*_args| raise "observe failed" }) { assert_nil Recorder.start }
      assert_equal false, Recorder.recording?
    end
  end

  test "notes a field only when it changed since that field was last noted" do
    rows = recording do
      assert_equal true, Recorder.on_change("pos", :pos, 5, 7), "a first value"
      assert_equal false, Recorder.on_change("pos", :pos, 5, 7), "the same again"
      assert_equal true, Recorder.on_change("map", :map, 5, 7), "another field with the same value"
      assert_equal true, Recorder.on_change("pos", :pos, 5, 8), "a new value"
    end
    assert_equal [row("pos", 5, 7), row("map", 5, 7), row("pos", 5, 8)], rows
  end

  test "dumps diag sections as rows tagged with why" do
    rows = recording { Recorder.snapshot([:diag_map, :diag_scene], "map") }
    assert_equal [row("diag", "map", "diag_map: ok"), row("diag", "map", "diag_scene: ok")], rows
  end

  test "dumps the diag's own section line by line, its timestamped header left out" do
    rows = recording { with_real_diag { Recorder.snapshot([:diag_map], "map") } }
    lines = PokeAccess::Keys.diag_build([:diag_map]).split("\n")
    assert_match(/\A=== PokeAccess diag /, lines[0], "the diag heads its dump with the time")
    assert_equal lines.drop(1).map { |line| row("diag", "map", line) }, rows
  end

  test "writes a dump like the last one for the same why as a single marker" do
    rows = recording do
      Recorder.snapshot([:diag_map], "map")
      Recorder.snapshot([:diag_map], "map")
      Recorder.snapshot([:diag_map], "scene")
    end
    assert_equal [row("diag", "map", "diag_map: ok"), row("diag", "map", "(igual que el anterior)"),
                  row("diag", "scene", "diag_map: ok")], rows
  end

  test "writes nothing for a dump the diag fails to build, and records on" do
    rows = recording do
      stubbing(PokeAccess::Keys, :diag_build, lambda { |_sections| raise "diag failed" }) do
        Recorder.snapshot([:diag_map], "map")
      end
      Recorder.note("in", "confirm")
    end
    assert_equal [row("in", "confirm")], rows
  end

  test "takes a deferred dump at the next frame's start, once" do
    rows = recording do
      Recorder.defer([:diag_map], "map")
      Recorder.note("in", "confirm")
      Recorder.flush_pending
      Recorder.flush_pending
    end
    assert_equal [row("in", "confirm"), row("diag", "map", "diag_map: ok")], rows
  end

  test "samples the map with its name, the player's place, the scene and the selection" do
    in_scene(Scene_Map.new) do
      rows = recording { Recorder.sample }
      assert_equal [row("map", 1, PokeAccess::Locator.map_name(1)), row("pos", 5, 5),
                    row("scene", "Scene_Map", PokeAccess::Control.reason.inspect), row("sel", 0, "")], rows
    end
  end

  test "dumps the map's sections the frame after a new map, and the scene's the frame after a new scene" do
    rows = in_scene(Scene_Map.new) { recording { 2.times { Recorder.sample } } }
    assert_equal MAP_SECTIONS.map { |s| row("diag", "map", "#{s}: ok") } +
                 SCENE_SECTIONS.map { |s| row("diag", "scene", "#{s}: ok") }, rows[4..-1],
                 "the map's with its surroundings (locator) and route (pathfinder)"
  end

  test "notes nothing for a frame where nothing changed" do
    in_scene(Scene_Map.new) do
      with_recorder do
        Recorder.start
        2.times { Recorder.sample }
        Recorder.flush
        settled = file_lines
        Recorder.sample
        Recorder.flush
        assert_equal settled, file_lines
      end
    end
  end

  test "notes the player's step, a new selection and a scene with none on screen" do
    reason = nil
    rows = in_scene(Scene_Map.new) do
      recording do
        Recorder.sample
        Recorder.flush_pending
        $game_player.x = 6
        PokeAccess::Locator.instance_variable_set(:@ti, 2)
        PokeAccess::Locator.instance_variable_set(:@target, Struct.new(:name).new("enfermera"))
        $scene = nil
        reason = PokeAccess::Control.reason.inspect
        Recorder.sample
      end
    end
    assert_equal [row("pos", 6, 5), row("scene", "nil", reason), row("sel", 2, "enfermera")], rows[-3..-1]
  end

  test "samples no map or place while there is no player yet" do
    player = $game_player
    $game_player = nil
    rows = in_scene(Scene_Map.new) { recording { Recorder.sample } }
    assert_equal ["scene", "sel"], rows.map { |line| line.split("\t")[1] }
  ensure
    $game_player = player
  end

  test "leaves the rest of a frame's sample after a piece that fails" do
    in_scene(Scene_Map.new) do
      with_recorder do
        Recorder.start
        opened = file_lines.length
        stubbing(PokeAccess::Control, :reason, lambda { |*_scope| raise "reason failed" }) { Recorder.sample }
        Recorder.flush
        assert_equal ["map", "pos"], file_lines[opened..-1].map { |line| line.split("\t")[1] }
      end
    end
  end

  test "samples no selection while the locator has none" do
    PokeAccess::Locator.instance_variable_set(:@ti, nil)
    rows = in_scene(Scene_Map.new) { recording { Recorder.sample } }
    assert_equal ["map", "pos", "scene"], rows.map { |line| line.split("\t")[1] }
  end

  test "notes the input pressed in the frame: confirm, cancel or a direction" do
    { [:trigger, Input::C] => "confirm", [:trigger, Input::B] => "cancel", [:repeat, Input::UP] => "dir",
      [:repeat, Input::DOWN] => "dir", [:repeat, Input::LEFT] => "dir",
      [:repeat, Input::RIGHT] => "dir" }.each do |(how, key), want|
      rows = in_scene(Scene_Map.new) { recording { pressing(how, key) { Recorder.sample } } }
      assert_equal row("in", want), rows[0], "for #{how} #{key}"
    end
  end

  test "notes no input for a frame with only another button pressed, or an Input that fails" do
    in_scene(Scene_Map.new) do
      other = recording { pressing(:trigger, Input::A) { Recorder.sample } }
      broken = recording { failing_input { Recorder.sample } }
      assert_equal [[], []], [other, broken].map { |rows| rows.select { |line| line.split("\t")[1] == "in" } }
    end
  end

  test "notes a mod key as it fires" do
    assert_equal [row("in", "tecla:hp")], recording { Recorder.note_key("hp") }
  end

  test "never asks the diag for the perf window or the poll benchmark on its own" do
    in_scene(Scene_Map.new) do
      with_recorder do
        Recorder.start
        2.times { Recorder.sample }
        $scene = nil
        2.times { Recorder.sample }
        assert_equal [], @diag_asked.flatten & [:diag_perf, :diag_polls], @diag_asked.inspect
      end
    end
  end

  test "hands every spoken line to an observer as a message with its text, category and interrupt flag" do
    seen = []
    observing(:spec_observer, lambda { |msg| seen.push([msg.text, msg.category, msg.interrupt]) }) do
      PokeAccess.speak("hola mundo", false, :system)
    end
    assert_equal [["hola mundo", :system, false]], seen
  end

  test "hands an observer no line for a blank text, which is not spoken" do
    seen = []
    observing(:spec_observer, lambda { |msg| seen.push(msg.text) }) { PokeAccess.speak(" \n\t ", true) }
    assert_equal [[], []], [seen, SpeakCapture.log]
  end

  test "still speaks a line an observer fails on, and hands it to the other observers" do
    seen = []
    observing(:spec_failing, lambda { |_msg| raise "observer exploded" }) do
      observing(:spec_observer, lambda { |msg| seen.push(msg.text) }) { PokeAccess.speak("sigo hablando", true) }
    end
    assert_equal [[["sigo hablando", true]], ["sigo hablando"]], [SpeakCapture.log, seen]
  end

  test "stops handing lines to an observer once it is removed" do
    seen = []
    observing(:spec_observer, lambda { |msg| seen.push(msg.text) }) do
      PokeAccess.speak("antes", true)
      Speech.unobserve(:spec_observer)
      PokeAccess.speak("despues", true)
    end
    assert_equal ["antes"], seen
  end

  test "replaces the observer registered again under the same key" do
    first = []
    second = []
    observing(:spec_observer, lambda { |msg| first.push(msg.text) }) do
      Speech.observe(:spec_observer) { |msg| second.push(msg.text) }
      PokeAccess.speak("hola", true)
    end
    assert_equal [[], ["hola"]], [first, second]
  end

  test "audits a healthy session clean" do
    assert_equal [], Replay.audit(HEALTHY)
  end

  test "audits clean a recording it wrote of a session that speaks after each selection" do
    text = in_scene(Scene_Map.new) do
      with_recorder do
        Recorder.start
        Recorder.sample
        PokeAccess.speak(PokeAccess::Locator.map_name(1), true)
        Recorder.sample
        Recorder.stop
        File.read(Recorder.path)
      end
    end
    assert_equal [], Replay.audit(text)
  end

  test "flags a selection nothing was spoken after, by its index and name" do
    assert_equal ["selection changed but nothing was spoken: 0 enfermera"],
                 Replay.audit("1.00\tsel\t0\tenfermera\n1.50\tsel\t1\tcartel\n2.00\tsay\t1\tcartel\n")
  end

  test "flags the last selection when the session ends before anything is said of it" do
    assert_equal ["selection changed but nothing was spoken: 1 cartel"],
                 Replay.audit("1.00\tsel\t0\tenfermera\n1.10\tsay\t1\tenfermera\n1.50\tsel\t1\tcartel\n")
  end

  test "flags a line spoken twice with nothing between, saying how long after" do
    assert_equal ["line repeated with no movement between: cartel (+0.20s)"],
                 Replay.audit("1.00\tsay\t1\tcartel\n1.20\tsay\t1\tcartel\n")
  end

  test "does not flag a line said again after a step, a key, a new map, scene or selection" do
    ["1.10\tpos\t5\t9", "1.10\tin\ttecla:info", "1.10\tin\tdir", "1.10\tmap\t2\tRuta 1",
     "1.10\tscene\tScene_Map\tnil", "1.10\tsel\t1\tcartel"].each do |between|
      text = "1.00\tsay\t1\tcartel\n#{between}\n1.20\tsay\t1\tcartel\n"
      assert_equal [], Replay.audit(text), "after #{between.inspect}"
    end
  end

  test "flags a spoken line that still carries control codes" do
    assert_equal ["raw control codes spoken: Hola \\c[3]entrenador"],
                 Replay.audit("1.00\tsay\t1\tHola \\c[3]entrenador\n")
  end

  test "reads past the header, blank lines, Windows line ends and the diag rows" do
    text = "# pea-recording 1\tgen6\t16.0\r\n\r\n1.00\tdiag\tmap\tdiag_map: ok\r\n" \
           "1.10\tdiag\tmap\t(igual que el anterior)\r\n1.20\tsay\t1\tCentro Pokemon\r\n"
    assert_equal [[1.2, "say", "1", "Centro Pokemon"]], Replay.parse(text).reject { |r| r[1] == "diag" }
    assert_equal [], Replay.audit(text)
  end

  test "audits the committed recordings clean" do
    refute_empty Replay.fixtures, "there are reference recordings to audit"
    problems = Replay.fixtures.map { |f| [File.basename(f), Replay.audit(File.read(f))] }
    assert_equal [], problems.reject { |_name, found| found.empty? }
  end

  private

  # Runs the block with the recorder off and fresh, on a clock stopped at clock seconds and a diag that dumps each
  # section asked as "<section>: ok" (each list of sections asked kept in @diag_asked); the recorder is stopped and its
  # file deleted after, its state and the stubs put back.
  def with_recorder(clock = 12.5)
    saved = STATE.map { |ivar| Recorder.instance_variable_get(ivar) }
    [false, [], nil, {}, 0, [], {}].each_with_index { |value, i| Recorder.instance_variable_set(STATE[i], value) }
    @diag_asked = []
    stubbing(PokeAccess, :clock, lambda { clock }) do
      stubbing(PokeAccess::Keys, :diag_build, fake_diag(@diag_asked)) { yield }
    end
  ensure
    Recorder.stop if Recorder.recording?
    path = Recorder.path
    File.delete(path) if path && File.exist?(path)
    Speech.unobserve(:recorder)
    STATE.each_with_index { |ivar, i| Recorder.instance_variable_set(ivar, saved[i]) }
  end

  # A stand-in for the diag's builder: its timestamped header, then "<section>: ok" for each section asked; each list
  # of sections asked is pushed onto asked.
  def fake_diag(asked)
    lambda do |sections|
      asked.push(sections)
      (["=== PokeAccess diag #{Time.now} ==="] + sections.map { |s| "#{s}: ok" }).join("\n")
    end
  end

  # Runs the block with the diag's own builder back in place of with_recorder's stand-in.
  def with_real_diag
    stubbing(PokeAccess::Keys, :diag_build, lambda { |sections| REAL_DIAG.call(sections) }) { yield }
  end

  # The lines the block added to a recording started for it, on with_recorder's clock and diag, once stopped.
  def recording(clock = 12.5)
    with_recorder(clock) do
      Recorder.start
      opened = file_lines.length
      yield
      Recorder.stop
      file_lines[opened..-1]
    end
  end

  # A recorded line at 12.50 seconds with the given fields.
  def row(*fields)
    "12.50\t#{fields.join("\t")}"
  end

  # The lines of the recording's file, or none before it exists.
  def file_lines
    path = Recorder.path
    path && File.exist?(path) ? File.readlines(path).map(&:chomp) : []
  end

  # Runs the block with $scene set to scene, put back after.
  def in_scene(scene)
    was = $scene
    $scene = scene
    yield
  ensure
    $scene = was
  end

  # Runs the block with only key held for Input's trigger? or repeat? (how is :trigger or :repeat), put back after.
  def pressing(how, key)
    meth = how == :trigger ? :trigger? : :repeat?
    stubbing(Input, meth, lambda { |asked| asked == key }) { yield }
  end

  # Runs the block with Input's trigger? and repeat? raising, put back after.
  def failing_input
    broken = lambda { |_key| raise "input failed" }
    stubbing(Input, :trigger?, broken) { stubbing(Input, :repeat?, broken) { yield } }
  end

  # Runs the block with blk observing speech under key, removed after.
  def observing(key, blk)
    Speech.observe(key, &blk)
    yield
  ensure
    Speech.unobserve(key)
  end

  # Runs the block with mod's singleton method meth answering as impl does, put back after.
  def stubbing(mod, meth, impl)
    real = mod.method(meth)
    mod.define_singleton_method(meth, &impl)
    yield
  ensure
    mod.define_singleton_method(meth, real)
  end
end
