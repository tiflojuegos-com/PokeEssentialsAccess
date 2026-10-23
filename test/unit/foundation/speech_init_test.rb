# The screen-reader bridge (core/speech/backend.rb): one start on first use, a failed one again only on the Ctrl+Alt+F8
# retry; its speech and braille calls pass on what the DLL answers and never raise; codepoints become UTF-8 bytes.
class SpeechInitTest < PokeAccessTest
  BACKEND_FILE = File.join(Harness::ROOT, "core", "speech", "backend.rb")
  FUNCTIONS = [:PEA_INIT, :PEA_SPEAK, :PEA_STOP, :PEA_PAUSE, :PEA_RESUME, :PEA_SPEAKING, :PEA_BRAILLE, :PEA_BACKEND]
  CONTROLS = { :stop_speech => :PEA_STOP, :pause_speech => :PEA_PAUSE, :resume_speech => :PEA_RESUME }
  # The bridge as the mod's loading leaves it, [up, start attempted], read when this file loads, before any test runs.
  AT_LOAD = [PokeAccess.speech_ready?, PokeAccess.instance_variable_get(:@init_attempted)]

  # A stand-in for one function of prism_pea.dll: gives its answers in turn and the last one from then on (:raise
  # raises), and keeps the arguments of every call.
  class DllFunction
    attr_reader :calls

    def initialize(*answers)
      @answers = answers
      @calls = []
    end

    def call(*args)
      @calls.push(args)
      answer = @answers.length > 1 ? @answers.shift : @answers.first
      raise "the DLL call failed" if answer == :raise
      answer
    end
  end

  test "loads with the bridge down and no start attempted yet" do
    assert_equal [false, false], AT_LOAD
  end

  test "a start the DLL refuses leaves the bridge down, with the failure logged for the diagnostic" do
    with_bridge(:PEA_INIT => DllFunction.new(0)) do
      assert_equal [false, false], [PokeAccess.init_speech!, PokeAccess.speech_ready?]
      assert_equal "PeaInitialize failed (no speech backend could start)", PokeAccess.logged["prism_init"]
    end
  end

  test "a failed start is not tried again until a retry" do
    init = DllFunction.new(0)
    with_bridge(:PEA_INIT => init) do
      PokeAccess.init_speech!
      assert_equal [false, 1], [PokeAccess.init_speech!, init.calls.length]
    end
  end

  test "a start the DLL accepts brings the bridge up once, with nothing logged" do
    init = DllFunction.new(1)
    with_bridge(:PEA_INIT => init) do
      assert_equal [true, true, true], [PokeAccess.init_speech!, PokeAccess.init_speech!, PokeAccess.speech_ready?]
      assert_equal 1, init.calls.length
      assert_nil PokeAccess.logged["prism_init"]
    end
  end

  test "a DLL without PeaInitialize leaves the bridge down" do
    with_bridge(:PEA_INIT => nil) do
      assert_equal [false, false], [PokeAccess.init_speech!, PokeAccess.speech_ready?]
    end
  end

  test "a start that raises in the DLL leaves the bridge down" do
    with_bridge(:PEA_INIT => DllFunction.new(:raise)) do
      assert_equal [false, false], [PokeAccess.init_speech!, PokeAccess.speech_ready?]
    end
  end

  test "a retry after a failed start tries the DLL again" do
    init = DllFunction.new(0, 1)
    with_bridge(:PEA_INIT => init) do
      PokeAccess.init_speech!
      assert_equal [true, true, 2], [PokeAccess.retry_init!, PokeAccess.speech_ready?, init.calls.length]
    end
  end

  test "a retry on a bridge that is up does not start it again" do
    init = DllFunction.new(1)
    with_bridge(:PEA_INIT => init) do
      PokeAccess.init_speech!
      assert_equal [true, 1], [PokeAccess.retry_init!, init.calls.length]
    end
  end

  test "hands each line to the reader with its end mark, cutting in or queued as asked" do
    speak = DllFunction.new(1)
    with_real_voice_out do
      with_bridge_up(:PEA_SPEAK => speak) do
        PokeAccess.voice_out("Hola", true)
        PokeAccess.voice_out("Adiós", false)
      end
    end
    assert_equal [["Hola\0", 1], ["Adiós\0", 0]], speak.calls
  end

  test "starts the bridge with the first line it hands over" do
    init = DllFunction.new(1)
    speak = DllFunction.new(1)
    with_real_voice_out do
      with_bridge(:PEA_INIT => init, :PEA_SPEAK => speak) do
        PokeAccess.voice_out("Hola", true)
        assert_equal [1, [["Hola\0", 1]]], [init.calls.length, speak.calls]
      end
    end
  end

  test "hands no line over while the bridge cannot start" do
    speak = DllFunction.new(1)
    with_real_voice_out do
      with_bridge(:PEA_INIT => DllFunction.new(0), :PEA_SPEAK => speak) { PokeAccess.voice_out("Hola", true) }
    end
    assert_equal [], speak.calls
  end

  test "a DLL without PeaSpeak takes no line and notes nothing" do
    with_real_voice_out do
      with_bridge_up(:PEA_SPEAK => nil) do
        assert_equal "", marked { PokeAccess.voice_out("Hola", true) }
      end
    end
  end

  test "a line the DLL fails to take is noted in the diagnostic marker, and the mod goes on" do
    with_real_voice_out do
      with_bridge_up(:PEA_SPEAK => DllFunction.new(:raise)) do
        noted = marked { PokeAccess.voice_out("Hola", true) }
        assert_match(/: speak_error: RuntimeError: the DLL call failed @ /, noted)
      end
    end
  end

  test "with the bridge up, stopping, pausing and resuming answer whether the DLL obeyed" do
    CONTROLS.each do |control, function|
      { 1 => true, 0 => false, :raise => false }.each do |answer, want|
        with_bridge_up(function => DllFunction.new(answer)) do
          assert_equal want, PokeAccess.send(control), "#{control} when the DLL answers #{answer.inspect}"
        end
      end
    end
  end

  test "with the bridge down, stopping, pausing and resuming answer false and leave the DLL alone" do
    CONTROLS.each do |control, function|
      dll = DllFunction.new(1)
      with_bridge(function => dll) do
        assert_equal [false, []], [PokeAccess.send(control), dll.calls], control.inspect
      end
    end
  end

  test "with the bridge up, speaking? says whether the reader still talks, or that it cannot tell" do
    { 1 => true, 0 => false, 4294967295 => nil, :raise => nil }.each do |answer, want|
      with_bridge_up(:PEA_SPEAKING => DllFunction.new(answer)) do
        got = PokeAccess.speaking?
        want.nil? ? assert_nil(got, answer.inspect) : assert_equal(want, got, answer.inspect)
      end
    end
  end

  test "with the bridge down, speaking? cannot tell and leaves the DLL alone" do
    dll = DllFunction.new(1)
    with_bridge(:PEA_SPEAKING => dll) do
      assert_nil PokeAccess.speaking?
      assert_equal [], dll.calls
    end
  end

  test "braille hands the text to the display and answers whether the DLL took it" do
    { 1 => true, 0 => false, :raise => false }.each do |answer, want|
      dll = DllFunction.new(answer)
      with_bridge_up(:PEA_BRAILLE => dll) do
        assert_equal [want, [["abc\0"]]], [PokeAccess.braille("abc"), dll.calls], "the DLL answers #{answer.inspect}"
      end
    end
  end

  test "braille hands nothing over for an empty or missing text" do
    dll = DllFunction.new(1)
    with_bridge_up(:PEA_BRAILLE => dll) do
      assert_equal [false, false, []], [PokeAccess.braille(""), PokeAccess.braille(nil), dll.calls]
    end
  end

  test "braille starts the bridge first, and hands nothing over when it cannot start" do
    { 1 => [true, [["abc\0"]]], 0 => [false, []] }.each do |start, want|
      dll = DllFunction.new(1)
      with_bridge(:PEA_INIT => DllFunction.new(start), :PEA_BRAILLE => dll) do
        assert_equal want, [PokeAccess.braille("abc"), dll.calls], "the start answers #{start}"
      end
    end
  end

  test "braille_codepoints hands the cells to the display as UTF-8" do
    dll = DllFunction.new(1)
    with_bridge_up(:PEA_BRAILLE => dll) do
      assert_equal true, PokeAccess.braille_codepoints([0x2801, 0x2803])
      assert_equal [[0xE2, 0xA0, 0x81, 0xE2, 0xA0, 0x83, 0x00]], dll.calls.map { |args| args[0].unpack("C*") }
    end
  end

  test "with the bridge up, names the backend the DLL reports, or none when it reports none or the call raises" do
    { "NVDA" => "NVDA", nil => "", :raise => "" }.each do |answer, want|
      with_bridge_up(:PEA_BACKEND => DllFunction.new(answer)) do
        assert_equal want, PokeAccess.speech_backend, answer.inspect
      end
    end
  end

  test "with the bridge down, names no backend and leaves the DLL alone" do
    dll = DllFunction.new("NVDA")
    with_bridge(:PEA_BACKEND => dll) do
      assert_equal ["", []], [PokeAccess.speech_backend, dll.calls]
    end
  end

  test "a DLL lacking a function answers that call's safe value with the bridge up" do
    with_bridge_up(:PEA_STOP => nil, :PEA_PAUSE => nil, :PEA_RESUME => nil, :PEA_SPEAKING => nil,
                   :PEA_BRAILLE => nil, :PEA_BACKEND => nil) do
      assert_equal [false, false, false, nil, false, ""],
                   [PokeAccess.stop_speech, PokeAccess.pause_speech, PokeAccess.resume_speech, PokeAccess.speaking?,
                    PokeAccess.braille("abc"), PokeAccess.speech_backend]
    end
  end

  test "encodes every codepoint of the Basic Multilingual Plane as UTF-8 does" do
    wrong = (0..0xFFFF).reject { |cp| PokeAccess.codepoints_to_utf8([cp]) == [cp].pack("U").b }
    assert_equal [], wrong.first(5)
  end

  test "encodes a run of codepoints in turn" do
    assert_equal [0xE2, 0xA0, 0x81, 0x20, 0xE2, 0xA0, 0x83],
                 PokeAccess.codepoints_to_utf8([0x2801, 0x20, 0x2803]).unpack("C*")
  end

  test "skips a codepoint that is missing, negative or past the plane" do
    assert_equal "ab", PokeAccess.codepoints_to_utf8([0x61, nil, -1, 0x10000, 0x1F600, 0x62])
  end

  private

  # Runs the block with every function of the DLL replaced: by the stand-in given for it (nil for one the DLL lacks),
  # the rest by stand-ins answering 0; the bridge down, no start attempted and no failed start logged. The real
  # functions, the bridge's state and the diagnostic's log are put back after.
  def with_bridge(functions = {})
    real = FUNCTIONS.map { |name| [name, PokeAccess.const_get(name)] }
    state = [PokeAccess.instance_variable_get(:@ready), PokeAccess.instance_variable_get(:@init_attempted)]
    log = PokeAccess.instance_variable_get(:@logged_once)
    FUNCTIONS.each { |name| set_function(name, functions.key?(name) ? functions[name] : DllFunction.new(0)) }
    PokeAccess.instance_variable_set(:@ready, false)
    PokeAccess.instance_variable_set(:@init_attempted, false)
    PokeAccess.instance_variable_set(:@logged_once, (log || {}).reject { |key, _line| key == "prism_init" })
    yield
  ensure
    real.each { |name, function| set_function(name, function) } if real
    PokeAccess.instance_variable_set(:@ready, state[0]) if state
    PokeAccess.instance_variable_set(:@init_attempted, state[1]) if state
    PokeAccess.instance_variable_set(:@logged_once, log)
  end

  # Runs the block as with_bridge, with the bridge started first.
  def with_bridge_up(functions = {})
    with_bridge({ :PEA_INIT => DllFunction.new(1) }.merge(functions)) do
      PokeAccess.init_speech!
      yield
    end
  end

  # Sets the DLL function the bridge calls under name.
  def set_function(name, function)
    PokeAccess.send(:remove_const, name)
    PokeAccess.const_set(name, function)
  end

  # Runs the block with voice_out as core/speech/backend.rb defines it in place of the harness's capture, evaluated
  # from the file under another name so the file's coverage stays its own; the capture is put back after.
  def with_real_voice_out
    capture = PokeAccess.method(:voice_out)
    src = Harness.source(BACKEND_FILE)
    from = src.index("  def self.voice_out(")
    PokeAccess.module_eval(src[from..(src.index("\n  end\n", from) + 5)], "backend.rb voice_out")
    yield
  ensure
    PokeAccess.define_singleton_method(:voice_out, capture)
  end

  # What the block appended to the mod's diagnostic marker file.
  def marked
    size = File.file?(PokeAccess.marker_file) ? File.size(PokeAccess.marker_file) : 0
    yield
    File.file?(PokeAccess.marker_file) ? File.binread(PokeAccess.marker_file)[size..-1].to_s : ""
  end
end
