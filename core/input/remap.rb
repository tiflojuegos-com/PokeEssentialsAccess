module PokeAccess
  # Optional key remapper: tracks how long each bound key has been held and feeds it into the engine's input, for
  # base buttons and game extras (register_extra). A rebound action silences the engine's key, except directions,
  # while the mod is on and the game window in front. Actions sit on key codes (Keyboard): the player's, from the remap
  # menu, or those the profile ships them on (ship).
  module Remap
    # The engines' repeat schedules as [frames held past which a key repeats, every how many]: the games' own Input in
    # Ruby (getstate) past 20 frames on even ones, mkxp-z's input by frames past 15 every 4 (RGSS1, as Essentials runs).
    RUBY_INPUT_REPEAT = [20, 2]
    FRAME_REPEAT = [15, 4]
    # The mkxp-z version from which its input repeats by time, 0.4 s and then every 0.1 s (timed_repeat).
    TIMED_REPEAT_SINCE = [2, 1, 1]

    # Base buttons: [action symbol, Input constant name, label key]. Alt is the engine's modifier button
    # the fangames' turbo scripts read (Input::ALT), which the engine's own F1 menu cannot rebind.
    BUTTONS = [
      [:down,  :DOWN,  :btn_down],
      [:left,  :LEFT,  :btn_left],
      [:right, :RIGHT, :btn_right],
      [:up,    :UP,    :btn_up],
      [:c,     :C,     :btn_accept],
      [:b,     :B,     :btn_cancel],
      [:a,     :A,     :btn_a],
      [:x,     :X,     :btn_x],
      [:y,     :Y,     :btn_y],
      [:z,     :Z,     :btn_z],
      [:l,     :L,     :btn_l],
      [:r,     :R,     :btn_r],
      [:alt,   :ALT,   :btn_alt]
    ]
    DIR_CODE = { :up => 8, :down => 2, :left => 4, :right => 6 }

    # The mod's own hotkeys (Config.keys), in the same remap list: locator keys, then readers, then modifiers.
    MOD_KEYS = [
      [:prev,   :rmk_prev],   [:next,  :rmk_next],  [:where,  :rmk_where],
      [:route,  :rmk_route],  [:info,  :rmk_info],  [:hp,     :rmk_hp],
      [:field,  :rmk_field],  [:coords, :rmk_coords], [:config, :rmk_config],
      [:hist_prev, :rmk_hist_prev], [:hist_next, :rmk_hist_next], [:verbosity, :rmk_verbosity],
      [:camera, :rmk_camera], [:shift,  :rmk_shift],  [:ctrl,  :rmk_ctrl]
    ]

    # Virtual-keys no action may take: Enter, Space, Escape and the arrows, which the engine answers, Backspace, which
    # takes a step of the free camera's trail back, F1, F2 and F12, which open the engine's settings window (mouse only),
    # show its frame rate and reset the game, and F8-F10, the mod's fixed Ctrl+Alt gestures.
    RESERVED = {
      0x08 => :rmp_key_backspace,
      0x0D => :rmp_key_enter, 0x1B => :rmp_key_escape, 0x20 => :rmp_key_space,
      0x25 => :rmp_key_left,  0x26 => :rmp_key_up,     0x27 => :rmp_key_right, 0x28 => :rmp_key_down,
      0x70 => :rmp_key_f1,    0x71 => :rmp_key_f2,     0x7B => :rmp_key_f12,
      0x77 => :rmp_key_f8,    0x78 => :rmp_key_f9,     0x79 => :rmp_key_f10
    }
    # The mod's modifiers, each a key of its own: a key with Alt could not be held beside another.
    PLAIN_KEYS = [:shift, :ctrl]
    # The mod's keys that answer on the map alone: in a battle they hold no key, so a game's Alt there stays the
    # engine's (alt_late?).
    FIELD_MOD_KEYS = [:camera]
    # The reads of the game's input no binding reaches, each with what it answers while the free camera holds the input
    # (Camera.blocking?): mkxp-z's and those a game's own Ruby input defines, a button's let-go, its time and count held,
    # their raw-key forms, a stick's push and the wheel.
    HELD_READS = { :release? => false, :time? => 0.0, :count => 0, :repeatcount => 0, :repeatex? => false,
                   :releaseex? => false, :timeex? => 0.0, :countex => 0, :repeatcountex => 0,
                   :axis_triggerex? => false, :scroll_v => 0 }
    # The Shift keys as virtual keys: either one, the left one and the right one.
    SHIFT_VKS = [0x10, 0xA0, 0xA1]
    # The arrows, which go with a held Shift in the game's own gestures (a list's page by page).
    ARROW_VKS = [0x25, 0x26, 0x27, 0x28]
    @held = {}
    @live = true

    # True when sym is one of the mod's own hotkeys rather than a game button or a game extra.
    def self.mod_action?(sym)
      MOD_KEYS.assoc(sym) ? true : false
    end

    # What already uses this key code across the game's rebinds, what the profile ships, the mod's keys and the game extras
    # still on the raw key the game reads them by: a reserved key's i18n key or another action's symbol, or nil when free.
    def self.conflict(code, action)
      return nil if code.nil? || code == PokeAccess::Keyboard::NO_KEY
      reserved = RESERVED[PokeAccess::Keyboard.key_of(code)]
      return reserved if reserved
      binds = (PokeAccess::Config.rebinds rescue nil) || {}
      hit = nil
      binds.each { |s, c| hit ||= s if c == code && s != action }
      defaults.each { |s, c| hit ||= s if c == code && s != action && binds[s].nil? }
      (PokeAccess::Config.keys rescue {}).each { |s, c| hit ||= s if c == code && s != action }
      extras.each { |s, key, _l| hit ||= s if raw_key(key) == code && s != action && binds[s].nil? && !defaults.key?(s) }
      hit
    end

    # The game extras as [action symbol, the raw key the game reads it by, label] rows, in registration order (an Array,
    # since a Hash has no order under 1.8.7).
    def self.extras; @extras ||= []; end

    # The extras the game reads as buttons of its own Input instead: action symbol => the constant's name.
    def self.extra_buttons; @extra_buttons ||= {}; end

    # Registers a game-specific action the game reads by a raw key, so it can be rebound from the remap menu: by its
    # virtual-key or by mkxp-z's name for its letter (:M), and, given a button, as that constant of its Input too. A read
    # any other way stays the game's. Registering a symbol again replaces its row in place.
    def self.register_extra(sym, key, label, button = nil)
      extras.reject! { |row| row[0] == sym }
      extras.push([sym, key, label])
      if button
        extra_buttons[sym] = button
      else
        extra_buttons.delete(sym)
      end
      @button_extras = nil
    end

    # An extra's raw key as a virtual-key.
    def self.raw_key(key)
      key.is_a?(Symbol) ? key.to_s.unpack("C")[0] : key
    end

    # The key codes the profile ships its game's actions on, as if the player had bound them, with nothing saved: action
    # symbol => key code.
    def self.defaults; @defaults ||= {}; end

    # The shipped actions that hold out of battle alone: a battle leaves them on the game's keys.
    def self.field_defaults; @field_defaults ||= {}; end

    # Ships actions on the keys a profile names them (Keyboard.code_for): the mod's own in Config.key_defaults, the game's
    # here.
    # param field_only holds them out of battle alone
    def self.ship(map, field_only = false)
      map.each do |sym, spec|
        code = PokeAccess::Keyboard.code_for(spec)
        if mod_action?(sym)
          PokeAccess::Config.key_defaults[sym] = code
          PokeAccess::Config.keys[sym] = code
        else
          defaults[sym] = code
          field_defaults[sym] = true if field_only
        end
      end
    end

    # The key code the profile ships an action on now, or nil: out of battle alone if shipped for the field, and not while
    # the player's bindings or the mod's keys hold that code for something else (a key saved before the game shipped it).
    def self.shipped(sym)
      code = defaults[sym]
      return nil if code.nil? || (field_defaults[sym] && PokeAccess::Battle.in_battle?)
      held_elsewhere?(code, sym) ? nil : code
    end

    # Whether the player's bindings or the mod's keys hold this code for another action.
    def self.held_elsewhere?(code, sym)
      binds = (PokeAccess::Config.rebinds rescue nil) || {}
      keys = (PokeAccess::Config.keys rescue nil) || {}
      binds.any? { |s, c| c == code && s != sym } || keys.values.include?(code)
    end

    # The key code an action answers now: the player's binding, else the shipped one; nil on its game's keys.
    def self.bound_code(sym)
      (PokeAccess::Config.rebinds[sym] rescue nil) || shipped(sym)
    end

    # The full remap-menu list: base buttons, game extras, the mod's keys and a final reset-all entry.
    def self.buttons
      list = BUTTONS.dup
      list.concat(extras.map { |row| [row[0], nil, row[2]] })
      list.concat(MOD_KEYS.map { |sym, label| [sym, nil, label] })
      list.push([:__reset__, nil, :btn_reset_all])
      list
    end

    #labels and lookups

    # action symbol => Input button integer, resolved once (Input.const_get is costly per-frame).
    def self.btn_int_map
      @btn_int_map ||= begin
        m = {}
        BUTTONS.each { |row| c = (Input.const_get(row[1]) rescue nil); m[row[0]] = c unless c.nil? }
        m
      end
    end

    # The reverse map: Input button integer => action symbol, resolved once.
    def self.int_sym_map
      @int_sym_map ||= begin
        m = {}; btn_int_map.each { |sym, i| m[i] = sym }; m
      end
    end

    # Spoken label for an action: a per-game override, else its row in buttons (the menu's own list), via I18n.
    def self.label(sym)
      row = buttons.assoc(sym)
      raw = (PokeAccess::Config.rebind_labels[sym] rescue nil) || (row ? row[2] : nil) || sym.to_s
      PokeAccess::I18n.t(raw)
    end

    # The engine's buttons a Ctrl+Alt gesture of the mod's presses on its way, as Input integers resolved once: Alt (the
    # games' turbo), F8 (their screenshot) and F9; those the engine's Input lacks are left out.
    def self.chord_buttons
      @chord_buttons ||= [:ALT, :F8, :F9].map { |c| (Input.const_get(c) rescue nil) }.compact
    end

    # True for one of chord_buttons while Ctrl and Alt are both held: the game reads it as up, so the mod's gestures
    # (Ctrl+Alt+F8, F9, F10) turn no turbo on and take no screenshot.
    def self.chord_button?(bi)
      return false unless chord_buttons.include?(bi)
      kb = PokeAccess::Keyboard
      kb.raw_down?(kb::VK_CONTROL) && kb.raw_down?(kb::VK_ALT) ? true : false
    end

    # The base action bound to an Input button integer, or the extra the game reads as that button, which a text field
    # leaves to the game.
    def self.sym_for_button(bi)
      int_sym_map[bi] || (PokeAccess::Keys.typing? ? nil : button_extras[bi])
    end

    # The reverse of extra_buttons: Input button integer => action symbol, resolved once, a constant the game lacks left out.
    def self.button_extras
      @button_extras ||= begin
        m = {}
        extra_buttons.each { |sym, const| m[Input.const_get(const)] = sym if Input.const_defined?(const) }
        m
      end
    end

    # The extra action the game reads by this raw key, if any.
    def self.sym_for_extra(vk)
      hit = extras.detect { |row| row[1] == vk }
      hit ? hit[0] : nil
    end

    #per-frame polling

    # Updates how long each bound key has been held; call once per frame. A frame with the mod off or another window in
    # front holds none and leaves every key to the game.
    def self.update
      return unless PokeAccess::Keys::GAKS
      @live = (PokeAccess::Keys.enabled rescue true) && (PokeAccess::Keys.focused? rescue true)
      unless @live
        @held = {}
        @alt_was = @alt_tap = @alt_used = false
        @shift_was = @shift_tap = @shift_used = false
        return
      end
      watch_alt
      watch_shift
      binds = (PokeAccess::Config.rebinds rescue nil) || {}
      if binds.empty? && defaults.empty?
        @held = {} unless @held.empty?
      else
        @held.each_key { |s| @held[s] = 0 unless binds[s] || defaults.key?(s) }
        binds.each { |sym, code| hold(sym, code) if code }
        defaults.each_key { |sym| hold(sym, shipped(sym)) unless binds[sym] }
      end
      @held[:alt] = 1 if @alt_tap
    end

    # One frame of an action on a key code, or on none: how long it has been held.
    def self.hold(sym, code)
      held = @held[sym].to_i
      down = code && code_held?(code, held > 0)
      @alt_used = true if down && PokeAccess::Keyboard.alt_code?(code)
      @held[sym] = down ? held + 1 : 0
    end

    # One frame of Alt: while the game reads it late (alt_late?), letting it go counts as one frame's press, unless an
    # action on Alt plus a key or Ctrl went with it, or it was held in the mod's menu, where it picks a key.
    def self.watch_alt
      kb = PokeAccess::Keyboard
      down = kb.raw_down?(kb::VK_ALT)
      @alt_used ||= down && (kb.raw_down?(kb::VK_CONTROL) || PokeAccess::ConfigMenu.active?)
      @alt_tap = @alt_was && !down && !@alt_used && alt_late?
      @alt_used = false unless down
      @alt_was = down
    end

    # One frame of the Shift a game button shares with the mod's Shift gestures (shift_button, found as Shift goes
    # down): letting it go is one frame's trigger of that button (shift_tap?), unless another key went with it
    # (shift_chord?).
    def self.watch_shift
      kb = PokeAccess::Keyboard
      any = kb.raw_down?(kb::VK_SHIFT)
      @shift_at = shift_button if any && !@any_shift
      @any_shift = any
      down = any && @shift_at ? kb.raw_down?(@shift_at[1]) : false
      @shift_used ||= down && shift_chord?
      @shift_tap = @shift_was && !down && !@shift_used
      @shift_used = false unless down
      @shift_was = down
    end

    # The game button that answers the Shift the mod's Shift gestures use, as [action, its Shift's virtual key, its
    # other keys]: the first standard button whose mkxp-z keys (native_buttons) hold a Shift, while the mod's Shift key
    # is one and the mod moved no key onto that button; nil for none.
    def self.shift_button
      return nil unless SHIFT_VKS.include?((PokeAccess::Config.keys[:shift] rescue nil))
      native_buttons.each do |sym, vks|
        vk = vks.detect { |k| SHIFT_VKS.include?(k) }
        return [sym, vk, vks - [vk]] if vk && !bound_code(sym)
      end
      nil
    end

    # The keys mkxp-z answers each standard button by, {action => [virtual keys]}: its F1 bindings, else its own
    # defaults (MKXP_DEFAULT_KEYS, the only modifier A's left Shift; under RGSS1 Z on A and C on C, later Z on C); none
    # in a game that reads the keyboard itself.
    def self.native_buttons
      return {} unless PokeAccess::NativeKeys.native_input?
      return PokeAccess::NativeKeys.table if PokeAccess::NativeKeys.active?
      keys = {}
      MKXP_DEFAULT_KEYS.each { |sym, vks| keys[sym] = vks.dup }
      if engine_config[2]
        keys[:a].push(0x5A)
        keys[:c].push(0x43)
      else
        keys[:c].push(0x5A)
      end
      keys
    end

    # mkxp-z's default keys of each standard button but the arrows, by virtual key, before the RGSS version's own.
    MKXP_DEFAULT_KEYS = { :a => [0xA0], :b => [0x1B, 0x60, 0x58], :c => [0x20, 0x0D], :x => [0x41], :y => [0x53],
                          :z => [0x44], :l => [0x51], :r => [0x57] }

    # Whether a key goes with the Shift held: Ctrl, Alt, the mod's menu, a text field, or a key of the mod's, of a game
    # button or an arrow.
    def self.shift_chord?
      kb = PokeAccess::Keyboard
      return true if kb.raw_down?(kb::VK_CONTROL) || kb.raw_down?(kb::VK_ALT)
      return true if PokeAccess::ConfigMenu.active? || PokeAccess::Keys.typing?
      keys = codes_in_use.compact.map { |c| kb.key_of(c) } + native_buttons.values.flatten + ARROW_VKS
      keys.any? { |vk| !SHIFT_VKS.include?(vk) && kb.raw_down?(vk) }
    end

    # Whether the game's trigger and repeat of a button wait for its Shift to be let go (watch_shift): the button
    # shares the Shift the mod's gestures use, held or let go this frame, and none of its other keys is down; never in a
    # text field, nor on a frame the mod is off or the window behind.
    def self.shift_late?(bi)
      return false unless @live && @shift_at && (@shift_was || @shift_tap)
      return false unless sym_for_button(bi) == @shift_at[0] && !PokeAccess::Keys.typing?
      kb = PokeAccess::Keyboard
      @shift_at[2].none? { |vk| kb.raw_down?(vk) }
    end

    # True on the frame the Shift of a button that waits for it (shift_late?) is let go with no other key.
    def self.shift_tap?; @shift_tap ? true : false; end

    # Whether the game reads its Alt late now: Alt down, or let go since the last pulse, with an action on Alt plus a key
    # and the game's Alt unbound. Asked at each read, as a game may read Alt inside its own Input.update, before the pulse.
    def self.alt_late?
      kb = PokeAccess::Keyboard
      return false unless kb.raw_down?(kb::VK_ALT) || @alt_was
      codes_in_use.any? { |code| code && kb.alt_code?(code) } && !bound_code(:alt)
    end

    # The key codes actions answer now: the player's bindings, the mod's keys (those of FIELD_MOD_KEYS out of a battle
    # alone) and what the profile ships; nil for none.
    def self.codes_in_use
      binds = (PokeAccess::Config.rebinds rescue nil) || {}
      keys = (PokeAccess::Config.keys rescue nil) || {}
      keys = keys.reject { |sym, _code| FIELD_MOD_KEYS.include?(sym) } if (PokeAccess::Battle.in_battle? rescue false)
      binds.values + keys.values + defaults.keys.map { |sym| binds[sym] ? nil : shipped(sym) }
    end

    # Whether a key code counts as held this frame (running: it already counts). A key with Alt counts from when it goes
    # down with Alt held. A key on its own counts while down, but with an action on Alt plus it, only from its own press
    # with no Alt held, so letting Alt go first or tapping it starts nothing.
    def self.code_held?(code, running)
      kb = PokeAccess::Keyboard
      vk = kb.key_of(code)
      pressed = kb.pressed?(vk)
      return false unless kb.raw_down?(vk)
      alt = kb.alt_held?
      return alt && (running || pressed) if kb.alt_code?(code)
      return false if kb.window_switch?(vk)
      !alt_bound?(vk) || (!alt && (running || pressed))
    end

    # True on the frame a key code goes down, for the mod's own keys: a key on its own yields, with Alt held, to an action
    # on Alt plus it.
    def self.code_pressed?(code)
      kb = PokeAccess::Keyboard
      return false unless kb.code_pressed?(code)
      return @alt_used = true if kb.alt_code?(code)
      return false if kb.window_switch?(code)
      !(kb.alt_held? && alt_bound?(code))
    end

    # Whether an action answers Alt plus this virtual-key now.
    def self.alt_bound?(vk)
      codes_in_use.include?(PokeAccess::Keyboard.with_alt(vk))
    end

    # True while the bound key for an action is held.
    def self.pressed_sym?(sym); (@held[sym] || 0) > 0; end

    # True only on the frame the bound key for an action transitions to pressed.
    def self.triggered_sym?(sym); (@held[sym] || 0) == 1; end

    # True on press and then on the schedule the game's own keys repeat on (repeat_schedule), for menu navigation.
    def self.repeated_sym?(sym)
      h = @held[sym] || 0
      return h == 1 if h <= 1
      start, every = repeat_schedule
      h > start && h % every == 0
    end

    # The repeat schedule of the input the game reads: its own in Ruby (NativeKeys.native_input? false), mkxp-z's by
    # time from TIMED_REPEAT_SINCE, else mkxp-z's by frames.
    def self.repeat_schedule
      return RUBY_INPUT_REPEAT unless (PokeAccess::NativeKeys.native_input? rescue true)
      return FRAME_REPEAT if (mkxp_version <=> TIMED_REPEAT_SINCE) < 0
      timed_repeat(repeat_fps)
    end

    # mkxp-z's version as numbers ([2, 4, 2]) from System::VERSION, read once: [2, 2] where it reads the unexpanded
    # MKXPZ_VERSION but System::CONFIG exists (2.2), none on an engine without either (1.3, or 2.1 by its VERSION).
    def self.mkxp_version
      @mkxp_version ||= begin
        v = (defined?(::System::VERSION) ? ::System::VERSION.to_s : "").scan(/\d+/).map { |d| d.to_i }
        v.empty? && defined?(::System::CONFIG) ? [2, 2] : v
      end
    end

    # mkxp-z's timed schedule at a frame rate, as its input works it out: the frame's length in single precision, the
    # 0.4 s wait and the 0.1 s interval each rounded up to whole frames; kept for the last rate asked.
    def self.timed_repeat(fps)
      return @timed[1] if @timed && @timed[0] == fps
      frame = [1.0 / fps].pack("e").unpack("e")[0]
      @timed = [fps, [(0.4 / frame).ceil, (0.1 / frame).ceil]]
      @timed[1]
    end

    # The frame rate mkxp-z's timed repeat counts by: mkxp.json's fixedFramerate; 40, the rate its input starts at,
    # under syncToRefreshrate, which never recounts it; else the game's frame rate within the engine's 10 to 120.
    def self.repeat_fps
      fixed, synced = engine_config
      return fixed if fixed > 0
      return 40 if synced
      [[(Graphics.frame_rate rescue 40).to_i, 10].max, 120].min
    end

    # mkxp.json's [fixedFramerate, syncToRefreshrate, whether rgssVersion is RGSS1 (1, or 0 and so the rxdata scripts
    # every Essentials game has)], its comment lines left out, read once; [0, false, true] without it.
    def self.engine_config
      @engine_config ||= begin
        text = File.exist?("mkxp.json") ? File.read("mkxp.json").gsub(/^\s*\/\/.*$/, "") : ""
        [text[/"fixedFramerate"\s*:\s*(\d+)/, 1].to_i, (text =~ /"syncToRefreshrate"\s*:\s*true/) ? true : false,
         text[/"rgssVersion"\s*:\s*(\d+)/, 1].to_i <= 1]
      rescue StandardError => e
        PokeAccess.swallowed(e)
        [0, false, true]
      end
    end

    #base-button queries (by Input integer)

    def self.pressed?(bi);   s = sym_for_button(bi); s ? pressed_sym?(s)   : false; end
    def self.triggered?(bi); s = sym_for_button(bi); s ? triggered_sym?(s) : false; end
    def self.repeated?(bi);  s = sym_for_button(bi); s ? repeated_sym?(s)  : false; end

    # True when no key has moved, by the player or by the profile: the Input wrappers' cheap early exit.
    def self.no_rebinds?
      h = (PokeAccess::Config.rebinds rescue nil)
      (h.nil? || h.empty?) && defaults.empty?
    end

    # True if a non-direction base button is bound, so its hook answers only the bound key (directions stay
    # additive), and for the game's Alt while it reads late (alt_late?); nothing is remapped without GAKS, nor on a frame
    # the mod is off or the window behind (see update).
    def self.remapped_button?(bi)
      return false unless PokeAccess::Keys::GAKS && @live
      return true if sym_for_button(bi) == :alt && alt_late?
      return false if no_rebinds?
      s = sym_for_button(bi)
      return false if s.nil? || DIR_CODE.key?(s)
      !bound_code(s).nil?
    end

    # True for the game's Alt where it reads late (alt_late?: an action on Alt plus a key, the game's Alt unbound): its
    # press? stays the engine's, the key as it is held (a turn in place while it is held), and only its trigger and
    # repeat wait for it to be let go.
    def self.alt_held_live?(bi)
      return false unless PokeAccess::Keys::GAKS && @live && sym_for_button(bi) == :alt && !bound_code(:alt)
      codes_in_use.any? { |code| code && PokeAccess::Keyboard.alt_code?(code) }
    end

    # The order bound directions are asked in, fixed (a 1.8.7 Hash has none) so two pressed on the same frame resolve
    # alike.
    DIR_ORDER = [:down, :left, :right, :up]

    # The 4-direction code from bound movement keys, or 0 if none held: of those held, the one pressed last (held the
    # fewest frames), as the engine's dir4 gives it.
    def self.dir
      sym = nil
      DIR_ORDER.each do |s|
        h = @held[s].to_i
        sym = s if h > 0 && (sym.nil? || h < @held[sym])
      end
      sym ? DIR_CODE[sym] : 0
    end

    #extra queries (by raw virtual-key)

    # True if the extra action for this raw key is bound, so triggerex? uses only the bound key; never on a frame the
    # mod is off or the window behind, nor in a text field, whose keys are letters.
    def self.extra_remapped?(vk)
      return false unless PokeAccess::Keys::GAKS && @live
      return false if no_rebinds? || PokeAccess::Keys.typing?
      s = sym_for_extra(vk)
      return false if s.nil?
      !bound_code(s).nil?
    end

    def self.extra_triggered?(vk); s = typing_free_extra(vk); s ? triggered_sym?(s) : false; end
    def self.extra_pressed?(vk);   s = typing_free_extra(vk); s ? pressed_sym?(s)   : false; end

    # The extra action for this raw key, or none in a text field.
    def self.typing_free_extra(vk)
      PokeAccess::Keys.typing? ? nil : sym_for_extra(vk)
    end
  end
