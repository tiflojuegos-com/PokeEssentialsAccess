module PokeAccess
  # Config menu, binding keys: one list of the game's buttons and the mod's own keys; confirm binds the next key
  # pressed and left restores the default. A game button's binding replaces the engine's keys for it (a direction's
  # adds to them) while the mod is on and the game window in front.
  module ConfigMenu
    KEYNAMES = {
      0x08 => :key_backspace, 0x09 => :key_tab, 0x0D => :key_enter, 0x10 => :key_shift,
      0x11 => :key_control, 0x12 => :key_alt, 0x14 => :key_caps_lock, 0x1B => :key_escape, 0x20 => :key_space,
      0x21 => :key_page_up, 0x22 => :key_page_down, 0x23 => :key_end, 0x24 => :key_home,
      0x25 => :key_arrow_left, 0x26 => :key_arrow_up, 0x27 => :key_arrow_right,
      0x28 => :key_arrow_down, 0x2D => :key_insert, 0x2E => :key_delete, 0x59 => :key_letter_y
    }
    # The signs the keyboard layouts of the mod's languages type on their punctuation and numpad keys, by code point,
    # each with the key of its spoken name.
    CHAR_NAMES = {
      0x21 => :key_exclamation, 0x22 => :key_quote, 0x23 => :key_hash, 0x24 => :key_dollar, 0x27 => :key_apostrophe,
      0x29 => :key_paren_close, 0x2A => :key_asterisk, 0x2B => :key_plus, 0x2C => :key_comma, 0x2D => :key_minus,
      0x2E => :key_period, 0x2F => :key_slash, 0x3A => :key_colon, 0x3B => :key_semicolon, 0x3C => :key_less,
      0x3D => :key_equals, 0x3F => :key_question, 0x5B => :key_bracket_open, 0x5C => :key_backslash,
      0x5D => :key_bracket_close, 0x5E => :key_circumflex, 0x60 => :key_grave, 0x7B => :key_brace_open, 0x7C => :key_bar,
      0x7D => :key_brace_close, 0x7E => :key_tilde, 0xA1 => :key_exclamation_open, 0xA7 => :key_section,
      0xA8 => :key_diaeresis, 0xAB => :key_guillemet_open, 0xB2 => :key_squared, 0xB4 => :key_acute,
      0xB5 => :key_micro, 0xB8 => :key_cedilla, 0xBA => :key_ordinal, 0xBF => :key_question_open
    }
    SCAN_CODES = [0x08, 0x09, 0x0D, 0x1B, 0x20, 0x21, 0x22, 0x23, 0x24,
                  0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x10, 0x11, 0x12,
                  0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0, 0xC1,
                  0xDB, 0xDC, 0xDD, 0xDE, 0xDF, 0xE2]
    SCAN_CODES.concat((0x30..0x39).to_a)
    SCAN_CODES.concat((0x41..0x5A).to_a)
    SCAN_CODES.concat((0x60..0x6F).to_a)
    SCAN_CODES.concat((0x70..0x87).to_a)
    # Alt's virtual-key: a key pressed with it belongs to the window or the engine (Alt+Tab, Alt+F4, Alt+Enter), so a
    # capture takes Alt only once it is released with nothing pressed beside it.
    ALT = 0x12
    @ri = 0
    @cap_down = {}
    @alt_alone = false

    # The remap submenu's frame, the info key saying the focused entry whole; after a capture it ignores input until
    # the captured key is released.
    def self.rebind_step
      if @cap_wait
        return if down?(@cap_wait)
        @cap_wait = nil
      end
      n = PokeAccess::Remap.buttons.length
      if Input.trigger?(Input::B)
        back_one
      elsif Input.repeat?(Input::UP)
        @armed = nil
        @ri = (@ri - 1) % n; say(rebind_desc)
      elsif Input.repeat?(Input::DOWN)
        @armed = nil
        @ri = (@ri + 1) % n; say(rebind_desc)
      elsif (PokeAccess::Keys.key(:info) rescue false)
        say(PokeAccess::Verbosity.whole { rebind_desc })
      elsif PokeAccess::Remap.buttons[@ri][0] == :__reset__
        reset_all if Input.trigger?(Input::C)
      elsif Input.trigger?(Input::C)
        start_capture
      elsif Input.trigger?(Input::LEFT)
        clear_binding
      end
    end

    # The focused entry: what it does and the key it is on, then, while key hints are said, how to change it.
    def self.rebind_desc
      sym = PokeAccess::Remap.buttons[@ri][0]
      return PokeAccess::Verbosity.with_hint(t(:rmp_reset), t(:rmp_reset_hint)) if sym == :__reset__
      entry = t(:rmp_entry, :action => PokeAccess::Remap.label(sym), :key => key_of(sym))
      PokeAccess::Verbosity.with_hint(entry, t(:rmp_entry_hint))
    end

    # The key an entry is on, in words: a mod key's (or unassigned), else a game button's binding, the key the game
    # reads an unbound extra on, or the game's keys.
    def self.key_of(sym)
      if PokeAccess::Remap.mod_action?(sym)
        code = (PokeAccess::Config.keys[sym] rescue nil)
        return code ? keyname(code) : t(:rmp_unassigned)
      end
      code = (PokeAccess::Config.rebinds[sym] rescue nil)
      extra = PokeAccess::Remap.extras.assoc(sym)
      code ||= extra[1] if extra
      code ? keyname(code) : t(:rmp_native)
    end

    # Resets both tables on a second press of its row (the first asks): drops the game rebinds (native keys take over)
    # and restores the mod keys' shipped values.
    def self.reset_all
      unless @armed == :reset_keys
        @armed = :reset_keys
        return say(t(:rmp_reset_confirm))
      end
      @armed = nil
      (PokeAccess::Config.rebinds.clear rescue (PokeAccess::Config.rebinds = {}))
      (PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup rescue nil)
      (PokeAccess::Settings.write rescue nil)
      say(t(:rmp_all_reset))
    end

    # Left on an entry: unbinds a game button, back on the game's keys (an extra on the key the game reads it on), or
    # restores a mod key's shipped default (unbound for a key that ships unbound) unless another entry holds that key
    # now, which is said instead; an entry already on its default says so.
    def self.clear_binding
      sym = PokeAccess::Remap.buttons[@ri][0]
      label = PokeAccess::Remap.label(sym)
      if PokeAccess::Remap.mod_action?(sym)
        deflt = PokeAccess::Config::KEY_DEFAULTS[sym]
        return say(deflt ? t(:rmp_at_default, :action => label) : t(:rmp_none)) if PokeAccess::Config.keys[sym] == deflt
        other = PokeAccess::Remap.conflict(deflt, sym)
        return say(taken_line(deflt, other)) if other
        PokeAccess::Config.keys[sym] = deflt
        (PokeAccess::Settings.write rescue nil)
        return say(deflt ? t(:rmp_restored, :action => label) : t(:rmp_cleared, :action => label))
      end
      had = (PokeAccess::Config.rebinds[sym] rescue nil)
      (PokeAccess::Config.rebinds.delete(sym) rescue nil)
      (PokeAccess::Settings.write rescue nil)
      return say(t(:rmp_none)) unless had
      say(t(PokeAccess::Remap.extras.assoc(sym) ? :rmp_restored : :rmp_native_back, :action => label))
    end

    def self.start_capture
      @capturing = true
      @cap_tick = 0
      @alt_alone = false
      @cap_down = {}
      SCAN_CODES.each { |c| @cap_down[c] = down?(c) }
      say(t(:rmp_press, :action => PokeAccess::Remap.label(PokeAccess::Remap.buttons[@ri][0])))
    end

    # One frame of key capture: cancel, or (every third frame, while the game window is in front) bind the first key
    # pressed since the last look, Alt once released alone; a key held across a look away from the game is not new.
    def self.capture_step
      if Input.trigger?(Input::B)
        @capturing = false
        return say(t(:cancelled))
      end
      @cap_tick = (@cap_tick.to_i + 1) % 3
      return unless @cap_tick == 0
      was = @cap_down
      @cap_down = {}
      SCAN_CODES.each { |c| @cap_down[c] = down?(c) }
      return @alt_alone = false unless PokeAccess::Keys.focused?
      others = SCAN_CODES.select { |c| c != ALT && @cap_down[c] }
      if @cap_down[ALT]
        @alt_alone = (was[ALT] ? @alt_alone : true) && others.empty?
        return
      end
      code = (was[ALT] && @alt_alone) ? ALT : others.find { |c| !was[c] }
      @alt_alone = false
      bind_captured(code) if code
    end

    # Binds the captured key to the focused entry and saves, unless Remap.conflict finds it taken in either table,
    # which is said instead.
    def self.bind_captured(c)
      sym = PokeAccess::Remap.buttons[@ri][0]
      other = PokeAccess::Remap.conflict(c, sym)
      @capturing = false
      @cap_wait = c
      return say(taken_line(c, other)) if other
      if PokeAccess::Remap.mod_action?(sym)
        PokeAccess::Config.keys[sym] = c
      else
        PokeAccess::Config.rebinds[sym] = c
      end
      (PokeAccess::Settings.write rescue nil)
      say(t(:rmp_assigned, :action => PokeAccess::Remap.label(sym), :key => keyname(c)))
    end

    # What is said of a key already in use: a reserved one, which no entry can free, by what the engine or the mod
    # keeps it for; else the entry bound to it, to free first.
    def self.taken_line(code, holder)
      return t(:rmp_reserved, :key => keyname(code), :action => t(holder)) if PokeAccess::Remap::RESERVED.key?(code)
      t(:rmp_inuse, :key => keyname(code), :action => PokeAccess::Remap.label(holder))
    end

    # Raw physical state of a virtual key, read past the engine's buttons and the mod's input gate.
    def self.down?(c); PokeAccess::Keyboard.raw_down?(c); end

    # A virtual key's spoken name: its own word, a digit or letter as itself, a numpad digit or function key by its
    # number, else the character the keyboard layout types on it (a numpad one as the numpad's); its code when the
    # layout types none or one without a name.
    def self.keyname(c)
      return t(KEYNAMES[c]) if KEYNAMES[c]
      return (c - 0x30).to_s if c >= 0x30 && c <= 0x39
      return c.chr if c >= 0x41 && c <= 0x5A
      return t(:key_numpad, :n => c - 0x60) if c >= 0x60 && c <= 0x69
      return t(:key_f, :n => c - 0x6F) if c >= 0x70 && c <= 0x87
      name = char_name(PokeAccess::Keyboard.char_code(c))
      return t(:key_code, :n => c) unless name
      c >= 0x6A && c <= 0x6F ? t(:key_numpad, :n => name) : name
    end

    # A character a key types, in words: a sign by its name, a letter or digit (a Latin letter with or without its
    # accent) as itself; nil for none or another character.
    def self.char_name(code)
      return nil unless code
      return t(CHAR_NAMES[code]) if CHAR_NAMES[code]
      ascii = (code >= 0x30 && code <= 0x39) || (code >= 0x41 && code <= 0x5A) || (code >= 0x61 && code <= 0x7A)
      latin = code >= 0xC0 && code <= 0x24F && code != 0xD7 && code != 0xF7
      ascii || latin ? [code].pack("U") : nil
    end
  end
end
