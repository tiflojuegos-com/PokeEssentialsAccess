module PokeAccess
  # The raw physical keyboard: whether a virtual-key is down (GetAsyncKeyState, global and focus-independent) and
  # whether it went down this frame. Knows nothing about the mod: key names are Keys', the focus gate is Focus'.
  module Keyboard
    GAKS = (Win32API.new("user32", "GetAsyncKeyState", ["i"], "i") rescue nil)

    # Fixed virtual-keys: the modifiers and the global chords' function keys (rebindable ones are in Config.keys).
    VK_SHIFT   = 0x10
    VK_CONTROL = 0x11
    VK_ALT     = 0x12
    VK_F8      = 0x77
    VK_F9      = 0x78
    VK_F10     = 0x79

    @down = {}

    # Raw physical state of a virtual-key; nil (falsy) where GetAsyncKeyState is unavailable.
    def self.raw_down?(vk); GAKS && (GAKS.call(vk) & 0x8000) != 0; end

    # True only while EVERY virtual-key of a chord is held.
    def self.all_down?(*vks)
      vks.all? { |vk| raw_down?(vk) }
    end

    # True only on the frame a virtual-key goes down. slot names the watcher, not the key, so each caller keeps
    # its own edge; call it once per frame per slot, since the call is the sampling.
    def self.triggered?(slot, vk)
      edge?(slot, raw_down?(vk))
    end

    # True only on the frame a whole chord becomes held; slot as in triggered?.
    def self.combo_triggered?(slot, *vks)
      edge?(slot, all_down?(*vks))
    end

    # Remembers a watcher's state and answers whether it just became true; both triggers are built on it.
    def self.edge?(slot, state)
      now = state ? true : false
      was = @down[slot]
      @down[slot] = now
      now && !was
    end
  end
end
