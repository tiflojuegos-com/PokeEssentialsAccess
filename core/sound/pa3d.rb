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

      @ready = false
      @boot_tried = false
      @ch = {}
      @rate = nil
      @latency = nil

      # Forgets what was sent: the next order of each kind goes out whatever it is.
      def self.forget
        @sent = {}
        @pitch = {}
        @occl = {}
        @listener = nil
        @master = nil
        @air = nil
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

      # Puts the listener on a tile; true once the engine is ready.
      def self.listener(x, y)
        return false unless @ready
        pos = [x, y]
        Native.call(:listener, x * TILE_UNITS, y * TILE_UNITS) unless pos == @listener
        @listener = pos
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Starts a one-shot sound on a tile at a volume, from the top if it was playing; whether it has a channel.
      def self.start(id, x, y, vol)
        n = channel(id)
        return false unless n
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

      # Sets a sound's playback rate, in percent of the recording; whether the engine took it.
      def self.tone(id, pct)
        n = channel(id)
        return false unless n && Native.has?(:pitch)
        Native.call(:pitch, n, pct) unless @pitch[n] == pct
        @pitch[n] = pct
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
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
    end
  end
end
