module PokeAccess
  # The raw physical keyboard, and nothing else. GetAsyncKeyState reports the hardware state of a
  # virtual-key globally: independent of window focus, of the engine's own ::Input, and of whether the mod
  # is enabled. So this module answers exactly two questions -- "is this key down right now" and "did it go
  # down on THIS frame" -- and holds the virtual-key codes those questions are asked with.
  #
  # It deliberately knows nothing about the mod: no Config, no I18n, no speech, no focus. Everything above
  # it (which key NAME maps to which code, whether the mod may act on the keystroke at all) belongs to
  # PokeAccess::Keys; the focus gate belongs to PokeAccess::Focus. The module is self-contained enough to
  # be copied into another project unchanged, and testable without booting the rest of the toolkit.
  module Keyboard
    GAKS = (Win32API.new("user32", "GetAsyncKeyState", ["i"], "i") rescue nil)

    # The virtual-keys the mod polls by identity instead of by configuration: the two modifiers its global
    # chords are built from, and the function keys those chords end in. Everything the PLAYER can rebind is
    # a code in Config.keys, not a constant here.
    VK_SHIFT   = 0x10
    VK_CONTROL = 0x11
    VK_ALT     = 0x12
    VK_F8      = 0x77
    VK_F9      = 0x78
    VK_F10     = 0x79

    @down = {}

    # Raw physical state of a virtual-key (global, focus-independent). Returns nil rather than false where
    # GetAsyncKeyState is unavailable; both are falsy, so no caller has to special-case it.
    def self.raw_down?(vk); GAKS && (GAKS.call(vk) & 0x8000) != 0; end

    # True only while EVERY virtual-key of a chord is held.
    def self.all_down?(*vks)
      vks.all? { |vk| raw_down?(vk) }
    end

    # True only on the frame a virtual-key transitions to pressed. slot names the WATCHER, not the key, so
    # two callers watching the same key keep independent edges and neither swallows the other's transition.
    # Must be called once per frame per slot -- the call itself is the sampling.
    def self.triggered?(slot, vk)
      edge?(slot, raw_down?(vk))
    end

    # True only on the frame a whole chord becomes held (every key down now, at least one of them not down
    # on the previous poll). Same per-watcher slot rule as triggered?.
    def self.combo_triggered?(slot, *vks)
      edge?(slot, all_down?(*vks))
    end

    # The edge primitive both triggers are built on: remembers the state of a watcher and reports whether
    # it just became true. Exposed so a caller with its own notion of "down" (a chord read elsewhere, a
    # pad button) can reuse the same edge bookkeeping instead of growing another flag.
    def self.edge?(slot, state)
      now = state ? true : false
      was = @down[slot]
      @down[slot] = now
      now && !was
    end
  end
end
