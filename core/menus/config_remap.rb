module PokeAccess
  # Config menu, binding keys: one list with the game's buttons and the mod's own keys, where confirm binds the
  # next key pressed and left gives the entry back its default. A game button's binding is an extra key on top of
  # the engine's native one, never a replacement for it.
  module ConfigMenu
    KEYNAMES = {
      0x08 => :key_backspace, 0x09 => :key_tab, 0x0D => :key_enter, 0x10 => :key_shift,
      0x11 => :key_control, 0x12 => :key_alt, 0x1B => :key_escape, 0x20 => :key_space,
      0x21 => :key_page_up, 0x22 => :key_page_down, 0x23 => :key_end, 0x24 => :key_home,
      0x25 => :key_arrow_left, 0x26 => :key_arrow_up, 0x27 => :key_arrow_right,
      0x28 => :key_arrow_down, 0x2D => :key_insert, 0x2E => :key_delete, 0x59 => :key_letter_y
    }
    SCAN_CODES = [0x08, 0x09, 0x0D, 0x1B, 0x20, 0x21, 0x22, 0x23, 0x24,
                  0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x10, 0x11, 0x12,
                  0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0,
                  0xDB, 0xDC, 0xDD, 0xDE]
    SCAN_CODES.concat((0x30..0x39).to_a)
    SCAN_CODES.concat((0x41..0x5A).to_a)
    SCAN_CODES.concat((0x60..0x6F).to_a)
    SCAN_CODES.concat((0x70..0x87).to_a)
    @ri = 0
    @cap_down = {}

    # The remap submenu's frame; after a capture it ignores input until the captured key is released.
    def self.rebind_step
      if @cap_wait
        return if down?(@cap_wait)
        @cap_wait = nil
      end
      n = PokeAccess::Remap.buttons.length
      if Input.trigger?(Input::B)
        back_one
      elsif Input.repeat?(Input::UP)
        @ri = (@ri - 1) % n; say(rebind_desc)
      elsif Input.repeat?(Input::DOWN)
        @ri = (@ri + 1) % n; say(rebind_desc)
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
      code = if PokeAccess::Remap.mod_action?(sym)
        (PokeAccess::Config.keys[sym] rescue nil)
      else
        (PokeAccess::Config.rebinds[sym] rescue nil)
      end
      entry = t(:rmp_entry, :action => PokeAccess::Remap.label(sym), :key => (code ? keyname(code) : t(:rmp_unassigned)))
      PokeAccess::Verbosity.with_hint(entry, t(:rmp_entry_hint))
    end

    # Resets both tables: drops the game rebinds (native keys take over) and restores the mod keys' shipped values.
    def self.reset_all
      (PokeAccess::Config.rebinds.clear rescue (PokeAccess::Config.rebinds = {}))
      (PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup rescue nil)
      (PokeAccess::Settings.write rescue nil)
      say(t(:rmp_all_reset))
    end

    # Left on an entry: unbinds a game button, so its native key takes over, or restores a mod key's shipped default
    # (unbound for a key that ships unbound).
    def self.clear_binding
      sym = PokeAccess::Remap.buttons[@ri][0]
      label = PokeAccess::Remap.label(sym)
      if PokeAccess::Remap.mod_action?(sym)
        deflt = PokeAccess::Config::KEY_DEFAULTS[sym]
        changed = PokeAccess::Config.keys[sym] != deflt
        PokeAccess::Config.keys[sym] = deflt
        (PokeAccess::Settings.write rescue nil)
        return say(t(:rmp_none)) unless changed
        return say(deflt ? t(:rmp_restored, :action => label) : t(:rmp_cleared, :action => label))
      end
      had = (PokeAccess::Config.rebinds[sym] rescue nil)
      (PokeAccess::Config.rebinds.delete(sym) rescue nil)
      (PokeAccess::Settings.write rescue nil)
      say(had ? t(:rmp_cleared, :action => label) : t(:rmp_none))
    end

    def self.start_capture
      @capturing = true
      @cap_tick = 0
      @cap_down = {}
      SCAN_CODES.each { |c| @cap_down[c] = down?(c) }
      say(t(:rmp_press, :action => PokeAccess::Remap.label(PokeAccess::Remap.buttons[@ri][0])))
    end

    # One frame of key capture: cancel, or (every third frame) bind the first newly pressed key unless
    # Remap.conflict finds it taken in either table.
    def self.capture_step
      if Input.trigger?(Input::B)
        @capturing = false
        return say(t(:cancelled))
      end
      @cap_tick = (@cap_tick.to_i + 1) % 3
      return unless @cap_tick == 0
      SCAN_CODES.each do |c|
        if down?(c) && !@cap_down[c]
          sym = PokeAccess::Remap.buttons[@ri][0]
          other = PokeAccess::Remap.conflict(c, sym)
          if other
            @capturing = false
            @cap_wait = c
            taken = PokeAccess::Remap::RESERVED.has_key?(c) ? t(other) : PokeAccess::Remap.label(other)
            return say(t(:rmp_inuse, :key => keyname(c), :action => taken))
          end
          if PokeAccess::Remap.mod_action?(sym)
            PokeAccess::Config.keys[sym] = c
          else
            PokeAccess::Config.rebinds[sym] = c
          end
          @capturing = false
          @cap_wait = c
          (PokeAccess::Settings.write rescue nil)
          return say(t(:rmp_assigned, :action => PokeAccess::Remap.label(sym), :key => keyname(c)))
        end
      end
    end

    # Raw physical state of a virtual key, read past the engine's buttons and the mod's input gate.
    def self.down?(c); PokeAccess::Keyboard.raw_down?(c); end

    def self.keyname(c)
      return t(KEYNAMES[c]) if KEYNAMES[c]
      return (c - 0x30).to_s if c >= 0x30 && c <= 0x39
      return c.chr if c >= 0x41 && c <= 0x5A
      return t(:key_numpad, :n => c - 0x60) if c >= 0x60 && c <= 0x69
      return t(:key_f, :n => c - 0x6F) if c >= 0x70 && c <= 0x7B
      t(:key_other, :n => c)
    end
  end
end
