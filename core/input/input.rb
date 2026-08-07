module PokeAccess
  # The input ORCHESTRATOR (named PokeAccess::Keys to avoid clashing with RGSS ::Input). What lives here is
  # what only makes sense for THIS mod: whether the mod is enabled, the once-per-frame global poll, the
  # suppression windows that keep it from eating the game's own keys, the resolution of a configured key
  # NAME to an actual keystroke, and the per-frame poller registry. Raw keyboard polling and edge detection
  # belong to PokeAccess::Keyboard and window focus to PokeAccess::Focus, both delegated to from here, while
  # the diagnostic half lives in input/diag.rb, which reopens this module. Every name other files call on
  # Keys still answers here: the moved ones as one-line delegations, GAKS/GFW/GAW/GCPID as re-exports.
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

    # Records the game window handle while focused, so focused? survives a fullscreen toggle. Delegates
    # to Focus.
    def self.mark_focused; PokeAccess::Focus.mark_focused; end

    # True only on the frame one of the mod's global gestures fires: Ctrl+Alt+<function key>, the shape all
    # three of them share (F8 toggle, F9 diag dump, F10 spoken diag). slot keeps their edges independent.
    def self.hotkey?(slot, fkey)
      kb = PokeAccess::Keyboard
      kb.combo_triggered?(slot, kb::VK_CONTROL, kb::VK_ALT, fkey)
    end

    # Toggles the whole mod on/off with Ctrl+Alt+F8 (edge-triggered); polled even while disabled.
    # Re-enabling also retries a failed speech init (see PokeAccess.retry_init!), so the off/on gesture
    # doubles as "reconnect the voice" when no engine could start at boot.
    def self.toggle_poll
      return unless hotkey?(:mod_toggle, PokeAccess::Keyboard::VK_F8)
      @enabled = !@enabled
      (PokeAccess.retry_init! rescue nil) if @enabled
      PokeAccess.speak(PokeAccess::I18n.t(@enabled ? :mod_on : :mod_off), true)
    end

    # Call while a text field is active so typed letters are not treated as commands; decays over a few
    # frames. Suppresses EVERY mod key (a typed "t" must enter the letter, not read info).
    def self.typing!
      @typing_ttl = 4
    end

    # Call while a custom MENU with its own raw-key input is active (e.g. a fangame's raw-key pause/party loops),
    # so the mod's movement/command keys do not clash with the game's -- but the read-only info keys still
    # work, so the player can query the focused option. Decays over a few frames, like typing!.
    def self.menu_lock!
      @menu_lock_ttl = 4
    end

    # True only on the frame a configured key (by Config.keys name) transitions to pressed. The mapping
    # name -> virtual-key is the mod's (the player rebinds it); the edge itself is Keyboard's, watched
    # under the key name as its slot. An unbound name is simply never pressed.
    def self.key(name)
      code = PokeAccess::Config.keys[name]
      return false unless code
      hit = PokeAccess::Keyboard.triggered?(name, code)
      (PokeAccess::Recorder.note_key(name) rescue nil) if hit
      hit
    end

    # True while the shift key is held. Reads Config.keys, not the hardware VK_SHIFT: the modifier the
    # info/locator keys pair with is configurable, so this is a mod question, not a keyboard one.
    def self.shift_down?
      PokeAccess::Keyboard.raw_down?(PokeAccess::Config.keys[:shift])
    end

    # True while the control key is held (configurable, like shift_down?).
    def self.ctrl_down?
      PokeAccess::Keyboard.raw_down?(PokeAccess::Config.keys[:ctrl])
    end

    # Whether the puzzle reader should answer the info key.
    #
    # Only on the map, under free control. A puzzle whose definition declares no solved state stays active
    # for the rest of the session, and without this it answered the info key inside the bag, the party and
    # the battle menus too -- where the potion's description, the focused member or the move's power are
    # the fresher answer and the only one the screen is showing.
    def self.puzzle_owns_info?
      return false if (PokeAccess::Spatial.keys_locked? rescue false)
      return false unless ($scene.is_a?(Scene_Map) rescue true)
      (PokeAccess::Puzzles.active? rescue false)
    rescue StandardError
      false
    end

    # Reads contextual keys that work in every scene (info, hp, field, coords).
    def self.global_poll
      toggle_poll
      diag_poll
      spoken_diag_poll
      return unless @enabled
      return unless focused?
      if @typing_ttl > 0
        @typing_ttl -= 1
        return
      end
      menu_locked = (@menu_lock_ttl ||= 0) > 0
      @menu_lock_ttl -= 1 if menu_locked
      return if PokeAccess::ConfigMenu.active?
      if !menu_locked && key(:config)
        PokeAccess::ConfigMenu.open
        return
      end
      if key(:info)
        if shift_down?
          d = PokeAccess.last_dialogue
          PokeAccess.speak((d && !d.to_s.empty?) ? d : PokeAccess::I18n.t(:no_recent_dialogue), true)
        elsif puzzle_owns_info?
          PokeAccess::Puzzles.read
        else
          t = PokeAccess::Info.info_text
          PokeAccess.speak(t, true) if t && !t.to_s.empty?
        end
      elsif key(:hp)
        PokeAccess::Battle.announce_hp(shift_down?)
      elsif key(:field)
        PokeAccess::Battle.announce_field
      elsif key(:coords)
        if ctrl_down?
          PokeAccess::Locator.toggle_hide_unreachable
        elsif shift_down?
          PokeAccess::Locator.rename_map
        else
          PokeAccess::Locator.announce_coords unless (PokeAccess::Spatial.busy? rescue false)
        end
      end
    end

    # Registers a block to run once per frame (after the global poll), in every scene -- for menus the
    # engine runs in its own blocking loop. Exposed to profiles as Game.define's poll_each_frame.
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

# Input hook: runs the global poll and the per-frame pollers every frame, in every context.
#
# Measured as :input_frame, the only label that reports from EVERYWHERE: the other two measured hooks hang
# off Game_Player#update and fall silent the moment the player opens a menu or enters a battle, while the
# diagnostic would still print their averages. Everything the mod does per frame outside the map goes
# through here -- the remap wrappers, the global key poll and every registered frame poller, the modal-loop
# readers among them. One label rather than three keeps it to two clock reads a frame.
#
# Guarded as a whole: each step already swallows its own failure, but a fault in the measuring itself would
# propagate out of Input.update and take the game down.
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
