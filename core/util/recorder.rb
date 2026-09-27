module PokeAccess
  # Session recorder: a transcript of what the mod saw and said, in order, fed by a speech observer and a
  # per-frame sample; test/support/replay.rb audits it.
  #
  # Line format (tab-separated, text always last; the auditor parses it):
  #   # pea-recording 1 <engine kind>  <engine version>  <fork>
  #   <seconds>  map    <map_id>  <name>
  #   <seconds>  pos    <x>  <y>
  #   <seconds>  scene  <class>  <busy reason>
  #   <seconds>  sel    <index>  <target name>
  #   <seconds>  say    <0|1 interrupt>  <text>
  #   <seconds>  in     <what>
  #   <seconds>  diag   <why>  <one line of a diagnostic section>
  module Recorder
    DIR = "#{PokeAccess::Paths::DATA}/recordings"
    FLUSH_EVERY = 120
    HEADER = /\A=== PokeAccess diag/

    # The diag sections dumped into the transcript at start, on a map change and on a scene change. diag_perf
    # and diag_polls stay out: the first resets its window, the second runs a benchmark.
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
      PokeAccess::Speech.observe(:recorder) { |msg| note("say", msg.interrupt ? 1 : 0, msg.text) }
      snapshot(SNAP_START, "start")
      flush
      File.basename(@path)
    rescue StandardError
      @on = false
      nil
    end

    # Stops the recording, removes the observer and writes what is pending; returns the session's event count
    # (not the buffer length, which flush empties).
    def self.stop
      return 0 unless @on
      @on = false
      PokeAccess::Speech.unobserve(:recorder)
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

    # Appends the buffered lines to the file and empties the buffer.
    def self.flush
      return if @path.nil? || @lines.empty?
      pending = @lines
      @lines = []
      File.open(@path, "a") { |f| f.write(pending.join("\n") + "\n") }
    rescue StandardError => e
      PokeAccess.log_once("recorder_flush", e)
      nil
    end

    # Notes a field only when it changed since the last call for that key; returns whether it wrote.
    def self.on_change(kind, key, *fields)
      return false if @seen[key] == fields
      @seen[key] = fields
      note(kind, *fields)
      true
    end

    # Dumps diag sections into the transcript as "diag" rows tagged with why, minus the timestamped header; a
    # dump identical to the last one for the same why writes a single marker row instead.
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

    # Queues a snapshot for the next frame, since the recorder's frame hook runs before the map readers update.
    def self.defer(sections, why)
      @pending.push([sections, why])
    end

    # Takes the snapshots queued by defer (at the top of the next sample).
    def self.flush_pending
      return if @pending.empty?
      due = @pending
      @pending = []
      due.each { |s| snapshot(s[0], s[1]) }
    end

    # The per-frame sample: the input pressed, and on change the map, position, scene (class and busy_reason,
    # which tells overlay menus apart) and locator selection; a new map or scene queues a snapshot.
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
      state = [($scene ? $scene.class.to_s : "nil"), (PokeAccess::Spatial.busy_reason.inspect rescue "?")]
      defer(SNAP_SCENE, "scene") if on_change("scene", :scene, state[0], state[1])
      l = PokeAccess::Locator
      ti = l.instance_variable_get(:@ti)
      tg = l.instance_variable_get(:@target)
      on_change("sel", :sel, ti, ((tg && tg.name) rescue "")) unless ti.nil?
    rescue StandardError
      nil
    end

    # What the player pressed this frame ("confirm", "cancel", "dir"), or nil, so the auditor can tell a re-read
    # from a repeat; directions use repeat?, since a held direction keeps moving the cursor.
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

    # Records a mod key as it fires (called from Keys.key).
    def self.note_key(name)
      note("in", "tecla:#{name}")
    end
  end
end

# Sampled on Keys.on_frame (Input.update), which also runs inside the menus' own blocking loops.
PokeAccess::Keys.on_frame { (PokeAccess::Recorder.sample rescue nil) }
