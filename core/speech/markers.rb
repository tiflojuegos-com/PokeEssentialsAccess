module PokeAccess
  # Diagnostics constants.
  DLL_DIR   = PokeAccess::Paths::LIB
  MARK_FILE = "#{PokeAccess::Paths::DATA}/hook_loaded.txt"

  # Appends a diagnostic line to the load-marker file.
  def self.write_marker(extra = "")
    File.open(MARK_FILE, "a") { |f| f.write("#{Time.now}: #{extra}") }
  rescue StandardError
  end

  # Formats an error for a diagnostic line: an exception as "Class: message @ frame <- frame <- frame" (its top three
  # backtrace frames), any other value as its string.
  def self.format_error(e)
    return e.to_s unless e.respond_to?(:backtrace)
    "#{e.class}: #{e.message} @ #{((e.backtrace || [])[0, 3]).join(' <- ')}"
  end

  # Writes the first failure (exception or string) for a key to the marker, and nothing more for it; never raises.
  def self.log_once(key, e)
    @logged_once ||= {}
    return if @logged_once[key]
    @logged_once[key] = true
    write_marker("#{key}: #{format_error(e)}\n")
  rescue StandardError
    nil
  end

  # Returns value, logging once when nil: only where the object must exist, never where nil is a normal state.
  def self.expect!(key, value)
    log_once("expect.#{key}", "expected but absent") if value.nil?
    value
  rescue StandardError
    value
  end

  # Seconds since the mod loaded in wall time, for all cue pacing (engine clocks are not reliably in seconds).
  def self.clock
    if @epoch.nil?
      @epoch = Time.now
      @uptime0 = (System.uptime rescue nil)
    end
    (Time.now - @epoch).to_f
  end

  # System.uptime units per real second (1.0, or 1_000_000.0 on a microsecond build), measured against clock; nil
  # without uptime or before a second has passed. Divide any difference of the engine's uptime stamps by it.
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

  # Playback rate, in percent of the recording, for a 0-100 tone setting: 50 is the recording, 0 an octave down, 100
  # an octave up, in equal steps of pitch.
  def self.tone_to_pitch(tone)
    (100 * (2 ** ((tone.to_i - 50) / 50.0))).round
  end
end
