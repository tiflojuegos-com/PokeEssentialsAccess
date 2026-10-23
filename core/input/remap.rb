module PokeAccess
  # Optional key remapper: tracks how long each bound key has been held and feeds it into the engine's input, for
  # base buttons and game extras (register_extra). A rebound action silences the engine's key, except directions,
  # while the mod is on and the game window in front.
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
      [:shift,  :rmk_shift],  [:ctrl,  :rmk_ctrl]
    ]

    # Virtual-keys no action may take: Enter, Space, Escape and the arrows, which the engine answers, F1, F2 and F12,
    # which open the engine's settings window (mouse only), show its frame rate and reset the game, and F8-F10, the
    # mod's fixed Ctrl+Alt gestures.
    RESERVED = {
      0x0D => :rmp_key_enter, 0x1B => :rmp_key_escape, 0x20 => :rmp_key_space,
      0x25 => :rmp_key_left,  0x26 => :rmp_key_up,     0x27 => :rmp_key_right, 0x28 => :rmp_key_down,
      0x70 => :rmp_key_f1,    0x71 => :rmp_key_f2,     0x7B => :rmp_key_f12,
      0x77 => :rmp_key_f8,    0x78 => :rmp_key_f9,     0x79 => :rmp_key_f10
    }
    @held = {}
    @live = true

    # True when sym is one of the mod's own hotkeys rather than a game button or a game extra.
    def self.mod_action?(sym)
      MOD_KEYS.assoc(sym) ? true : false
    end

    # What already uses this virtual-key across the game's rebinds, the mod's keys and the game extras still on the
    # raw key the game reads them by: a reserved key's i18n key or another action's symbol, or nil when free.
    def self.conflict(code, action)
      return nil if code.nil?
      return RESERVED[code] if RESERVED.key?(code)
      binds = (PokeAccess::Config.rebinds rescue nil) || {}
      hit = nil
      binds.each { |s, c| hit ||= s if c == code && s != action }
      (PokeAccess::Config.keys rescue {}).each { |s, c| hit ||= s if c == code && s != action }
      extras.each { |s, vk, _l| hit ||= s if vk == code && s != action && binds[s].nil? }
      hit
    end

    # The game extras as [action symbol, default virtual-key, label] rows, in registration order (an Array, since a
    # Hash has no order under 1.8.7).
    def self.extras; @extras ||= []; end

    # Registers a game-specific action read by raw virtual-key, so it can be rebound from the remap menu.
    # Registering a symbol again replaces its row in place.
    def self.register_extra(sym, default_vk, label)
      extras.reject! { |row| row[0] == sym }
      extras.push([sym, default_vk, label])
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

    # The base action bound to an Input button integer, if any.
    def self.sym_for_button(bi); int_sym_map[bi]; end

    # The extra action whose default key is this raw virtual-key, if any.
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
        return
      end
      binds = (PokeAccess::Config.rebinds rescue nil)
      if binds.nil? || binds.empty?
        @held = {} unless @held.empty?
        return
      end
      @held.each_key { |s| @held[s] = 0 unless binds.key?(s) }
      binds.each do |sym, code|
        next unless code
        down = PokeAccess::Keyboard.raw_down?(code)
        @held[sym] = down ? (@held[sym].to_i + 1) : 0
      end
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

    # mkxp.json's [fixedFramerate, syncToRefreshrate], its comment lines left out, read once; [0, false] without it.
    def self.engine_config
      @engine_config ||= begin
        text = File.exist?("mkxp.json") ? File.read("mkxp.json").gsub(/^\s*\/\/.*$/, "") : ""
        [text[/"fixedFramerate"\s*:\s*(\d+)/, 1].to_i, (text =~ /"syncToRefreshrate"\s*:\s*true/) ? true : false]
      rescue StandardError => e
        PokeAccess.swallowed(e)
        [0, false]
      end
    end

    #base-button queries (by Input integer)

    def self.pressed?(bi);   s = sym_for_button(bi); s ? pressed_sym?(s)   : false; end
    def self.triggered?(bi); s = sym_for_button(bi); s ? triggered_sym?(s) : false; end
    def self.repeated?(bi);  s = sym_for_button(bi); s ? repeated_sym?(s)  : false; end

    # True when the player has not rebound a single key: the Input wrappers' cheap early exit.
    def self.no_rebinds?
      h = (PokeAccess::Config.rebinds rescue nil)
      h.nil? || h.empty?
    end

    # True if a non-direction base button is bound, so its hook answers only the bound key (directions stay
    # additive); nothing is remapped without GAKS, nor on a frame the mod is off or the window behind (see update).
    def self.remapped_button?(bi)
      return false unless PokeAccess::Keys::GAKS && @live
      return false if no_rebinds?
      s = sym_for_button(bi)
      return false if s.nil? || DIR_CODE.key?(s)
      !(PokeAccess::Config.rebinds[s] rescue nil).nil?
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
    # mod is off or the window behind.
    def self.extra_remapped?(vk)
      return false unless PokeAccess::Keys::GAKS && @live
      return false if no_rebinds?
      s = sym_for_extra(vk)
      return false if s.nil?
      !(PokeAccess::Config.rebinds[s] rescue nil).nil?
    end

    def self.extra_triggered?(vk); s = sym_for_extra(vk); s ? triggered_sym?(s) : false; end
    def self.extra_pressed?(vk);   s = sym_for_extra(vk); s ? pressed_sym?(s)   : false; end
  end
end

# Input hooks feeding the bindings into the engine's: a button the mod's Ctrl+Alt gesture holds reads as up, a
# remapped button answers only its bound key, else engine or bound. Each forwards *args/*rest, since dir4/dir8 take an
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
            if (PokeAccess::Remap.chord_button?(n) rescue false)
              false
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
        def dir4(*args); d = dir4__access_orig(*args); d != 0 ? d : (PokeAccess::Remap.dir rescue 0); end
      end
      PokeAccess::Hooks.keep_bound(self, :dir8) do |_again|
        alias_method :dir8__access_orig, :dir8
        def dir8(*args); d = dir8__access_orig(*args); d != 0 ? d : (PokeAccess::Remap.dir rescue 0); end
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
          if (PokeAccess::Remap.extra_remapped?(k) rescue false)
            (PokeAccess::Remap.send(query, k) rescue false)
          else
            send(ali, k, *rest) || (PokeAccess::Remap.send(query, k) rescue false)
          end
        end
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_input_remap: #{e.message}\n")
end
