module PokeAccess
  # Optional key remapper: tracks how long each bound key has been held and feeds that into the engine's
  # input. Two action kinds -- base RPG Maker buttons and game extras bound to a raw virtual-key
  # (registered via register_extra). A rebound action silences the engine's default key, except directions
  # (kept additive so movement stays safe). Every addition is rescued, so a bug here can't take control away.
  module Remap
    REPEAT_DELAY = 15
    REPEAT_INTERVAL = 6

    # Base buttons: [action symbol, Input constant name, label key].
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
      [:r,     :R,     :btn_r]
    ]
    DIR_CODE = { :up => 8, :down => 2, :left => 4, :right => 6 }

    # The mod's OWN hotkeys, offered in the same remap list as the game's buttons but living in a different
    # table (Config.keys) with different semantics -- see conflict? and the menu's clear step. Order is the
    # one a player thinks in: the locator cluster first, then the readers, then the modifiers.
    MOD_KEYS = [
      [:prev,   :rmk_prev],   [:next,  :rmk_next],  [:where,  :rmk_where],
      [:route,  :rmk_route],  [:info,  :rmk_info],  [:hp,     :rmk_hp],
      [:field,  :rmk_field],  [:coords, :rmk_coords], [:config, :rmk_config],
      [:shift,  :rmk_shift],  [:ctrl,  :rmk_ctrl]
    ]

    # Virtual-keys the engine itself answers to. They are not ours to give away: bound to a mod action, the
    # player would confirm a message and read the screen with the same press, and in a yes/no box that is
    # unrecoverable. Enter/Space/Escape, the four arrows, and F8-F10 (the mod's fixed Ctrl+Alt gestures,
    # which are deliberately NOT remappable so there is always a way back from a bad binding).
    RESERVED = {
      0x0D => :rmp_key_enter, 0x1B => :rmp_key_escape, 0x20 => :rmp_key_space,
      0x25 => :rmp_key_left,  0x26 => :rmp_key_up,     0x27 => :rmp_key_right, 0x28 => :rmp_key_down,
      0x77 => :rmp_key_f8,    0x78 => :rmp_key_f9,     0x79 => :rmp_key_f10
    }
    @held = {}

    # True when sym is one of the mod's own hotkeys rather than a game button or a game extra.
    def self.mod_action?(sym)
      MOD_KEYS.assoc(sym) ? true : false
    end

    # What already uses this virtual-key, as an i18n key or an action symbol, or nil when it is free.
    #
    # ONE check for BOTH assignment paths, because the tables can collide with each other: before this, the
    # menu compared game buttons only against other game buttons, so binding the game's A to T silently
    # made T do two things at once -- the mod key kept working and nothing warned. Excludes the action
    # being assigned, so rebinding a key to itself is not a conflict.
    def self.conflict(code, action)
      return nil if code.nil?
      return RESERVED[code] if RESERVED.has_key?(code)
      hit = nil
      (PokeAccess::Config.rebinds rescue {}).each { |s, c| hit ||= s if c == code && s != action }
      (PokeAccess::Config.keys rescue {}).each { |s, c| hit ||= s if c == code && s != action }
      hit
    end

    # The registry of game extras: action symbol => [default virtual-key, label].
    def self.extras; @extras ||= {}; end

    # Registers a game-specific action read by raw virtual-key, so it can be rebound from the remap menu.
    def self.register_extra(sym, default_vk, label)
      extras[sym] = [default_vk, label]
    end

    # The full remap-menu action list: base buttons, game extras, and a final reset-all entry.
    # Built on a duped array with concat/push, never BUTTONS + [...]: a fangame script patch
    # redefines Array#+ as an in-place mutator, so the literal `+` would corrupt the constant.
    def self.buttons
      list = BUTTONS.dup
      list.concat(extras.map { |sym, info| [sym, nil, info[1]] })
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

    # Spoken label for an action (a per-game override wins); resolved through I18n, where an unknown
    # key returns itself. Looked up in `buttons`, the SAME list the remap menu shows, rather than in
    # BUTTONS plus extras separately: the reset-all row lives only in that assembled list, so the split
    # lookup missed it and the menu would have said "underscore underscore reset" while its perfectly
    # good btn_reset_all string sat unused in both languages.
    def self.label(sym)
      row = buttons.assoc(sym)
      raw = (PokeAccess::Config.rebind_labels[sym] rescue nil) || (row ? row[2] : nil) || sym.to_s
      PokeAccess::I18n.t(raw)
    end

    # The base action bound to an Input button integer, if any.
    def self.sym_for_button(bi); int_sym_map[bi]; end

    # The extra action whose default key is this raw virtual-key, if any.
    def self.sym_for_extra(vk)
      hit = extras.detect { |_sym, info| info[0] == vk }
      hit ? hit[0] : nil
    end

    #per-frame polling

    # Updates how long each bound key has been held; call once per frame.
    def self.update
      return unless PokeAccess::Keys::GAKS
      unless (PokeAccess::Keys.enabled rescue true) && (PokeAccess::Keys.focused? rescue true)
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

    # True on press and then on the repeat schedule, for menu navigation.
    def self.repeated_sym?(sym)
      h = @held[sym] || 0
      h == 1 || (h > REPEAT_DELAY && ((h - REPEAT_DELAY) % REPEAT_INTERVAL) == 0)
    end

    #base-button queries (by Input integer)

    def self.pressed?(bi);   s = sym_for_button(bi); s ? pressed_sym?(s)   : false; end
    def self.triggered?(bi); s = sym_for_button(bi); s ? triggered_sym?(s) : false; end
    def self.repeated?(bi);  s = sym_for_button(bi); s ? repeated_sym?(s)  : false; end

    # True if a non-direction base button is bound, so its hook uses only the bound key and lets the
    # engine's default key go silent (directions are never suppressed; a missing GAKS can't lock input).
    def self.remapped_button?(bi)
      return false unless PokeAccess::Keys::GAKS
      s = sym_for_button(bi)
      return false if s.nil? || DIR_CODE.has_key?(s)
      !(PokeAccess::Config.rebinds[s] rescue nil).nil?
    end

    # The 4-direction code from bound movement keys, or 0 if none held.
    def self.dir
      hit = DIR_CODE.detect { |sym, _code| pressed_sym?(sym) }
      hit ? hit[1] : 0
    end

    #extra queries (by raw virtual-key)

    # True if the extra action for this raw key is bound, so triggerex? uses only the bound key.
    def self.extra_remapped?(vk)
      return false unless PokeAccess::Keys::GAKS
      s = sym_for_extra(vk)
      return false if s.nil?
      !(PokeAccess::Config.rebinds[s] rescue nil).nil?
    end

    def self.extra_triggered?(vk); s = sym_for_extra(vk); s ? triggered_sym?(s) : false; end
    def self.extra_pressed?(vk);   s = sym_for_extra(vk); s ? pressed_sym?(s)   : false; end
  end
