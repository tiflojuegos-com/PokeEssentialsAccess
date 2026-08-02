module PokeAccess
  # Session recorder: turns a real play session into a TRANSCRIPT -- what the mod saw and what it said,
  # in order. Two uses, one file: a tester who hears the mod go quiet hands over a recording instead of
  # trying to describe the moment, and test/support/replay.rb audits the same file automatically for the
  # three failure modes that matter (a cursor that moved without speaking, the same line twice in a row,
  # a reader that spoke raw control codes).
  #
  # It costs nothing when off: the speech observer is nil and the frame sampler returns on a boolean.
  # It hooks NOTHING inside the readers -- everything it knows arrives through PokeAccess.on_speak and a
  # per-frame read of state the mod already keeps -- so a reader can never be broken by the instrument.
  #
  # Line format (tab-separated, text always last so a tab can never split it; the auditor parses it):
  #   # pea-recording 1 <engine kind>  <engine version>  <fork>
  #   <seconds>  map    <map_id>  <name>
  #   <seconds>  pos    <x>  <y>
  #   <seconds>  scene  <class>
  #   <seconds>  sel    <index>  <target name>
  #   <seconds>  say    <0|1 interrupt>  <text>
  #   <seconds>  in     <what>
  #   <seconds>  diag   <why>  <one line of a diagnostic section>
  module Recorder
    DIR = "#{PokeAccess::Paths::DATA}/recordings"
    FLUSH_EVERY = 120
    HEADER = /\A=== PokeAccess diag/

    # Diagnostic sections dumped into the transcript, so a report answers "what did the mod SEE", not
    # just what it said: the nearby objects and their classification, the reachable-tiles flood and the
    # route, the surfaces, the active scene. They are the diag's own sections -- including any a profile
    # registered -- so the recorder never grows a second, drifting copy of that knowledge.
    # diag_perf and diag_polls are deliberately absent: the first RESETS the performance window it
    # reads (it would falsify the player's own measurements) and the second runs a 5000-iteration
    # micro-benchmark, which is fine on a keypress and absurd on every map change.
    SNAP_START = [:diag_focus, :diag_map, :diag_locator, :diag_pathfinder, :diag_surface,
                  :diag_audio3d, :diag_scene, :diag_runtime]
    SNAP_MAP   = [:diag_map, :diag_locator, :diag_pathfinder, :diag_surface]
    SNAP_SCENE = [:diag_scene]
    @on = false
    @lines = []
    @path = nil
    @seen = {}
    @count = 0
    @pending = []
    @last_snap = {}

    def self.recording?; @on; end

    # The file the current (or last) recording writes to, or nil.
    def self.path; @path; end

    # Starts a recording: opens a timestamped file, installs the speech observer and clears the change
    # tracker so the first frame writes a full picture. Returns the file name, or nil if it could not start.
    def self.start
      return nil if @on
      (Dir.mkdir(PokeAccess::Paths::DATA) rescue nil)
      (Dir.mkdir(DIR) rescue nil)
      stamp = Time.now.strftime("%Y%m%d-%H%M%S")
      @path = "#{DIR}/rec-#{stamp}.txt"
      @lines = []
      @seen = {}
      @count = 0
      @pending = []
      @last_snap = {}
      @on = true
      e = PokeAccess::Engine
      @lines.push("# pea-recording 1\t#{e.kind rescue '?'}\t#{e.version rescue '?'}\t#{e.fork.inspect rescue '?'}")
      PokeAccess.on_speak = lambda { |text, interrupt| note("say", interrupt ? 1 : 0, text) }
      snapshot(SNAP_START, "start")
      flush
      File.basename(@path)
    rescue StandardError
      @on = false
      nil
    end

    # Stops the recording, removes the observer and writes what is pending. Returns the number of events
    # in the WHOLE session -- counted as they are noted, never as the buffer length: flush empties the
    # buffer every FLUSH_EVERY lines, so a 500-event session would have reported the ~20 still pending
    # and the menu would have said so out loud.
    def self.stop
      return 0 unless @on
      @on = false
      PokeAccess.on_speak = nil
      flush
      @count
    rescue StandardError
      0
    end

    # Starts or stops, whichever applies -- the single debug-menu gesture.
    def self.toggle
      @on ? stop : start
    end

    # Appends one event. The text field is stripped of tabs and newlines so a line can never be split.
    def self.note(kind, *fields)
      return unless @on
      clean = fields.map { |f| f.to_s.gsub(/[\t\r\n]+/, " ") }
      @lines.push("#{sprintf('%.2f', PokeAccess.clock)}\t#{kind}\t#{clean.join("\t")}")
      @count += 1
      flush if @lines.length >= FLUSH_EVERY
    rescue StandardError
      nil
    end

    # Writes the buffered lines and empties the buffer. Buffered rather than per-event so a per-frame
    # sampler cannot turn into a file write per frame.
    def self.flush
      return if @path.nil? || @lines.empty?
      pending = @lines
      @lines = []
      File.open(@path, "a") { |f| f.write(pending.join("\n") + "\n") }
    rescue StandardError
      nil
    end

    # Records a field only when it CHANGED, so the transcript stays a list of events instead of a dump
    # of every frame. Returns whether it wrote, so a caller can hang a snapshot off the same change.
    def self.on_change(kind, key, *fields)
      return false if @seen[key] == fields
      @seen[key] = fields
      note(kind, *fields)
      true
    end

    # Dumps the given diagnostic sections into the transcript, one row per line, tagged with WHY it was
    # taken (start / map / scene). Each line rides the normal event format, so the auditor -- which only
    # reads say/sel/pos/in -- simply ignores them while a human reading the file gets the full picture.
    #
    # The diag's own "=== PokeAccess diag <time> ===" header is dropped: every row is already timestamped,
    # and keeping it would make each dump differ from the last by the clock alone, defeating the check
    # below. A dump identical to the previous one for the same reason writes ONE marker line instead of
    # repeating itself -- the scene flips between nil, :message and :in_menu constantly, and in a real
    # session those identical six-line dumps were half the file, burying what mattered.
    def self.snapshot(sections, why)
      return unless @on
      text = (PokeAccess::Keys.diag_build(sections) rescue nil)
      return if text.nil?
      lines = text.split("\n").reject { |line| line =~ HEADER }
      if @last_snap[why] == lines
        note("diag", why, "(igual que el anterior)")
        return
      end
      @last_snap[why] = lines
      lines.each { |line| note("diag", why, line) }
    rescue StandardError
      nil
    end

    # Queues a snapshot for the NEXT frame instead of taking it now. The recorder's own frame hook runs
    # BEFORE the map readers' (a real recording proved it: the map-change dump showed the new map's size
    # alongside the previous map's target list, with coordinates that could not exist on it). Waiting one
    # frame lets every other reader react first, so the dump describes the state the player is actually in.
    def self.defer(sections, why)
      @pending.push([sections, why])
    end

    # Takes the snapshots queued by defer. Called at the top of the next sample, one frame after the change.
    def self.flush_pending
      return if @pending.empty?
      due = @pending
      @pending = []
      due.each { |s| snapshot(s[0], s[1]) }
    end

    # The per-frame sample: map, position, scene and the locator's selected target, each only on change.
    # A new map or a new scene also drags in its diagnostic snapshot -- those are exactly the moments a
    # "here it went wrong" report needs the surroundings for (a pathfinder that cannot route, a menu that
    # reads nothing), and they are rare enough to afford it.
    def self.sample
      return unless @on
      flush_pending
      gi = game_input
      note("in", gi) if gi
      if $game_map && $game_player
        moved_map = on_change("map", :map, $game_map.map_id,
                              (PokeAccess::Locator.map_name($game_map.map_id) rescue ""))
        defer(SNAP_MAP, "map") if moved_map
        on_change("pos", :pos, $game_player.x, $game_player.y)
      end
      # Scene class AND busy_reason together: many menus (bag, summary, the custom ones) run as an
      # overlay of the map scene, so the class alone never changes and their moment would go
      # uncaptured -- busy_reason is what tells a menu, a battle and a message apart.
      state = [($scene ? $scene.class.to_s : "nil"), (PokeAccess::Spatial.busy_reason.inspect rescue "?")]
      defer(SNAP_SCENE, "scene") if on_change("scene", :scene, state[0], state[1])
      l = PokeAccess::Locator
      ti = l.instance_variable_get(:@ti)
      tg = l.instance_variable_get(:@target)
      on_change("sel", :sel, ti, ((tg && tg.name) rescue "")) unless ti.nil?
    rescue StandardError
      nil
    end

    # What the player pressed this frame, or nil. The auditor needs it to tell a broken dedup ("it said the
    # same line twice on its own") from the player asking again -- moving inside a menu changes no position
    # and no scene, so without this every legitimate re-read looked like a bug. Directions use repeat?, not
    # trigger?: holding a direction to scroll a list moves the cursor repeatedly, and each of those moves is
    # a real player action. Mod keys do not come through here; Keys.key reports them as they fire.
    def self.game_input
      return nil unless defined?(Input)
      return "confirm" if (Input.trigger?(Input::C) rescue false)
      return "cancel" if (Input.trigger?(Input::B) rescue false)
      dir = (Input.repeat?(Input::UP) || Input.repeat?(Input::DOWN) ||
             Input.repeat?(Input::LEFT) || Input.repeat?(Input::RIGHT) rescue false)
      dir ? "dir" : nil
    rescue StandardError
      nil
    end

    # Records a mod key the moment it fires. Called from Keys.key, the single point every configured key
    # goes through, so no caller has to remember to report itself.
    def self.note_key(name)
      note("in", "tecla:#{name}")
    end
  end
end

# Sampled on the same per-frame driver the map readers use. frame_hook, not after_hook: the recorder must
# never take part in the reentrancy guard that decides which reader speaks.
PokeAccess::Hooks.frame_hook("Game_Player", :update) do |_p, _a|
  (PokeAccess::Recorder.sample rescue nil)
end
