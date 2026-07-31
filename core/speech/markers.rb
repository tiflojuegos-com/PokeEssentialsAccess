module PokeAccess
  # Diagnostics constants.
  DLL_DIR   = PokeAccess::Paths::LIB
  MARK_FILE = "#{PokeAccess::Paths::DATA}/hook_loaded.txt"

  # Appends a diagnostic line to the load-marker file.
  def self.write_marker(extra = "")
    File.open(MARK_FILE, "a") { |f| f.write("#{Time.now}: #{extra}") }
  rescue StandardError
  end

  # Formats an error for a diagnostic line: an exception as "Class: message @ frame <- frame <- frame"
  # (its top three backtrace frames), or any other value as its string. Shared by log_once,
  # Audio3D.log3d, and Hooks.run_body so a swallowed failure reads the same everywhere.
  def self.format_error(e)
    return e.to_s unless e.respond_to?(:backtrace)
    "#{e.class}: #{e.message} @ #{((e.backtrace || [])[0, 3]).join(' <- ')}"
  end

  # Writes the FIRST failure for a given key to the marker, then stays silent for that key, so a per-frame
  # path that throws every frame leaves one diagnostic line instead of thousands. Accepts an exception or a
  # plain string. The single home for "log a swallowed error once" (Hooks.run_body and Audio3D.log3d follow
  # the same pattern over their own per-scope stores). Self-guarded so it can never itself raise out of a
  # rescue clause.
  def self.log_once(key, e)
    @logged_once ||= {}
    return if @logged_once[key]
    @logged_once[key] = true
    write_marker("#{key}: #{format_error(e)}\n")
  rescue StandardError
    nil
  end

  # Seconds since the mod loaded, the source for all cue pacing. Plain wall time, because a cue cadence is
  # something a human hears: "a ping every 0.4 s" has to mean 0.4 real seconds in every game.
  #
  # It used to prefer System.uptime and fall back to Graphics.frame_count / 40, and both branches proved
  # unsafe. Infinite Fusion ships an mkxp-z whose System.uptime does NOT return seconds, so every interval
  # was met on the very next frame and the whole soundscape fired at frame rate (its performance exe, which
  # has no System.uptime, sounded correct -- that split is what pinned the bug down). The frame_count branch
  # is only right while the game truly holds its nominal rate, and it jumps whenever loading a save rewrites
  # frame_count. Time.now has neither failure mode and matches, to the millisecond, what the games that
  # already sounded right were doing. FPS survives as the frames-to-seconds constant the tunables are
  # expressed in (see freq_to_seconds), not as a clock.
  def self.clock
    if @epoch.nil?
      @epoch = Time.now
      @uptime0 = (System.uptime rescue nil)
    end
    (Time.now - @epoch).to_f
  end

  # How many System.uptime units make one real second: 1.0 where it counts seconds, 1_000_000.0 on the
  # Infinite Fusion build (its own scripts give it away -- 001_MKXP_Compatibility.rb defines
  # Graphics.delta_s as Graphics.delta / 1_000_000). nil while there is no uptime to read, or before
  # enough time has passed to measure it. Anything comparing two of the ENGINE's own uptime stamps has to
  # divide by this; the mod's own pacing never touches uptime at all (see clock).
  def self.uptime_scale
    return @uptime_scale if @uptime_scale
    now = clock
    u = (System.uptime rescue nil)
    return nil if u.nil? || @uptime0.nil? || now < 1.0
    @uptime_scale = (u - @uptime0) / now
  end

  # Seconds between cues for a 0-100 frequency setting (higher = more frequent), paced in real game time:
  # ~0.15s at 100, ~1.5s at 0. Shared by the guide chime and the spatial pings so their cadence is identical.
  def self.freq_to_seconds(f)
    base = 6 + ((100 - f.to_i) * 54) / 100
    base = 4 if base < 4
    base / FPS
  end
end