end

# Input hooks: feed our bindings into the engine's, rescued so they can never break input. Each wrapper
# forwards *args/*rest to the original so it matches whatever signature the base uses -- La Base de Sky's
# dir4/dir8 take an argument while vanilla Essentials' take none, so a fixed arity here crashed Sky games.
# The five query hooks share one pattern (remapped -> only ours; else engine OR ours), so they are
# generated from a table -- one source for a body that must never diverge between them. dir4/dir8 keep
# their own (different) shape.
begin
  class << Input
    unless method_defined?(:trigger__access_orig)
      [[:trigger?, :trigger__access_orig, :triggered?],
       [:press?,   :press__access_orig,   :pressed?],
       [:repeat?,  :repeat__access_orig,  :repeated?]].each do |meth, ali, query|
        alias_method ali, meth
        define_method(meth) do |n, *rest|
          if (PokeAccess::Remap.remapped_button?(n) rescue false)
            (PokeAccess::Remap.send(query, n) rescue false)
          else
            send(ali, n, *rest) || (PokeAccess::Remap.send(query, n) rescue false)
          end
        end
      end
      alias_method :dir4__access_orig, :dir4
      def dir4(*args); d = dir4__access_orig(*args); d != 0 ? d : (PokeAccess::Remap.dir rescue 0); end
      alias_method :dir8__access_orig, :dir8
      def dir8(*args); d = dir8__access_orig(*args); d != 0 ? d : (PokeAccess::Remap.dir rescue 0); end
    end

    #raw-key hooks for game extras, only if the engine exposes them.
    [[:triggerex?, :triggerex__access_orig, :extra_triggered?],
     [:pressex?,   :pressex__access_orig,   :extra_pressed?]].each do |meth, ali, query|
      next unless method_defined?(meth)
      next if method_defined?(ali)
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
rescue StandardError => e
  PokeAccess.write_marker("hook_input_remap: #{e.message}\n")
end
