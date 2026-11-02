module PokeAccess
  # The raw physical keyboard: whether a virtual-key is down (GetAsyncKeyState, focus-independent) or went down this
  # frame against the snapshot the Input pulse takes every frame, modal loops too (a key held as a screen closes is no
  # new press), and which character a key types in the game's layout. Key names live in Keys, the focus gate in Focus.
  module Keyboard
    GAKS = (Win32API.new("user32", "GetAsyncKeyState", ["i"], "i") rescue nil)

    # Windows' MapVirtualKey (wide), asked for the character a virtual-key types in the calling thread's layout, and
    # its Ex form, asked in the layout of the game window's thread (GetKeyboardLayout), which follows a switch mid-game.
    MVK_CHAR = (Win32API.new("user32", "MapVirtualKeyW", "ii", "i") rescue nil)
    MVK_CHAR_EX = (Win32API.new("user32", "MapVirtualKeyExW", "iil", "i") rescue nil)
    GKL = (Win32API.new("user32", "GetKeyboardLayout", "l", "l") rescue nil)
    MAPVK_VK_TO_CHAR = 2

    # Fixed virtual-keys: the modifiers and the global chords' function keys (rebindable ones are in Config.keys).
    VK_SHIFT   = 0x10
    VK_CONTROL = 0x11
    VK_ALT     = 0x12
    VK_F8      = 0x77
    VK_F9      = 0x78
    VK_F10     = 0x79
    # What marks a key code as a key pressed with Alt held; the key tables and settings.ini hold it like any other code.
    ALT_HELD   = 0x1200
    # The key code of no key: an action on it answers nothing, and its game's key stops answering for it.
    NO_KEY     = 0

    @now = {}
    @prev = {}
    @used = {}

    # Raw physical state of a virtual-key; nil (falsy) where GetAsyncKeyState is unavailable.
    def self.raw_down?(vk); GAKS && (GAKS.call(vk) & 0x8000) != 0; end

    # The key code of a virtual-key pressed with Alt held.
    def self.with_alt(vk); ALT_HELD | vk; end

    # Whether a key code is a key pressed with Alt held.
    def self.alt_code?(code); code >= ALT_HELD; end

    # The virtual-key of a key code.
    def self.key_of(code); code & 0xFF; end

    # Whether Alt is held for a key with it: AltGr, which holds Ctrl with it, types instead.
    def self.alt_held?; raw_down?(VK_ALT) && !raw_down?(VK_CONTROL); end

    # The key code of a key named as a profile names it: a letter, a digit or an F key, after "Alt+" for one with Alt
    # held; "Alt" for Alt alone; "None" for no key. A number is a code already, and nil stays nil.
    def self.code_for(spec)
      return spec unless spec.is_a?(String)
      return NO_KEY if spec == "None"
      return VK_ALT if spec == "Alt"
      key = spec.sub(/\AAlt\+/, "")
      vk = key =~ /\AF(\d+)\z/ ? 0x6F + $1.to_i : key.unpack("C")[0]
      key == spec ? vk : with_alt(vk)
    end

    # The code point of the character a virtual-key types unshifted in the game window's keyboard layout (game_char),
    # else in the calling thread's, a dead key's accent too; nil where the layout puts none on it or Windows cannot be
    # asked.
    def self.char_code(vk)
      code = game_char(vk) || (MVK_CHAR ? MVK_CHAR.call(vk, MAPVK_VK_TO_CHAR).to_i : 0)
      code &= 0xFFFF
      code > 0 ? code : nil
    end

    # What MapVirtualKeyExW gives a virtual-key's character in the layout of the game window's thread (window_layout),
    # 0 for none; nil while that layout or the call cannot be had.
    def self.game_char(vk)
      hkl = MVK_CHAR_EX && window_layout
      hkl ? MVK_CHAR_EX.call(vk, MAPVK_VK_TO_CHAR, hkl).to_i : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The keyboard layout (GetKeyboardLayout) of the game window's thread (Focus.hwnd), which follows a switch
    # mid-game; nil while no window is known or the thread or its layout cannot be had.
    def self.window_layout
      h = PokeAccess::Focus.hwnd
      tids = PokeAccess::Focus::GWTPID
      return nil unless h && h != 0 && tids && GKL
      tid = tids.call(h, [0].pack("L")).to_i
      hkl = tid == 0 ? 0 : GKL.call(tid).to_i
      hkl == 0 ? nil : hkl
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Takes this frame's picture of every key asked about so far, keeping the last one to compare against; run once
    # per frame, before anything reads the keys.
    def self.snapshot
      @prev = @now
      @now = {}
      @used = {}
      @prev.each_key { |vk| @now[vk] = raw_down?(vk) ? true : false }
    end

    # Whether a virtual-key is down in this frame's picture; a key asked about for the first time is read now.
    def self.down?(vk)
      @now[vk] = raw_down?(vk) ? true : false unless @now.key?(vk)
      @now[vk]
    end

    # True on the frame a virtual-key goes down, until a reader consumes it.
    def self.pressed?(vk)
      down?(vk) && !@prev[vk] && !@used[vk]
    end

    # True on the frame a key code goes down, until a reader consumes it; a key with Alt needs Alt held by then, and its
    # key is asked about every frame, so one held before Alt is no new press.
    def self.code_pressed?(code)
      pressed = pressed?(key_of(code))
      pressed && (!alt_code?(code) || alt_held?)
    end

    # True on the frame a whole chord becomes held: every key down now, not all of them down the frame before.
    def self.chord_pressed?(*vks)
      vks.all? { |vk| down?(vk) } && !vks.all? { |vk| @prev[vk] }
    end

    # Marks this frame's press of a key as taken, so a reader later in the frame does not take it again; the key joins
    # the picture, so the next frames see it held rather than newly pressed.
    def self.consume(vk)
      down?(vk)
      @used[vk] = true
    end
  end
end
