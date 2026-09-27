require "tmpdir"
require "fileutils"

# A keybindings.mkxp1 as mkxp-z writes it: three words of header, then [source type, code, unused, button] per
# binding. bindings: [[button, type, code], ...]
def native_keys_file(bindings)
  words = [2, 1, bindings.length]
  bindings.each { |b, t, c| words.concat([t, c, 0, b]) }
  words.pack("V*")
end

# A player's real F1 layout in Pokemon Z: movement on WASD, the X button on F, Y on R, Z on C, L on Z, R on X,
# A on G and H, B on Escape, numpad 0 and Q, C on Space, Enter and E; a pad button on A besides.
NATIVE_KEYS_Z = [[11, 1, 10], [11, 1, 11], [11, 2, 3], [12, 1, 41], [12, 1, 98], [12, 1, 20], [13, 1, 44],
                 [13, 1, 40], [13, 1, 8], [14, 1, 9], [15, 1, 21], [16, 1, 6], [17, 1, 29], [18, 1, 27],
                 [8, 1, 26], [2, 1, 22], [4, 1, 4], [6, 1, 7]]

# The file's words become the buttons' keys: only keyboard sources, only the standard buttons, each key once,
# and a file cut short is no file at all.
Suite.define("native keys: a keybindings.mkxp1 read as the keys of each button") do
  nk = PokeAccess::NativeKeys
  t = nk.parse(native_keys_file(NATIVE_KEYS_Z))
  eq "the X button on F", t[:x], [0x46]
  eq "A on G and H, the pad button left out", t[:a], [0x47, 0x48]
  eq "C on Space, Enter and E, in the file's order", t[:c], [0x20, 0x0D, 0x45]
  eq "B on Escape, numpad 0 and Q", t[:b], [0x1B, 0x60, 0x51]
  falsy "directions are not asked for", t.key?(:up) || t.values.flatten.include?(0x57)
  eq "a key bound twice counts once", nk.parse(native_keys_file([[14, 1, 9], [14, 1, 9]]))[:x], [0x46]
  eq "a file cut short is nothing", nk.parse(native_keys_file(NATIVE_KEYS_Z)[0, 40]), {}
  eq "scancodes as virtual keys: letter, digit, zero, F1, space, numpad 1, left shift",
     [nk.vk_of(4), nk.vk_of(30), nk.vk_of(39), nk.vk_of(58), nk.vk_of(44), nk.vk_of(89), nk.vk_of(225)],
     [0x41, 0x31, 0x30, 0x70, 0x20, 0x61, 0x10]
end

# A hint names the key F1 put its button on, where mkxp-z answers the game's input; a key the game paints that
# still works is kept, the mod's own rebind still wins, and a game that reads the keyboard itself is left as it is.
Suite.define("native keys: the hints say the key F1 put each button on") do
  nk = PokeAccess::NativeKeys
  kh = PokeAccess::KeyHints
  cm = PokeAccess::ConfigMenu
  rgss = kh::RGSS_LETTERS
  dir = Dir.mktmpdir
  defined_system = !defined?(::System)
  Object.const_set(:System, Module.new) if defined_system
  ::System.instance_variable_set(:@native_keys_dir, dir)
  def System.data_directory; @native_keys_dir; end
  was = PokeAccess::Config.rebinds
  PokeAccess::Config.rebinds = {}
  file = File.join(dir, "keybindings.mkxp1")
  File.open(file, "wb") { |f| f.write(native_keys_file(NATIVE_KEYS_Z)) }
  nk.reset
  truthy "with the file there, there is something to go by", nk.active?
  eq "the X button's hint says F", kh.localize("[A] Curar", rgss), "[F] Curar"
  eq "a label line, both keys moved", kh.localize("C/X: Salir", rgss), "E/Q: Salir"
  eq "a letter first among the button's keys", nk.name(:c, "C"), "E"
  eq "a painted key the button still has is kept", nk.name(:c, cm.keyname(0x0D)), nil
  eq "so the title still asks for Enter", kh.key(:c, cm.keyname(0x0D)), cm.keyname(0x0D)
  PokeAccess::Config.rebinds = { :x => 0x4A }
  eq "the mod's own rebind wins over F1", kh.localize("[A] Curar", rgss), "[J] Curar"
  PokeAccess::Config.rebinds = {}
  File.open(file, "wb") { |f| f.write(native_keys_file([[14, 1, 225], [14, 1, 98]])) }
  File.utime(Time.now + 5, Time.now + 5, file)
  eq "the file is read again when it changes, and a modifier is said last",
     kh.localize("[A] Curar", rgss), "[#{cm.keyname(0x60)}] Curar"
  def Input.getstate(_k); false; end
  nk.reset
  falsy "a game that reads the keyboard itself never sees F1", nk.active?
  eq "and its hints stay as painted", kh.localize("[A] Curar", rgss), "[A] Curar"
ensure
  (class << Input; remove_method :getstate; end) if Input.respond_to?(:getstate)
  Object.send(:remove_const, :System) if defined_system && defined?(::System)
  PokeAccess::Config.rebinds = was
  nk.reset
  FileUtils.rm_rf(dir) if dir
end
