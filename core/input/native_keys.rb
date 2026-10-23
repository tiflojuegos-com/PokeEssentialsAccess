module PokeAccess
  # The keys mkxp-z's F1 menu gave each button (keybindings.mkxp1 in its data directory); only for games that leave
  # input to mkxp-z, not those whose Input defines getstate.
  module NativeKeys
    # The file's button numbers for the standard buttons (mkxp-z's Input::ButtonCode), as the mod's actions.
    BUTTON_OF = { 11 => :a, 12 => :b, 13 => :c, 14 => :x, 15 => :y, 16 => :z, 17 => :l, 18 => :r }

    # An entry's source type for a keyboard key; the others are pad buttons, axes and hats.
    KEYBOARD = 1

    # SDL scancodes as Windows virtual keys, for the names the mod gives keys everywhere else.
    SCANCODE_VK = {
      40 => 0x0D, 41 => 0x1B, 42 => 0x08, 43 => 0x09, 44 => 0x20, 45 => 0xBD, 46 => 0xBB, 47 => 0xDB,
      48 => 0xDD, 49 => 0xDC, 51 => 0xBA, 52 => 0xDE, 53 => 0xC0, 54 => 0xBC, 55 => 0xBE, 56 => 0xBF,
      57 => 0x14, 73 => 0x2D, 74 => 0x24, 75 => 0x21, 76 => 0x2E, 77 => 0x23, 78 => 0x22, 79 => 0x27,
      80 => 0x25, 81 => 0x28, 82 => 0x26, 84 => 0x6F, 85 => 0x6A, 86 => 0x6D, 87 => 0x6B, 88 => 0x0D,
      98 => 0x60, 99 => 0x6E, 224 => 0x11, 225 => 0x10, 226 => 0x12, 228 => 0x11, 229 => 0x10, 230 => 0x12
    }

    # The modifier keys, said last: a button bound to Shift and to a letter is the letter's.
    MODIFIERS = [0x10, 0x11, 0x12]

    # The SDL scancodes whose key the keyboard layout names (letters, digits, punctuation, the key beside the left
    # Shift) as the physical scan codes Windows maps through it, the way F1 names them.
    LAYOUT_SCAN = {
      4 => 0x1E, 5 => 0x30, 6 => 0x2E, 7 => 0x20, 8 => 0x12, 9 => 0x21, 10 => 0x22, 11 => 0x23, 12 => 0x17,
      13 => 0x24, 14 => 0x25, 15 => 0x26, 16 => 0x32, 17 => 0x31, 18 => 0x18, 19 => 0x19, 20 => 0x10, 21 => 0x13,
      22 => 0x1F, 23 => 0x14, 24 => 0x16, 25 => 0x2F, 26 => 0x11, 27 => 0x2D, 28 => 0x15, 29 => 0x2C, 30 => 0x02,
      31 => 0x03, 32 => 0x04, 33 => 0x05, 34 => 0x06, 35 => 0x07, 36 => 0x08, 37 => 0x09, 38 => 0x0A, 39 => 0x0B,
      45 => 0x0C, 46 => 0x0D, 47 => 0x1A, 48 => 0x1B, 49 => 0x2B, 51 => 0x27, 52 => 0x28, 53 => 0x29, 54 => 0x33,
      55 => 0x34, 56 => 0x35, 100 => 0x56
    }

    # Windows' MapVirtualKey, asked for a scan code's virtual key in the calling thread's layout, and its Ex form, asked
    # in the game window's (Keyboard.window_layout), as the key names are.
    MVK = (Win32API.new("user32", "MapVirtualKeyA", "ii", "i") rescue nil)
    MVK_EX = (Win32API.new("user32", "MapVirtualKeyExA", "iil", "i") rescue nil)

    @table = nil
    @stamp = nil
    @native = nil

    # The virtual key of an SDL scancode, or nil for one the mod has no name for: keyboard layout hkl's where Windows
    # tells it (layout_vk), else a US keyboard's.
    def self.vk_of(sc, hkl = PokeAccess::Keyboard.window_layout)
      vk = layout_vk(sc, hkl)
      return vk if vk
      return 0x41 + sc - 4 if sc >= 4 && sc <= 29
      return 0x31 + sc - 30 if sc >= 30 && sc <= 38
      return 0x30 if sc == 39
      return 0x70 + sc - 58 if sc >= 58 && sc <= 69
      return 0x61 + sc - 89 if sc >= 89 && sc <= 97
      SCANCODE_VK[sc]
    end

    # The virtual key keyboard layout hkl (the game window's) puts on a LAYOUT_SCAN scancode, the calling thread's
    # where hkl is nil or puts none; nil for another scancode or where Windows does not say.
    def self.layout_vk(sc, hkl)
      scan = LAYOUT_SCAN[sc]
      return nil unless scan
      vk = hkl && MVK_EX ? MVK_EX.call(scan, 1, hkl).to_i : 0
      vk = MVK.call(scan, 1).to_i if vk <= 0 && MVK
      vk > 0 ? vk : nil
    end

    # Whether mkxp-z answers the game's input, which its F1 menu then rebinds: the games that read the keyboard
    # themselves define Input.getstate.
    def self.native_input?
      @native = !(::Input.respond_to?(:getstate) rescue true) if @native.nil?
      @native
    end

    # Where mkxp-z keeps the F1 bindings of this game, or nil outside mkxp-z.
    def self.path
      base = (System.data_directory rescue nil)
      base && !base.to_s.empty? ? File.join(base.to_s, "keybindings.mkxp1") : nil
    end

    # The keyboard keys bound to each standard button, {action => [virtual keys in the file's order]}, read again only
    # when the file or the game window's keyboard layout changes; empty with no file or a file it cannot read.
    def self.table
      p = native_input? ? path : nil
      hkl = p ? PokeAccess::Keyboard.window_layout : nil
      stamp = (p && File.exist?(p)) ? [p, File.mtime(p).to_i, File.size(p), hkl] : nil
      return @table if @table && stamp == @stamp
      @stamp = stamp
      @table = stamp ? parse(File.open(p, "rb") { |f| f.read }, hkl) : {}
    rescue StandardError => e
      (PokeAccess.log_once("native_keys", e) rescue nil)
      @table = {}
    end

    # The bindings in a keybindings.mkxp1: three words of header (format, RGSS version, count), then four words
    # per binding (source type, scancode, unused, button); keys read in keyboard layout hkl (vk_of).
    def self.parse(data, hkl = PokeAccess::Keyboard.window_layout)
      words = data.to_s.unpack("V*")
      count = words[2].to_i
      out = {}
      return out if words.length < 3 + count * 4
      count.times do |i|
        type, code, _extra, button = words[3 + i * 4, 4]
        sym = BUTTON_OF[button]
        vk = type == KEYBOARD ? vk_of(code, hkl) : nil
        next unless sym && vk
        (out[sym] ||= []).push(vk) unless (out[sym] || []).include?(vk)
      end
      out
    end

    # True when there are F1 bindings to go by.
    def self.active?
      !table.empty?
    end

    # The name of the key a button is on now (a letter first, then any non-modifier) when F1 moved it off the painted
    # one; nil while the painted key still works or there is nothing to go by.
    # param painted the key as the game paints it
    def self.name(sym, painted)
      keys = table[sym]
      return nil if keys.nil? || keys.empty?
      said = keys.map { |vk| PokeAccess::ConfigMenu.keyname(vk).to_s.downcase }
      return nil if said.include?(painted.to_s.downcase)
      pick = keys.detect { |vk| vk >= 0x41 && vk <= 0x5A } || keys.detect { |vk| !MODIFIERS.include?(vk) } || keys[0]
      PokeAccess::ConfigMenu.keyname(pick)
    end

    # Forgets what it read and whether input is mkxp-z's, so the next call looks again (tests).
    def self.reset
      @table = nil
      @stamp = nil
      @native = nil
    end
  end
end
