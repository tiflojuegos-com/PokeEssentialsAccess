module PokeAccess
  # The input orchestrator (PokeAccess::Keys, not RGSS ::Input): the mod's on/off, the global poll, the suppression
  # windows, configured key names and the per-frame pollers. Raw keys are Keyboard's and focus is Focus's, reached
  # through delegations and re-exports; the diagnostics live in input/diag.rb.
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
    # three of them share (F8 toggle, F9 diag dump, F10 spoken diag). slot keeps their edges independent.
    def self.hotkey?(slot, fkey)
      kb = PokeAccess::Keyboard
      kb.combo_triggered?(slot, kb::VK_CONTROL, kb::VK_ALT, fkey)
    end

    # Toggles the whole mod with Ctrl+Alt+F8, polled even while disabled; re-enabling retries a failed speech init.
    def self.toggle_poll
      return unless hotkey?(:mod_toggle, PokeAccess::Keyboard::VK_F8)
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
      hit = PokeAccess::Keyboard.triggered?(name, code)
      (PokeAccess::Recorder.note_key(name) rescue nil) if hit
      hit
    end

    # True while the configured shift key (Config.keys[:shift]) is held.
    def self.shift_down?
      PokeAccess::Keyboard.raw_down?(PokeAccess::Config.keys[:shift])
    end

    # True while the control key is held (configurable, like shift_down?).
    def self.ctrl_down?
      PokeAccess::Keyboard.raw_down?(PokeAccess::Config.keys[:ctrl])
    end

    # Whether the puzzle reader answers the info key: only on the map under free control, since a puzzle with no
    # solved state stays active all session.
    def self.puzzle_owns_info?
      return false if (PokeAccess::Spatial.keys_locked? rescue false)
      return false unless ($scene.is_a?(Scene_Map) rescue true)
      (PokeAccess::Puzzles.active? rescue false)
    rescue StandardError
      false
    end

    # The once-per-frame poll: the global hotkeys, then the contextual keys (info, hp, field, history, verbosity) and
    # the coordinates key, this one only while the player is free; each answer is filed under its category.
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
      elsif key(:coords) && !(PokeAccess::Spatial.busy? rescue false)
        PokeAccess::Speech.as(:nav) { coords_key }
      elsif key(:hist_prev)
        history_key(-1)
      elsif key(:hist_next)
        history_key(1)
      elsif key(:verbosity)
        PokeAccess::Verbosity.rotate_scheme
      end
    end

    # The info key: the last dialogue with shift, the focused row whole with ctrl, a puzzle's state on the map, else
    # what the screen published. Ctrl on a screen with no row says what the key alone says.
    def self.info_key
      row = ctrl_down? ? PokeAccess::Info.row_text : nil
      if shift_down?
        d = PokeAccess.last_dialogue
        PokeAccess.speak((d && !d.to_s.empty?) ? d : PokeAccess::I18n.t(:no_recent_dialogue), true)
      elsif row
        PokeAccess.speak(row, true)
      elsif puzzle_owns_info?
        PokeAccess::Puzzles.read
      else
        PokeAccess.speak(PokeAccess::Info.info_text, true)
      end
    end

    # The field key: a marker on the player's tile with ctrl (navigation), else the conditions (information).
    def self.field_key
      if ctrl_down?
        PokeAccess::Speech.as(:nav) { PokeAccess::Locator.mark_here }
      else
        PokeAccess::Speech.as(:info) { PokeAccess::Battle.announce_field }
      end
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

    # Registers a block to run once per frame after the global poll, in every scene (Game.define's poll_each_frame).
    def self.on_frame(&blk); (@frame_pollers ||= []) << blk if blk; end

    # Runs every registered per-frame callback, each guarded so one failure cannot stop the others.
    def self.run_frame_pollers
      (@frame_pollers || []).each_with_index do |cb, i|
        begin
          cb.call
        rescue StandardError => e
          PokeAccess.log_once("frame_poller_#{i}", e)
        end
      end
    end
  end
end

# Input.update hook: the remap, the global poll and every per-frame poller, each frame in every context, measured
# as :input_frame and guarded as a whole.
begin
  class << Input
    unless method_defined?(:update__access_orig)
      alias_method :update__access_orig, :update
      def update(*a)
        r = update__access_orig(*a)
        begin
          PokeAccess::Perf.measure(:input_frame) do
            begin; PokeAccess::Remap.update; rescue StandardError => e; PokeAccess.log_once("remap_update", e); end
            begin; PokeAccess::Keys.global_poll; rescue StandardError => e; PokeAccess.log_once("global_poll", e); end
            begin; PokeAccess::Keys.run_frame_pollers; rescue StandardError => e; PokeAccess.log_once("frame_pollers", e); end
          end
        rescue StandardError => e
          PokeAccess.log_once("input_frame", e)
        end
        r
      end
    end
  end
rescue StandardError => e
  PokeAccess.write_marker("hook_input: #{e.message}\n")
end