end

# Input hooks feeding the bindings into the engine's: every read of the game's input answers nothing while the free
# camera holds it (Camera.blocking?), a button the mod's Ctrl+Alt gesture holds reads as up, a remapped button answers
# only its bound key, else engine or bound. Each forwards *args/*rest, since dir4/dir8 take an
# argument in La Base de Sky and none in vanilla.
begin
  class << Input
    unless method_defined?(:trigger__access_orig)
      [[:trigger?, :trigger__access_orig, :triggered?],
       [:press?,   :press__access_orig,   :pressed?],
       [:repeat?,  :repeat__access_orig,  :repeated?]].each do |meth, ali, query|
        PokeAccess::Hooks.keep_bound(self, meth) do |_again|
          alias_method ali, meth
          define_method(meth) do |n, *rest|
            if (PokeAccess::Camera.blocking? rescue false) || (PokeAccess::Remap.chord_button?(n) rescue false)
              false
            elsif query != :pressed? && (PokeAccess::Remap.shift_late?(n) rescue false)
              PokeAccess::Remap.shift_tap?
            elsif query == :pressed? && (PokeAccess::Remap.alt_held_live?(n) rescue false)
              send(ali, n, *rest)
            elsif (PokeAccess::Remap.remapped_button?(n) rescue false)
              (PokeAccess::Remap.send(query, n) rescue false)
            else
              send(ali, n, *rest) || (PokeAccess::Remap.send(query, n) rescue false)
            end
          end
        end
      end
      PokeAccess::Hooks.keep_bound(self, :dir4) do |_again|
        alias_method :dir4__access_orig, :dir4
        def dir4(*args)
          return 0 if (PokeAccess::Camera.blocking? rescue false)
          d = dir4__access_orig(*args)
          d != 0 ? d : (PokeAccess::Remap.dir rescue 0)
        end
      end
      PokeAccess::Hooks.keep_bound(self, :dir8) do |_again|
        alias_method :dir8__access_orig, :dir8
        def dir8(*args)
          return 0 if (PokeAccess::Camera.blocking? rescue false)
          d = dir8__access_orig(*args)
          d != 0 ? d : (PokeAccess::Remap.dir rescue 0)
        end
      end
    end

    # Raw-key hooks for the game extras, only where the engine has them.
    [[:triggerex?, :triggerex__access_orig, :extra_triggered?],
     [:pressex?,   :pressex__access_orig,   :extra_pressed?]].each do |meth, ali, query|
      next unless method_defined?(meth)
      next if method_defined?(ali)
      PokeAccess::Hooks.keep_bound(self, meth) do |_again|
        alias_method ali, meth
        define_method(meth) do |k, *rest|
          if (PokeAccess::Camera.blocking? rescue false)
            false
          elsif (PokeAccess::Remap.extra_remapped?(k) rescue false)
            (PokeAccess::Remap.send(query, k) rescue false)
          else
            send(ali, k, *rest) || (PokeAccess::Remap.send(query, k) rescue false)
          end
        end
      end
    end

    # The other reads (HELD_READS), only where the engine or the game has them: what they answer while the free camera
    # holds the input, else theirs.
    PokeAccess::Remap::HELD_READS.each do |meth, idle|
      ali = :"#{meth.to_s.delete('?')}__access_orig"
      next unless method_defined?(meth)
      next if method_defined?(ali)
      PokeAccess::Hooks.keep_bound(self, meth) do |_again|
        alias_method ali, meth
        define_method(meth) { |*args| (PokeAccess::Camera.blocking? rescue false) ? idle : send(ali, *args) }
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_input_remap: #{e.message}\n")
end
