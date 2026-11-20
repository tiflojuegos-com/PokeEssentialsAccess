module PokeAccess
  module Sound
    # The positional engine (Native), booted once: a channel per catalog sound with a file, loaded from the copy that
    # matches the device's rate. Every order to a channel goes through here, and one repeating the state the engine
    # already has is left out. Positions are tiles, scaled to the engine's units here.
    module Pa3d
      # Engine units per map tile.
      TILE_UNITS = 100
      # The 48000 Hz copies of the sounds, used when the device runs at that rate.
      SND48 = "#{PokeAccess::Paths::SOUNDS}/48000"
      # Each output of audio3d_output and the dll's number for it.
      OUTPUTS = { :binaural => 0, :mono => 1, :stereo => 2, :quad => 3, :surround51 => 4, :surround71 => 5 }
      # The outputs with no speakers behind, where the dll pitches a source by how far ahead or behind it lies: a source
      # straight ahead by 1 + ENGINE_TILT, one straight behind by 1 - ENGINE_TILT (its PITCH_TILT).
      TILTED = [OUTPUTS[:mono], OUTPUTS[:stereo]]
      ENGINE_TILT = 0.2

      @ready = false
      @boot_tried = false
      @ch = {}
      @rate = nil
      @latency = nil

      # Forgets what was sent: the next order of each kind goes out whatever it is.
      def self.forget
        @sent = {}
        @pitch = {}
        @base = {}
        @ratio = {}
        @occl = {}
        @listener = nil
        @master = nil
        @air = nil
        @output = nil
        @playing = nil
        @reach = nil
      end
      forget

      # Boots the engine and loads its channels, trying once, then puts the listener on the player; whether it is
      # ready. A boot that fails is logged and told to the player (unavailable), so once a session.
      def self.boot
        return @ready if @ready
        return false if @boot_tried
        @boot_tried = true
        unless Native.available?
          PokeAccess::Sound.log(:boot, "native PA3D dll unavailable (arch mismatch or missing native/)")
          return unavailable
        end
        unless Native.call(:init) == 1
          PokeAccess::Sound.log(:boot, "INIT failed (Steam Audio returned != 1)")
          return unavailable
        end
        @rate = (Native.call(:rate) rescue nil)
        @rate = nil if @rate && @rate <= 0
        @latency = (Native.call(:latency) rescue nil)
        Catalog.channels.each { |id, file, loops| @ch[id] = (Native.call(:channel, "#{wav(file)}\0", loops) rescue -1) }
        @ready = true
        listener($game_player.x, $game_player.y) if $game_player
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        PokeAccess::Sound.log(:boot, e)
        @ready ? false : unavailable
      end

      # Tells the player, queued, that positional sound is off: the sonar, the water and the wind fall silent, the
      # steps, walls and guide play in stereo; false, as a failed boot answers.
      def self.unavailable
        PokeAccess.speak(PokeAccess::I18n.t(:audio3d_unavailable), false)
        false
      end

      # Whether the engine booted, and whether booting was tried.
      def self.ready?; @ready; end
      def self.boot_tried?; @boot_tried; end

      # Whether positional sound can play here: the dll is there and, once booting was tried, it booted.
      def self.positional?
        Native.available? && (!@boot_tried || @ready) ? true : false
      end

      # The device's sample rate (Hz) and output latency (ms), set at boot; nil until then.
      def self.device_rate; @rate; end
      def self.device_latency; @latency; end

      # Each sound's channel as booting loaded it (-1 for one that failed).
      def self.channels; @ch; end

      # The pitches last sent, by channel.
      def self.pitches; @pitch; end

      # The path of a sound file for the device: its 48000 Hz copy when the device runs at 48000 and there is one,
      # else the original (which the engine resamples).
      def self.wav(name)
        if @rate == 48000
          p = "#{SND48}/#{name}"
          return p if (File.exist?(p) rescue false)
        end
        "#{PokeAccess::Paths::SOUNDS}/#{name}"
      end

      # A sound's loaded channel once the engine is ready, else nil.
      def self.channel(id)
        n = @ready ? @ch[id] : nil
        n && n >= 0 ? n : nil
      end

      # Puts the listener on a tile, the loops that play aimed again from there; true once the engine is ready.
      def self.listener(x, y)
        return false unless @ready
        pos = [x, y]
        return true if pos == @listener
        Native.call(:listener, x * TILE_UNITS, y * TILE_UNITS)
        @listener = pos
        @sent.each { |n, order| aim(n, order[0], order[1]) if order.is_a?(Array) }
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Starts a one-shot sound on a tile at a volume, from the top if it was playing; whether it has a channel.
      def self.start(id, x, y, vol)
        n = channel(id)
        return false unless n
        aim(n, x, y)
        Native.call(:set, n, x * TILE_UNITS, y * TILE_UNITS, vol.to_i, 1)
        @sent[n] = nil
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Plays a loop on a tile at a volume, or moves it there if it plays; whether it has a channel.
      def self.hold(id, x, y, vol)
        n = channel(id)
        return false unless n
        order = [x, y, vol.to_i]
        aim(n, x, y)
        Native.call(:set, n, x * TILE_UNITS, y * TILE_UNITS, vol.to_i, 1) unless @sent[n] == order
        @sent[n] = order
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Stops a sound's channel; whether it has one.
      def self.stop(id)
        n = channel(id)
        return false unless n
        Native.call(:set, n, 0, 0, 0, 0) unless @sent[n] == :stopped
        @sent[n] = :stopped
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Stops every channel, or those of ids.
      def self.silence(ids = nil)
        (ids || @ch.keys).each { |id| stop(id) }
      end

      # Sets a sound's playback rate, in percent of the recording, before its direction's factor (aim); whether the
      # engine took it.
      def self.tone(id, pct)
        n = channel(id)
        return false unless n && Native.has?(:pitch)
        @base[n] = pct
        send_pitch(n)
      end

      # Sends a channel its rate times its direction's factor, unless the engine has that one; whether it took it.
      def self.send_pitch(n)
        pct = ((@base[n] || 100) * (@ratio[n] || 1.0)).round
        Native.call(:pitch, n, pct) unless @pitch[n] == pct
        @pitch[n] = pct
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Gives a channel the factor of a source on (x, y) (direction_ratio), sending its rate again when that changed.
      def self.aim(n, x, y)
        r = direction_ratio(x, y)
        return if r == (@ratio[n] || 1.0)
        @ratio[n] = r
        send_pitch(n) if Native.has?(:pitch)
      end

      # The factor a source on (x, y) plays at over the dll's own tilt, so it sounds at the pitch the player set for
      # where it lies (audio3d_pitch_north, south, west and east, each side counting by how far toward it the source
      # lies): 1.0 outside the TILTED outputs and for a source on the listener, and at the defaults, the dll's own tilt.
      def self.direction_ratio(x, y)
        return 1.0 unless @listener && TILTED.include?(@playing)
        dx = (x - @listener[0]).to_f
        dz = (y - @listener[1]).to_f
        dist = Math.sqrt(dx * dx + dz * dz)
        return 1.0 if dist < 1e-4
        ux = dx / dist
        uz = dz / dist
        c = PokeAccess::Config
        f = 1.0 + side(c.audio3d_pitch_north, -uz) + side(c.audio3d_pitch_south, uz) +
            side(c.audio3d_pitch_west, -ux) + side(c.audio3d_pitch_east, ux)
        (f / (1.0 - ENGINE_TILT * uz) * 10000).round / 10000.0
      rescue StandardError => e
        PokeAccess.swallowed(e)
        1.0
      end

      # One side's share of the factor: its pitch's step away from 100 percent, by how far toward that side the source
      # lies (toward, 0 to 1; none for a source on the other side).
      def self.side(pct, toward)
        toward > 0 ? (pct.to_f / 100.0 - 1.0) * toward : 0.0
      end

      # Muffles a sound's channel by 0 (clear) to 100.
      def self.occlude(id, amount)
        n = channel(id)
        return false unless n && Native.has?(:occl)
        Native.call(:occl, n, amount) unless @occl[n] == amount
        @occl[n] = amount
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Sets the engine's master volume, 0-100 (it keeps it).
      def self.master(v)
        return unless @ready
        Native.call(:master, v) unless v == @master
        @master = v
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Sets the distance in tiles at which a source falls silent, where the dll takes it (it keeps it).
      def self.reach(tiles)
        return unless @ready && Native.has?(:range)
        Native.call(:range, tiles) unless tiles == @reach
        @reach = tiles
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Turns the air's absorption of distant sounds on or off.
      def self.air(on)
        return unless @ready && Native.has?(:air)
        a = on ? 1 : 0
        Native.call(:air, a) unless a == @air
        @air = a
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Sets how sources reach the speakers, where the dll takes it. The player is told, queued, when another output
      # plays instead, and when none could open; changing the setting tries again.
      def self.output(mode)
        return unless @ready && Native.has?(:output) && mode != @output
        @output = mode
        number = OUTPUTS[mode]
        return unless number
        @playing = Native.call(:output, number)
        return if @playing == number
        used = OUTPUTS.keys.find { |o| OUTPUTS[o] == @playing }
        return output_failed(mode) unless used
        s = PokeAccess::Config.setting(:audio3d_output)
        PokeAccess.speak(PokeAccess::I18n.t(:audio3d_output_short, :output => PokeAccess::Config.value_name(s, mode),
                                            :used => PokeAccess::Config.value_name(s, used),
                                            :channels => device_channels), false)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Logs and tells the player that positional sound stays silent, no output having opened.
      def self.output_failed(mode)
        PokeAccess::Sound.log(:output, "no output opens, asked for #{mode}")
        PokeAccess.speak(PokeAccess::I18n.t(:audio3d_output_failed), false)
      end

      # How many channels the device really has; nil before booting.
      def self.device_channels
        @ready ? Native.call(:device_channels) : nil
      end

      # The dll's number for the output playing, or -1 when none opened; nil until one was set.
      def self.output_playing; @playing; end
    end
  end
end
