# The keyboard's picture, one per pulse: a press is the frame a key goes down, the same for every reader that frame; a
# key held through a screen with its own loop is no new press when the map asks again; a consumed press is taken once;
# a chord fires on the frame it completes; and a key is down while GetAsyncKeyState sets its high bit.
class KeyboardTest < PokeAccessTest
  Keyboard = PokeAccess::Keyboard
  K = 0x4B
  L = 0x4C
  ENTER = 0x0D
  # A game window's handle, its thread's id and its keyboard layout, as the stand-ins of game_layout answer them.
  GAME_HWND = 0x5150
  GAME_THREAD = 77
  GAME_HKL = 0x080A080A

  test "a key is pressed only on the frames it goes down" do
    got = with_keys { [[], [K], [K], [], [K]].map { |held| frame(*held); Keyboard.pressed?(K) } }
    assert_equal [false, true, false, false, true], got
  end

  test "every reader of a frame sees the same press" do
    got = with_keys do
      frame
      frame(K)
      [Keyboard.pressed?(K), Keyboard.pressed?(K)]
    end
    assert_equal [true, true], got
  end

  test "a held key is down on every frame it is held, and up once let go" do
    got = with_keys { [[K], [K], []].map { |held| frame(*held); Keyboard.down?(K) } }
    assert_equal [true, true, false], got
  end

  test "a key held through a screen's own loop is no press when the map asks again" do
    got = with_keys do
      frame
      Keyboard.pressed?(L)
      3.times { frame(L) }
      Keyboard.pressed?(L)
    end
    assert_equal false, got
  end

  test "a consumed press is gone for the later readers of its frame, though the key is down" do
    got = with_keys do
      frame
      frame(ENTER)
      Keyboard.consume(ENTER)
      [Keyboard.pressed?(ENTER), Keyboard.down?(ENTER)]
    end
    assert_equal [false, true], got
  end

  test "after a consumed press, the next press is a new one" do
    got = with_keys do
      frame
      frame(ENTER)
      Keyboard.consume(ENTER)
      frame
      frame(ENTER)
      Keyboard.pressed?(ENTER)
    end
    assert_equal true, got
  end

  # A screen takes a key's press before any reader asked about the key (the randomizer's Enter opening a field).
  test "a key taken before anyone asked about it is held, not pressed, on the next frames" do
    got = with_keys do
      never_asked(ENTER)
      frame(ENTER)
      Keyboard.consume(ENTER)
      frame(ENTER)
      held = Keyboard.pressed?(ENTER)
      frame
      frame(ENTER)
      [held, Keyboard.pressed?(ENTER)]
    end
    assert_equal [false, true], got
  end

  test "a chord fires on the frame it completes, whichever key comes last, and not again while held" do
    c = Keyboard::VK_CONTROL
    a = Keyboard::VK_ALT
    f = Keyboard::VK_F8
    got = with_keys do
      [[c, a], [c, a, f], [c, a, f], [a, f], [c, a, f]].map { |held| frame(*held); Keyboard.chord_pressed?(c, a, f) }
    end
    assert_equal [false, true, false, false, true], got
  end

  test "the global chords' keys are Windows' virtual keys for Ctrl, Alt, F8, F9 and F10" do
    got = [Keyboard::VK_CONTROL, Keyboard::VK_ALT, Keyboard::VK_F8, Keyboard::VK_F9, Keyboard::VK_F10]
    assert_equal [0x11, 0x12, 0x77, 0x78, 0x79], got
  end

  test "a key is down while GetAsyncKeyState sets its high bit, whatever its low bit says" do
    states = { 0x8000 => true, 0x8001 => true, -32768 => true, -32767 => true, 0x0001 => false, 0 => false }
    states.each { |state, down| assert_equal down, async_state(state) { Keyboard.raw_down?(K) }, "for state #{state}" }
  end

  test "the character a key types is the active layout's, a dead key's accent too, and none where it types none" do
    got = typing(0xBC => 0x2C, 0xC0 => 0xF1, 0xDE => 0xB4 - 0x80000000) do
      [0xBC, 0xC0, 0xDE, 0x6C].map { |vk| Keyboard.char_code(vk) }
    end
    assert_equal [0x2C, 0xF1, 0xB4, nil], got
  end

  test "the character a key types is the game window's thread's layout's, the mod's own thread's where that fails" do
    got = typing(0xBC => 0x2C) do
      [game_layout(0xBC => 0x3B) { Keyboard.char_code(0xBC) }, game_layout(0xBC => 0x3B) { Keyboard.char_code(0xDE) },
       game_layout({ 0xBC => 0x3B }, 0) { Keyboard.char_code(0xBC) }, Keyboard.char_code(0xBC)]
    end
    assert_equal [0x3B, nil, 0x2C, 0x2C], got
  end

  private

  # The block's value with the game window known (Focus.hwnd), its thread's layout (GetKeyboardLayout) hkl and
  # MapVirtualKeyExW answering in that layout what chars gives a virtual key (0 for the rest); all put back after.
  def game_layout(chars, hkl = GAME_HKL)
    real = []
    thread = Object.new
    thread.define_singleton_method(:call) { |h, _pid| h == GAME_HWND ? GAME_THREAD : 0 }
    layout = Object.new
    layout.define_singleton_method(:call) { |tid| tid == GAME_THREAD ? hkl : 0 }
    ex = Object.new
    ex.define_singleton_method(:call) { |vk, type, k| type == 2 && k == GAME_HKL ? (chars[vk] || 0) : 0 }
    stubs = [[PokeAccess::Focus, :GWTPID, thread], [Keyboard, :GKL, layout], [Keyboard, :MVK_CHAR_EX, ex]]
    stubs.each { |mod, name, fake| real.push([mod, name, swap_const(mod, name, fake)]) }
    was = PokeAccess::Focus.hwnd
    PokeAccess::Focus.instance_variable_set(:@game_hwnd, GAME_HWND)
    yield
  ensure
    PokeAccess::Focus.instance_variable_set(:@game_hwnd, was)
    real.each { |mod, name, value| swap_const(mod, name, value) }
  end

  # Sets mod's constant name to value, answering the one it held.
  def swap_const(mod, name, value)
    held = mod.const_get(name)
    mod.send(:remove_const, name)
    mod.const_set(name, value)
    held
  end

  # The block's value with MapVirtualKey answering, for a virtual key to its character (MAPVK_VK_TO_CHAR), what chars
  # gives it (0 for the rest); the real one put back after.
  def typing(chars)
    fake = Object.new
    fake.define_singleton_method(:call) { |vk, type| type == 2 ? (chars[vk] || 0) : 0 }
    real = Keyboard::MVK_CHAR
    Keyboard.send(:remove_const, :MVK_CHAR)
    Keyboard.const_set(:MVK_CHAR, fake)
    yield
  ensure
    Keyboard.send(:remove_const, :MVK_CHAR)
    Keyboard.const_set(:MVK_CHAR, real)
  end

  # The block's value with the raw keyboard read from the keys frame holds down, the real reading put back and the
  # picture left blank after.
  def with_keys
    @held = {}
    held = @held
    sc = Keyboard.singleton_class
    sc.send(:alias_method, :keyboard_test_raw_down, :raw_down?)
    Keyboard.define_singleton_method(:raw_down?) { |vk| held[vk] ? true : false }
    yield
  ensure
    if sc && sc.method_defined?(:keyboard_test_raw_down)
      sc.send(:alias_method, :raw_down?, :keyboard_test_raw_down)
      sc.send(:remove_method, :keyboard_test_raw_down)
    end
    2.times { Keyboard.snapshot }
  end

  # One frame: the keys held down in it, then the picture the pulse takes.
  def frame(*vks)
    @held.clear
    vks.each { |vk| @held[vk] = true }
    Keyboard.snapshot
  end

  # Leaves vk out of the keyboard's picture, as a key no reader has asked about yet.
  def never_asked(vk)
    Keyboard.instance_variable_get(:@now).delete(vk)
    Keyboard.instance_variable_get(:@prev).delete(vk)
  end

  # The block's value with GetAsyncKeyState answering state for every key, its own answer put back after.
  def async_state(state)
    gaks = Keyboard::GAKS
    sc = gaks.singleton_class
    was = sc.instance_methods(false).include?(:call) ? gaks.method(:call) : nil
    gaks.define_singleton_method(:call) { |*_a| state }
    yield
  ensure
    if was
      gaks.define_singleton_method(:call, was)
    elsif sc && sc.instance_methods(false).include?(:call)
      sc.send(:remove_method, :call)
    end
  end
end
