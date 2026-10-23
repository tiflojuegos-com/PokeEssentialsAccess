module PokeAccess
  # The input orchestrator (PokeAccess::Keys, not RGSS ::Input): the mod's on/off, the global poll, the suppression
  # windows and the configured key names. Raw keys are Keyboard's, focus is Focus's and the per-frame beat is Frame's;
  # the diagnostics live in input/diag.rb.
  module Keys
    GAKS  = PokeAccess::Keyboard::GAKS
    GFW   = PokeAccess::Focus::GFW
    GAW   = PokeAccess::Focus::GAW
    GCPID = PokeAccess::Focus::GCPID
    @typing_ttl = 0
    @enabled = true
    @menu_lock_ttl = 0

    # Whether the mod is active (Ctrl+Alt+F8 toggles it, a manual fallback for unreliable focus).
    def self.enabled; @enabled; end

    # Raw physical state of a virtual-key (global, focus-independent). Delegates to Keyboard.
    def self.raw_down?(c); PokeAccess::Keyboard.raw_down?(c); end

    # True while the game window is foreground; fail-safe true. Delegates to Focus.
    def self.focused?; PokeAccess::Focus.focused?; end

    # Records the game window handle while focused. Delegates to Focus.
    def self.mark_focused; PokeAccess::Focus.mark_focused; end

    # True only on the frame one of the mod's global gestures fires: Ctrl+Alt+<function key>, the shape all
    # three of them share (F8 toggle, F9 diag dump, F10 spoken diag).
    def self.hotkey?(fkey)
      kb = PokeAccess::Keyboard
      kb.chord_pressed?(kb::VK_CONTROL, kb::VK_ALT, fkey)
    end

    # Toggles the whole mod with Ctrl+Alt+F8, polled even while disabled; re-enabling retries a failed speech init.
    def self.toggle_poll
      return unless hotkey?(PokeAccess::Keyboard::VK_F8)
      @enabled = !@enabled
      (PokeAccess.retry_init! rescue nil) if @enabled
      PokeAccess.speak(PokeAccess::I18n.t(@enabled ? :mod_on : :mod_off), true, :system)
    end

    # Call while a text field is active: every mod key is suppressed for a few frames.
    def self.typing!
      @typing_ttl = 4
    end

    # Call each frame a game's own screen answers a mod key itself: that key then does nothing for a few frames.
    def self.yield_key!(name)
      (@yielded ||= {})[name] = 4
    end

    # Whether a game's screen has claimed this key of the mod's (see yield_key!).
    def self.yielded?(name)
      (@yielded ||= {})[name].to_i > 0
    end

    # Call while a game menu with its own raw-key input is active: the config key is ignored for a few frames,
    # while the info keys keep working.
    def self.menu_lock!
      @menu_lock_ttl = 4
    end

    # True only on the frame a configured key (by Config.keys name) goes down; an unbound name is never pressed.
    def self.key(name)
      code = PokeAccess::Config.keys[name]
      return false unless code
      hit = PokeAccess::Keyboard.pressed?(code)
      (PokeAccess::Recorder.note_key(name) rescue nil) if hit
      hit
    end

    # True while the configured shift key (Config.keys[:shift]) is held; an unbound one is never held.
    def self.shift_down?
      code = PokeAccess::Config.keys[:shift]
      code ? PokeAccess::Keyboard.raw_down?(code) : false
    end

    # True while the control key is held (configurable, like shift_down?).
    def self.ctrl_down?
      code = PokeAccess::Config.keys[:ctrl]
      code ? PokeAccess::Keyboard.raw_down?(code) : false
    end

    # The once-per-frame poll: the global hotkeys, then the contextual keys (info, hp, field, history, verbosity) and
    # the coordinates key, this one only while the locator keys are free (a message or a cutscene leaves them free) and
    # out of battle; each answer is filed under its category.
    def self.global_poll
      PokeAccess::Speech.as(:system) do
        toggle_poll
        diag_poll
        spoken_diag_poll
      end
      return unless @enabled
      return unless focused?
      if @typing_ttl > 0
        @typing_ttl -= 1
        return
      end
      menu_locked = (@menu_lock_ttl ||= 0) > 0
      @menu_lock_ttl -= 1 if menu_locked
      (@yielded ||= {}).each_key { |k| @yielded[k] -= 1 if @yielded[k] > 0 }
      return if PokeAccess::ConfigMenu.active?
      if !menu_locked && key(:config)
        PokeAccess::ConfigMenu.open
        return
      end
      if key(:info) && !yielded?(:info)
        PokeAccess::Speech.as(:info) { info_key }
      elsif key(:hp)
        PokeAccess::Speech.as(:info) { PokeAccess::Battle.announce_hp(shift_down?) }
      elsif key(:field)
        field_key
      elsif key(:coords) && PokeAccess::Control.keys? && !PokeAccess::Battle.in_battle?
        PokeAccess::Speech.as(:nav) { coords_key }
      elsif key(:hist_prev)
        history_key(-1)
      elsif key(:hist_next)
        history_key(1)
      elsif key(:verbosity)
        PokeAccess::Verbosity.rotate_scheme
      end
    end

    # The info key: the last dialogue with shift, the focused row whole with ctrl, else what the screen published (on
    # the map, its owners' line: Info.map_text). Ctrl on a screen with no row says what the key alone says.
    def self.info_key
      row = ctrl_down? ? PokeAccess::Info.row_text : nil
      if shift_down?
        d = PokeAccess.last_dialogue
        PokeAccess.speak((d && !d.to_s.empty?) ? d : PokeAccess::I18n.t(:no_recent_dialogue), true)
      elsif row
        PokeAccess.speak(row, true)
      else
        PokeAccess.speak(PokeAccess::Info.info_text, true)
      end
    end

    # The field key: a marker on the player's tile with ctrl (navigation), else the conditions (information).
    def self.field_key
      if ctrl_down?
        PokeAccess::Speech.as(:nav) { mark_key }
      else
        PokeAccess::Speech.as(:info) { PokeAccess::Battle.announce_field }
      end
    end

    # Ctrl with the field key: a marker on the player's tile, unless a battle (which keeps the map scene) or a screen
    # locks the locator keys, where it says markers go on the map.
    def self.mark_key
      return PokeAccess::Locator.mark_here if PokeAccess::Control.keys? && !PokeAccess::Battle.in_battle?
      PokeAccess.speak(PokeAccess::I18n.t(:mark_map_only), true)
    end

    # The coordinates key: hide the unreachable targets with ctrl, rename the map with shift, else where the
    # player stands.
    def self.coords_key
      if ctrl_down?
        PokeAccess::Locator.toggle_hide_unreachable
      elsif shift_down?
        PokeAccess::Locator.rename_map
      else
        PokeAccess::Locator.announce_coords
      end
    end

    # The history keys: with ctrl, to the first or the last message; with shift, to the previous or the next
    # category; else one message back or on.
    # param dir -1 for the older side (the previous key), 1 for the newer
    def self.history_key(dir)
      if ctrl_down?
        PokeAccess::History.to_end(dir)
      elsif shift_down?
        PokeAccess::History.switch_category(dir)
      else
        PokeAccess::History.step(dir)
      end
    end
  end
end
