require "tmpdir"
require "fileutils"

# mkxp-z's F1 bindings (keybindings.mkxp1 in its data directory): the file read as each standard button's keyboard
# keys, its SDL scancodes as Windows virtual keys, and the hints saying the key F1 put a button on, unless the mod's
# own rebind goes first or the game reads the keyboard itself.
class NativeKeysTest < PokeAccessTest
  NK = PokeAccess::NativeKeys
  KeyHints = PokeAccess::KeyHints
  RGSS = PokeAccess::KeyHints::RGSS_LETTERS

  # A player's real F1 layout in Pokemon Z, as [button, source type, code]: movement on WASD, the X button on F, Y on
  # R, Z on C, L on Z, R on X, A on G and H (and a pad button), B on Escape, numpad 0 and Q, C on Space, Enter and E.
  Z_LAYOUT = [[11, 1, 10], [11, 1, 11], [11, 2, 3], [12, 1, 41], [12, 1, 98], [12, 1, 20], [13, 1, 44], [13, 1, 40],
              [13, 1, 8], [14, 1, 9], [15, 1, 21], [16, 1, 6], [17, 1, 29], [18, 1, 27], [8, 1, 26], [2, 1, 22],
              [4, 1, 4], [6, 1, 7]].freeze

  # That layout's keys by the mod's action, in the file's order.
  Z_KEYS = { :a => [0x47, 0x48], :b => [0x1B, 0x60, 0x51], :c => [0x20, 0x0D, 0x45], :x => [0x46], :y => [0x52],
             :z => [0x43], :l => [0x5A], :r => [0x58] }.freeze

  # Named keys as SDL numbers them (SDL_scancode.h) and as Windows does (WinUser.h): Return, Escape, Backspace, Tab,
  # Space, the punctuation keys, Caps Lock, the editing and arrow keys, the numpad's operators, Enter, 0 and point,
  # and both sides' Ctrl, Shift and Alt.
  NAMED_KEYS = { 40 => 0x0D, 41 => 0x1B, 42 => 0x08, 43 => 0x09, 44 => 0x20, 45 => 0xBD, 46 => 0xBB, 47 => 0xDB,
                 48 => 0xDD, 49 => 0xDC, 51 => 0xBA, 52 => 0xDE, 53 => 0xC0, 54 => 0xBC, 55 => 0xBE, 56 => 0xBF,
                 57 => 0x14, 73 => 0x2D, 74 => 0x24, 75 => 0x21, 76 => 0x2E, 77 => 0x23, 78 => 0x22, 79 => 0x27,
                 80 => 0x25, 81 => 0x28, 82 => 0x26, 84 => 0x6F, 85 => 0x6A, 86 => 0x6D, 87 => 0x6B, 88 => 0x0D,
                 98 => 0x60, 99 => 0x6E, 224 => 0x11, 225 => 0x10, 226 => 0x12, 228 => 0x11, 229 => 0x10,
                 230 => 0x12 }.freeze

  # Two keyboard layouts the game window's thread may be on (GetKeyboardLayout's handles).
  GAME_HKL = 0x040C040C
  OTHER_HKL = 0x04070407

  test "reads each standard button's keyboard keys in the file's order, leaving out pad buttons and directions" do
    assert_equal Z_KEYS, NK.parse(native_keys_file(Z_LAYOUT))
  end

  test "a key bound twice to a button counts once" do
    assert_equal({ :x => [0x46] }, NK.parse(native_keys_file([[14, 1, 9], [14, 1, 9]])))
  end

  test "an empty file, or one cut short, has no bindings" do
    ["", native_keys_file(Z_LAYOUT)[0, 40]].each do |data|
      assert_equal({}, NK.parse(data), "for #{data.bytesize} bytes")
    end
  end

  test "reads letters, digits, function keys and the numpad's digits as Windows numbers them, at both ends" do
    { 3 => nil, 4 => 0x41, 29 => 0x5A, 30 => 0x31, 38 => 0x39, 39 => 0x30, 58 => 0x70, 69 => 0x7B, 70 => nil,
      89 => 0x61, 97 => 0x69 }.each do |sc, vk|
      vk ? assert_equal(vk, NK.vk_of(sc), "scancode #{sc}") : assert_nil(NK.vk_of(sc), "scancode #{sc}")
    end
  end

  test "reads the other named keys as Windows numbers them" do
    assert_equal({}, NAMED_KEYS.reject { |sc, vk| NK.vk_of(sc) == vk })
  end

  test "a key whose name follows the keyboard layout is read as the active layout has it, as F1 names it" do
    azerty = { 0x10 => 0x41, 0x1E => 0x51, 0x27 => 0x4D }
    assert_equal [0x41, 0x51, 0x4D, 0x0D], with_layout(azerty) { [20, 4, 51, 40].map { |sc| NK.vk_of(sc) } }
  end

  test "where Windows maps no scancode through the layout, a key is read as a US keyboard has it" do
    assert_equal [0x51, 0xBA], with_layout({}) { [20, 51].map { |sc| NK.vk_of(sc) } }
  end

  test "a key is read as the game window's layout has it, the mod thread's where that one says none or is unknown" do
    got = with_layout(0x10 => 0x41, 0x27 => 0x4D) do
      with_window_layouts(GAME_HKL => { 0x10 => 0x5A }) do |switch_to|
        switch_to.call(GAME_HKL)
        in_game = [20, 51].map { |sc| NK.vk_of(sc) }
        switch_to.call(nil)
        [in_game, [20, 51].map { |sc| NK.vk_of(sc) }]
      end
    end
    assert_equal [[0x5A, 0x4D], [0x41, 0x4D]], got
  end

  test "the file is read again when the game window's keyboard layout changes" do
    got = with_mkxp([[14, 1, 20]]) do
      with_window_layouts(GAME_HKL => { 0x10 => 0x51 }, OTHER_HKL => { 0x10 => 0x4B }) do |switch_to|
        switch_to.call(GAME_HKL)
        first = KeyHints.localize("[A] Curar", RGSS)
        switch_to.call(OTHER_HKL)
        [first, KeyHints.localize("[A] Curar", RGSS)]
      end
    end
    assert_equal ["[Q] Curar", "[K] Curar"], got
  end

  test "with the file there, there is something to go by; without it, nothing" do
    assert_equal [true, false], [with_mkxp(Z_LAYOUT) { NK.active? }, with_mkxp(nil) { NK.active? }]
  end

  test "outside mkxp-z, with no data directory to name, there is no file to read" do
    [nil, ""].each do |dir|
      assert_nil with_data_directory(dir) { NK.path }, "for #{dir.inspect}"
    end
  end

  test "a file it cannot read gives nothing to go by" do
    got = with_mkxp(nil) do |file|
      Dir.mkdir(file)
      NK.active?
    end
    assert_equal false, got
  end

  test "a hint says the key F1 put its button on" do
    got = with_mkxp(Z_LAYOUT) { [KeyHints.localize("[A] Curar", RGSS), KeyHints.localize("C/X: Salir", RGSS)] }
    assert_equal ["[F] Curar", "E/Q: Salir"], got
  end

  test "a button is said by a letter first among its keys, else a key that is no modifier, else its first" do
    [[[[13, 1, 44], [13, 1, 4]], "A"],
     [[[13, 1, 44], [13, 1, 29]], "Z"],
     [[[13, 1, 225], [13, 1, 44]], t(:key_space)],
     [[[13, 1, 225]], t(:key_shift)]].each do |layout, said|
      assert_equal said, with_mkxp(layout) { NK.name(:c, "C") }, "for #{layout.inspect}"
    end
  end

  test "a painted key the button still has is kept, so the title still asks for Enter" do
    enter = t(:key_enter)
    assert_equal [nil, enter], with_mkxp(Z_LAYOUT) { [NK.name(:c, enter), KeyHints.key(:c, enter)] }
  end

  test "a button the file leaves out keeps its painted key" do
    assert_nil with_mkxp([[14, 1, 9]]) { NK.name(:y, "S") }
  end

  test "the mod's own rebind wins over F1" do
    PokeAccess::Config.rebinds = { :x => 0x4A }
    assert_equal "[J] Curar", with_mkxp(Z_LAYOUT) { KeyHints.localize("[A] Curar", RGSS) }
  end

  test "the file is read again when it changes" do
    got = with_mkxp(Z_LAYOUT) do |file|
      first = KeyHints.localize("[A] Curar", RGSS)
      File.binwrite(file, native_keys_file([[14, 1, 225], [14, 1, 98]]))
      File.utime(Time.now + 5, Time.now + 5, file)
      [first, KeyHints.localize("[A] Curar", RGSS)]
    end
    assert_equal ["[F] Curar", "[#{t(:key_numpad, :n => 0)}] Curar"], got
  end

  test "a game that reads the keyboard itself never sees F1, and its hints stay as painted" do
    got = with_mkxp(Z_LAYOUT) { reading_keyboard_itself { [NK.active?, KeyHints.localize("[A] Curar", RGSS)] } }
    assert_equal [false, "[A] Curar"], got
  end

  private

  # Runs the block with MapVirtualKey answering, for a scan code to a virtual key (MAPVK_VSC_TO_VK), what keys gives
  # it (0 for the rest), as the active keyboard layout would; put back after.
  def with_layout(keys)
    fake = Object.new
    fake.define_singleton_method(:call) { |code, type| type == 1 ? (keys[code] || 0) : 0 }
    real = NK::MVK
    NK.send(:remove_const, :MVK)
    NK.const_set(:MVK, fake)
    yield
  ensure
    NK.send(:remove_const, :MVK)
    NK.const_set(:MVK, real)
  end

  # Runs the block with the game window's thread on the keyboard layout the block's argument switches to
  # (Keyboard.window_layout, nil for none) and MapVirtualKeyEx answering in each of layouts, {layout => {scan code =>
  # virtual key}}, what it puts on a scan code (0 for the rest); put back after.
  def with_window_layouts(layouts)
    now = [nil]
    fake = Object.new
    fake.define_singleton_method(:call) { |code, type, hkl| type == 1 ? ((layouts[hkl] || {})[code] || 0) : 0 }
    real = NK::MVK_EX
    NK.send(:remove_const, :MVK_EX)
    NK.const_set(:MVK_EX, fake)
    answering(PokeAccess::Keyboard, :window_layout, proc { now[0] }) { yield(lambda { |hkl| now[0] = hkl }) }
  ensure
    NK.send(:remove_const, :MVK_EX)
    NK.const_set(:MVK_EX, real)
  end

  # A keybindings.mkxp1 as mkxp-z writes it: three words of header, then [source type, code, unused, button] per
  # binding, from [button, source type, code] triples.
  def native_keys_file(bindings)
    words = [2, 1, bindings.length]
    bindings.each { |b, t, c| words.concat([t, c, 0, b]) }
    words.pack("V*")
  end

  # A mod text in the language under test.
  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # The block's value with mkxp-z's data directory a fresh folder holding a keybindings.mkxp1 of bindings (no file
  # for nil), given the file's path; what NativeKeys read is forgotten before and after.
  def with_mkxp(bindings)
    dir = Dir.mktmpdir("native-keys")
    file = File.join(dir, "keybindings.mkxp1")
    File.binwrite(file, native_keys_file(bindings)) if bindings
    with_data_directory(dir) { yield file }
  ensure
    FileUtils.rm_rf(dir) if dir
  end

  # The block's value with System.data_directory answering dir, System put back as it was after; what NativeKeys
  # read is forgotten before and after.
  def with_data_directory(dir)
    made = !defined?(::System)
    Object.const_set(:System, Module.new) if made
    answering(::System, :data_directory, proc { dir }) do
      NK.reset
      yield
    end
  ensure
    Object.send(:remove_const, :System) if made && defined?(::System)
    NK.reset
  end

  # The block's value with the game's Input defining getstate, as a game that reads the keyboard itself does.
  def reading_keyboard_itself
    answering(Input, :getstate, proc { |_k| false }) do
      NK.reset
      yield
    end
  ensure
    NK.reset
  end

  # The block's value with obj's meth answering as body does; the method obj had of its own, if any, put back after.
  def answering(obj, meth, body)
    sc = obj.singleton_class
    own = sc.instance_methods(false).include?(meth) || sc.private_instance_methods(false).include?(meth)
    was = own ? obj.method(meth) : nil
    obj.define_singleton_method(meth, &body)
    yield
  ensure
    if was
      obj.define_singleton_method(meth, was)
    elsif sc && sc.instance_methods(false).include?(meth)
      sc.send(:remove_method, meth)
    end
  end
end
