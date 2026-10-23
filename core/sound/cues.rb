module PokeAccess
  # The mod's sounds (Sound::Catalog): one way to play each, where it plays and what stands in without the positional
  # engine (Pa3d) coming from the catalog; the caller only says what happened.
  module Sound
    # Writes the first failure of each kind to the diagnostic marker.
    def self.log(key, e)
      @logged ||= {}
      return if @logged[key]
      @logged[key] = true
      PokeAccess.write_marker("sound #{key}: #{e.is_a?(String) ? e : PokeAccess.format_error(e)}\n")
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # How many tiles to the side the guide's sounds play (at least one).
    def self.guide_distance
      [(PokeAccess::Config.guide_distance rescue 3).to_i, 1].max
    end

    # Plays a one-shot sound toward a direction (opts :dir, :vol, its family's volume if none) through the engine where
    # its place allows, sound navigation is on and it starts, else the catalog's flat stand-in: :engine or :flat for
    # what played, else false.
    def self.cue(id, opts = {})
      e = Catalog.entry(id)
      d = opts[:dir]
      vol = opts[:vol] || Mixer.volume(id)
      return false if e.nil? || vol.nil? || vol <= 0
      at = Scheduler.nav_off? ? nil : engine_tile(e, d)
      if at && Pa3d.channel(id)
        Pa3d.tone(id, (100 * Mixer.flat_factor(id)).round) if e.place == :side
        return :engine if Pa3d.start(id, at[0], at[1], vol)
      end
      flat(e, d, vol) ? :flat : false
    end

    # The tile a sound plays on through the engine toward d, or nil where its place leaves it flat: a side sound ahead
    # or behind, as stereo headphones cannot place front and back.
    def self.engine_tile(e, d)
      return nil unless $game_player
      px = $game_player.x; py = $game_player.y
      dx, dy = PokeAccess::DIR_DELTA[d] || [0, 0]
      case e.place
      when :side then (d == 4 || d == 6) ? [px + dx * guide_distance, py + dy * guide_distance] : nil
      when :front then [px + dx, py + dy]
      when :player then [px, py]
      end
    end

    # Plays a sound's flat stand-in toward d at vol, its pitch through its family's tone: the direction's file, else
    # :any's, else none; whether one played. Steps alternate between the full pitch and 90 % of it.
    def self.flat(e, d, vol)
      f = e.flat && (e.flat[d] || e.flat[:any])
      return false unless f
      base = f[1]
      if e.place == :player
        base = @flip ? 90 : 100
        @flip = !@flip
      end
      Flat.play(f[0], vol, (base * Mixer.flat_factor(e.id)).round)
      true
    end

    # Keeps a looping sound toward d (opts :dir, :vol), or stops it with no :dir; whether the engine plays it (none
    # stands in for a loop, nor plays with sound navigation off). The guide's held tone sounds guide_distance tiles to
    # the side, ahead and behind on the player, pitched as its chime.
    def self.hold(id, opts = {})
      d = opts[:dir]
      return release(id) if d.nil?
      e = Catalog.entry(id)
      vol = opts[:vol] || Mixer.volume(id)
      return false unless e && vol && $game_player && Pa3d.channel(id) && !Scheduler.nav_off?
      side = (d == 4 || d == 6) ? guide_distance : 0
      dx, dy = PokeAccess::DIR_DELTA[d] || [0, 0]
      base = (Catalog::GUIDE_FLAT[d] || [nil, 100])[1]
      Pa3d.tone(id, (base * Mixer.flat_factor(:guide)).round)
      Pa3d.hold(id, $game_player.x + dx * side, $game_player.y + dy * side, vol)
    end

    # Stops a looping sound; whether the engine has it.
    def self.release(id)
      Pa3d.stop(id)
    end

    # Plays a sound that is always flat (the radar, the minigame's tick) at a volume (its family's if nil) and a pitch
    # (the catalog's through its tone if nil).
    def self.earcon(id, vol = nil, pitch = nil)
      e = Catalog.entry(id)
      f = e && e.flat && e.flat[:any]
      return unless f
      Flat.play(f[0], vol || Mixer.volume(id), pitch || [(f[1] * Mixer.flat_factor(id)).round, 150].min)
    end

    # The pitch range a gauge sweeps: from GAUGE_LOW up by GAUGE_SPAN to 150, the most the flat channel plays. A base
    # and a span, not a low and a high: the MTS guard cannot prove a constant minus a constant is scalar.
    GAUGE_LOW = 80
    GAUGE_SPAN = 70

    # The minigame's tick, its pitch carrying a magnitude, 0.0 low to 1.0 high, for timing minigames; a fraction
    # outside 0..1 is clamped, not refused (live state can overshoot by a frame).
    def self.gauge(fraction)
      f = fraction.to_f
      f = 0.0 if f < 0.0
      f = 1.0 if f > 1.0
      earcon(:minigame, nil, GAUGE_LOW + (f * GAUGE_SPAN).to_i)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Plays a puzzle grid's cell tone: the file by its column, the pitch by its row through the grid's tone.
    def self.cell(col, row)
      v = Mixer.volume(:grid)
      return unless v && v > 0
      pitch = ((Catalog::GRID_ROWS[row] || 100) * Mixer.flat_factor(:grid)).round
      Flat.play(Catalog::GRID_COLUMNS[col] || "pa_guide_c", v, pitch)
    end

    # Plays a sound on the player at a volume and a pitch, the config menu's audition of a volume or tone row, with the
    # listener on the player (a move without control leaves it behind) and no muffle of a ping behind a wall; false
    # when the engine is down or the sound has no channel.
    def self.preview(id, vol, pitch)
      return false unless $game_player && Pa3d.channel(id)
      follow_player
      Pa3d.master((PokeAccess::Config.audio3d_volume rescue 80).to_i)
      Pa3d.tone(id, pitch)
      Pa3d.occlude(id, 0)
      x = $game_player.x; y = $game_player.y
      loop?(id) ? Pa3d.hold(id, x, y, vol) : Pa3d.start(id, x, y, vol)
    end

    # Stops a sound a preview started (water and wind would play on under the menu).
    def self.preview_stop(id)
      Pa3d.stop(id)
    end

    # True for a sound that loops rather than plays once.
    def self.loop?(id)
      e = Catalog.entry(id)
      e ? e.role == :loop : false
    end

    # Whether the mod's bump would be heard: sound navigation on, the wall volume above zero and, when the engine would
    # play it, its master volume above zero.
    def self.bump_audible?(interact = false)
      return false if Scheduler.nav_off?
      return false if (Mixer.volume(:wall) || 0) <= 0
      return true unless Pa3d.channel(interact ? :interact : :wall)
      (PokeAccess::Config.audio3d_volume rescue 80).to_i > 0
    end

    # Puts the listener on the player's tile at once, so what the map frame places from a new tile (the step, the
    # guide's chime) is heard from where the player stands; true if set.
    def self.follow_player
      $game_player ? Pa3d.listener($game_player.x, $game_player.y) : false
    end
  end
end
