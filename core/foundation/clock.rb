module PokeAccess
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
