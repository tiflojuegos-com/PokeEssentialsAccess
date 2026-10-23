# The positional engine (Sound::Pa3d) on the dll's stand-in: it boots once, only on a whole dll, loading each sound at
# the device's rate and placing the listener; each kind's volume (Mixer); why the soundscape fell silent (gate_report).
require "tmpdir"
require "fileutils"

class EngineTest < PokeAccessTest
  Pa3d = PokeAccess::Sound::Pa3d
  Catalog = PokeAccess::Sound::Catalog
  Mixer = PokeAccess::Sound::Mixer
  Scheduler = PokeAccess::Sound::Scheduler
  SOUNDS = PokeAccess::Paths::SOUNDS
  # Each emitter kind and the volume slider of its own it follows.
  SLIDERS = { :npc => :audio3d_npc, :object => :audio3d_object, :hazard => :audio3d_hazard, :trap => :audio3d_trap,
              :control => :audio3d_control, :push => :audio3d_push, :belt => :audio3d_belt, :door => :audio3d_door,
              :exit => :audio3d_exit, :teleporter => :audio3d_teleporter, :mark => :audio3d_mark,
              :water => :audio3d_water }

  test "loads each sound that has a file from the original, NUL-terminated, a loop as a loop" do
    with_sound_engine(true, 44100) do |dll|
      assert_equal Catalog.channels.map { |_id, file, loops| ["#{SOUNDS}/#{file}\0", loops] }, dll.loaded
    end
  end

  test "plays each sound on the channel the dll gave it, in the catalog's order" do
    with_sound_engine do
      ids = Catalog.channels.map { |id, _f, _l| id }
      assert_equal (0...ids.length).to_a, ids.map { |id| Pa3d.channel(id) }
    end
  end

  test "loads a sound's 48 kHz copy on a 48 kHz device" do
    in_sound_folder("pa3d_npc.wav") do
      with_sound_engine(true, 48000) do |dll|
        assert_equal ["#{Pa3d::SND48}/pa3d_npc.wav\0", 0], loaded(dll, "pa3d_npc")
      end
    end
  end

  test "loads the original on a 48 kHz device for a sound with no copy" do
    in_sound_folder("pa3d_npc.wav") do
      with_sound_engine(true, 48000) do |dll|
        assert_equal ["#{SOUNDS}/pa3d_door.wav\0", 0], loaded(dll, "pa3d_door")
      end
    end
  end

  test "loads the originals on a device at another rate or reporting none, a copy there or not" do
    in_sound_folder("pa3d_npc.wav") do
      [44100, 0].each do |rate|
        with_sound_engine(true, rate) do |dll|
          want = [["#{SOUNDS}/pa3d_npc.wav\0", 0], ["#{SOUNDS}/pa3d_door.wav\0", 0]]
          assert_equal want, [loaded(dll, "pa3d_npc"), loaded(dll, "pa3d_door")], "at #{rate} Hz"
        end
      end
    end
  end

  test "takes the device's rate and latency as it boots, a rate of zero as none" do
    { 48000 => 48000, 0 => nil }.each do |rate, want|
      with_sound_engine(true, rate) do
        assert_equal [want, 20], [Pa3d.device_rate, Pa3d.device_latency], "at #{rate} Hz"
      end
    end
  end

  test "puts the listener on the player's tile as it boots" do
    with_sound_engine(false) do |dll|
      Pa3d.boot
      assert_equal [[500, 500]], dll.args(:listener), "the player's (5, 5), in the engine's units"
    end
  end

  test "sends the listener only when it moves to a new tile" do
    with_sound_engine do |dll|
      sent = [Pa3d.listener(5, 5), Pa3d.listener(6, 5)]
      assert_equal [[true, true], [[600, 500]]], [sent, dll.args(:listener)]
    end
  end

  test "places no listener before the engine is ready" do
    with_sound_engine(false) do |dll|
      assert_equal [false, []], [Pa3d.listener(5, 5), dll.args(:listener)]
    end
  end

  test "boots once, a second call loading nothing more" do
    with_sound_engine do |dll|
      before = dll.loaded.length
      assert_equal [true, before], [Pa3d.boot, dll.loaded.length]
    end
  end

  test "stays down when the dll's start fails, and never tries it again" do
    with_sound_engine(false) do |dll|
      dll.instance_variable_set(:@starts, [0, 1])
      def dll.call(name, *args)
        name == :init ? @starts.shift : super
      end
      assert_equal false, Pa3d.boot, "its start fails"
      assert_equal false, Pa3d.boot, "and it is not started again, though it would start now"
      assert_equal [false, true], [Pa3d.ready?, Pa3d.boot_tried?]
    end
  end

  test "stays down when the dll raises as it starts" do
    with_sound_engine(false) do |dll|
      def dll.call(name, *args)
        raise "PA3D_Init crashed" if name == :init
        super
      end
      assert_equal [false, false, true], [Pa3d.boot, Pa3d.ready?, Pa3d.boot_tried?]
    end
  end

  test "tells once that positional sound is off when the dll is missing, fails to start or raises as it starts" do
    { "missing" => nil, "failing" => 0, "raising" => :raise }.each do |what, start|
      with_sound_engine(false, 44100, start.nil? ? [:init] : []) do |dll|
        starting(dll, start) unless start.nil?
        SpeakCapture.clear
        2.times { Pa3d.boot }
        assert_equal [PokeAccess::I18n.t(:audio3d_unavailable)], SpeakCapture.lines, what
      end
    end
  end

  test "says nothing of positional sound when it boots" do
    with_sound_engine(false) do
      SpeakCapture.clear
      Pa3d.boot
      assert_nothing_spoken
    end
  end

  test "never boots a dll missing an entry point it needs" do
    with_sound_engine(false, 44100, [:master]) do |dll|
      assert_equal [false, false, true, []], [Pa3d.boot, Pa3d.ready?, Pa3d.boot_tried?, dll.loaded]
    end
  end

  test "can play positionally while the dll is whole, until booting it fails" do
    with_sound_engine(false) { assert_equal true, Pa3d.positional?, "not booted yet" }
    with_sound_engine { assert_equal true, Pa3d.positional?, "booted" }
    with_sound_engine(false) do |dll|
      def dll.call(name, *args)
        name == :init ? 0 : super
      end
      Pa3d.boot
      assert_equal false, Pa3d.positional?, "its boot failed"
    end
    with_sound_engine(false, 44100, [:master]) { assert_equal false, Pa3d.positional?, "missing an entry point" }
  end

  test "leaves a sound the dll refuses without a channel, the others loaded" do
    with_sound_engine(false) do |dll|
      def dll.call(name, *args)
        raise "no such file" if name == :channel && args[0].include?("pa3d_door")
        super
      end
      assert_equal true, Pa3d.boot, "a refused file does not stop the boot"
      assert_equal [nil, 0], [Pa3d.channel(:door), Pa3d.channel(:npc)]
    end
  end

  test "plays each emitter kind at its own slider's volume" do
    SLIDERS.values.each_with_index { |key, i| PokeAccess::Config.send("#{key}=", 11 + i) }
    want = SLIDERS.keys.each_with_index.map { |kind, i| [kind, 11 + i] }
    assert_equal want, SLIDERS.keys.map { |kind| [kind, Mixer.volume(kind)] }
  end

  test "plays a kind switched off at volume zero, its slider kept for the menu" do
    PokeAccess::Config.sound_people = false
    assert_equal [0, 85], [Mixer.volume(:npc), Mixer.level(:npc)]
  end

  test "reports no data for a window with no frame counted" do
    [nil, {}].each { |gates| with_gates(gates) { assert_equal "(sin datos)", Scheduler.gate_report, gates.inspect } }
  end

  test "reports the frames played of the total, then why the others fell silent, the most frequent first" do
    with_gates({}) do
      4.times { Scheduler.gate(:total) }
      Scheduler.gate(:playing)
      Scheduler.gate(:message)
      2.times { Scheduler.gate(:in_menu) }
      assert_equal "1/4 playing by=in_menu:2 message:1", Scheduler.gate_report
    end
  end

  test "lists no reason when every frame played" do
    with_gates({}) do
      3.times { Scheduler.gate(:total); Scheduler.gate(:playing) }
      assert_equal "3/3 playing", Scheduler.gate_report
    end
  end

  test "starts a new window with each report" do
    with_gates({}) do
      Scheduler.gate(:total)
      Scheduler.gate(:no_map)
      assert_equal ["0/1 playing by=no_map:1", "(sin datos)"], [Scheduler.gate_report, Scheduler.gate_report]
    end
  end

  private

  # Runs the block from a fresh folder holding the named 48 kHz copies where the game keeps them; the working folder
  # and the files go after.
  def in_sound_folder(*copies)
    Dir.mktmpdir("pa_sound_folder") do |tmp|
      dir = File.join(tmp, Pa3d::SND48)
      FileUtils.mkdir_p(dir)
      copies.each { |n| File.open(File.join(dir, n), "wb") { |f| f.write("x") } }
      Dir.chdir(tmp) { yield }
    end
  end

  # What booting loaded for a sound's file (no extension), as [path, loop flag].
  def loaded(dll, file)
    dll.loaded.find { |path, _loops| path.include?("/#{file}.wav") }
  end

  # Makes the dll's start answer start, or raise for :raise.
  def starting(dll, start)
    dll.instance_variable_set(:@start, start)
    def dll.call(name, *args)
      return super unless name == :init
      raise "PA3D_Init crashed" if @start == :raise
      @start
    end
  end

  # Runs the block with the scheduler's count of silent frames set to gates, put back after.
  def with_gates(gates)
    was = Scheduler.instance_variable_get(:@gates)
    Scheduler.instance_variable_set(:@gates, gates)
    yield
  ensure
    Scheduler.instance_variable_set(:@gates, was)
  end
end
