# The clipboard's UTF-8 halves match Ruby's own at every width, a cut-short lead byte kept as itself; set_text copies
# through mkxp-z's clipboard, else Windows' as UTF-16, freeing what Windows has not taken, and never raises.
class CodepointsTest < PokeAccessTest
  Clipboard = PokeAccess::Clipboard
  # Codepoints at both edges of each UTF-8 width and with every bit the encoder masks set and clear, plus a text that
  # changes width at each character.
  SAMPLES = {
    "one byte" => [0x00, 0x41, 0x7F],
    "two bytes" => [0x80, 0xE0, 0xE1, 0xF1, 0x7FF],
    "three bytes" => [0x800, 0x76F8, 0x68D2, 0xFFFF],
    "four bytes" => [0x10000, 0x1F600, 0x40000, 0x10FFFF],
    "mixed widths" => [72, 0xF3, 0x1F600, 0x76F8, 33]
  }.freeze
  # The Win32 calls in the order a copy makes them.
  COPY_STEPS = [:alloc, :lock, :copy, :unlock, :open, :empty, :set, :close].freeze
  # Windows' own values for movable global memory and the Unicode text clipboard format.
  GMEM_MOVEABLE = 0x0002
  CF_UNICODETEXT = 13

  test "encodes codepoints as Ruby's own UTF-8" do
    SAMPLES.each { |label, cps| assert_equal cps.pack("U*").b, Clipboard.utf8(cps).b, label }
  end

  test "decodes Ruby's own UTF-8 back into its codepoints" do
    SAMPLES.each { |label, cps| assert_equal cps, Clipboard.codepoints_of(cps.pack("U*")), label }
  end

  test "keeps a lead byte with too few bytes after it as itself and decodes on from the next byte" do
    { [0xC3] => [0xC3], [0x61, 0xC3] => [0x61, 0xC3], [0xE2, 0x82] => [0xE2, 0x82], [0xF0, 0x9F] => [0xF0, 0x9F],
      [0xF0, 0x9F, 0x98] => [0xF0, 0x7D8] }.each do |bytes, cps|
      assert_equal cps, Clipboard.codepoints_of(bytes.pack("C*")), "for #{bytes.inspect}"
    end
  end

  test "copies a text through mkxp-z's clipboard as UTF-8" do
    got = []
    with_game_clipboard(lambda { |text| got.push(text) }) do
      assert_equal true, Clipboard.set_text("Pokémon ñ 😀")
    end
    assert_equal ["Pokémon ñ 😀".b], got.map { |t| t.b }
  end

  test "writes Windows' clipboard as UTF-16 Unicode text, a surrogate pair above U+FFFF, when the game has none" do
    copied = "A€😁\u{FFFF}\u{10000}"
    calls = []
    with_win32(calls) { assert_equal true, Clipboard.set_text(copied) }
    text = (copied.encode("UTF-16LE") + "\u0000".encode("UTF-16LE")).b
    assert_equal [[:alloc, GMEM_MOVEABLE, 16], [:lock, 40], [:copy, 80, text, 16], [:unlock, 40], [:open, 0], [:empty],
                  [:set, CF_UNICODETEXT, 40], [:close]], calls
  end

  test "falls back to Windows' clipboard when mkxp-z's raises" do
    calls = []
    with_game_clipboard(lambda { |_text| raise IOError, "no clipboard" }) do
      with_win32(calls) { assert_equal true, Clipboard.set_text("x") }
    end
    assert_equal COPY_STEPS, calls.map { |c| c[0] }
  end

  test "frees the memory and answers false when a Windows step fails before the system owns it" do
    { :alloc => [:alloc],
      :lock => [:alloc, :lock, :free],
      :open => [:alloc, :lock, :copy, :unlock, :open, :free],
      :set => [:alloc, :lock, :copy, :unlock, :open, :empty, :set, :free, :close] }.each do |failing, steps|
      calls = []
      with_win32(calls, failing) { assert_equal false, Clipboard.set_text("x"), "#{failing} failing" }
      assert_equal steps, calls.map { |c| c[0] }, "#{failing} failing"
      assert_equal [:free, 40], calls.assoc(:free), "#{failing} failing frees the handle" if steps.include?(:free)
    end
  end

  test "answers false with neither clipboard to write" do
    with_win32(nil) { assert_equal false, Clipboard.set_text("x") }
  end

  test "answers false when a Windows call raises, giving up at it" do
    calls = []
    with_win32(calls, nil, :lock) { assert_equal false, Clipboard.set_text("x") }
    assert_equal [:alloc, :lock], calls.map { |c| c[0] }
  end

  test "answers false for a text it cannot have" do
    broken = Object.new
    def broken.to_s; raise "no text"; end
    calls = []
    with_win32(calls) { assert_equal false, Clipboard.set_text(broken) }
    assert_equal [], calls, "nothing reached Windows"
  end

  private

  # Runs the block with mkxp-z's Input.clipboard= handing what is written to accept (which may raise); the engine's own
  # comes back after, or none.
  def with_game_clipboard(accept)
    meta = Input.singleton_class
    had = meta.method_defined?(:clipboard=, false) ? Input.method(:clipboard=) : nil
    Input.define_singleton_method(:clipboard=) { |text| accept.call(text) }
    yield
  ensure
    had ? Input.define_singleton_method(:clipboard=, had) : meta.send(:remove_method, :clipboard=)
  end

  # Runs the block with the Win32 clipboard calls answered by fakes that log [name, *args] into calls, the step named
  # failing answering 0 and the one named raising raising; nil for calls leaves the API unloaded. The real calls come
  # back after.
  def with_win32(calls, failing = nil, raising = nil)
    saved = Clipboard.instance_variable_get(:@api)
    answers = { :alloc => 40, :lock => 80, :copy => nil, :unlock => 1, :open => 1, :empty => 1, :set => 7,
                :close => 1, :free => 0 }
    fake = lambda do |name|
      lambda do |*args|
        calls.push([name, *args])
        raise IOError, "the call fails" if name == raising
        name == failing ? 0 : answers[name]
      end
    end
    Clipboard.instance_variable_set(:@api, calls && Hash[answers.keys.map { |name| [name, fake.call(name)] }])
    yield
  ensure
    Clipboard.instance_variable_set(:@api, saved)
  end
end
