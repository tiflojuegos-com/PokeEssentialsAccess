module PokeAccess
  module Sound
    # What each sound plays at, from its family's settings (Catalog.key): its volume, the seconds between its pings, its
    # rate through the positional engine and the factor its tone gives a flat cue.
    module Mixer
      # A sound's volume, 0-100: its family's setting, 0 with the family's sound switched off; nil for a sound with
      # none.
      def self.volume(id)
        v = level(id)
        v && !on?(id) ? 0 : v
      end

      # A sound's family volume setting, switched on or not (what the menu auditions); nil for a sound with none.
      def self.level(id)
        key = Catalog.key(id, :vol)
        key ? (PokeAccess::Config.send(key) rescue 80).to_i : nil
      end

      # Whether a sound's family is switched on ("Sounds on"); one without a switch always is.
      def self.on?(id)
        key = Catalog.key(id, :on)
        key.nil? || (PokeAccess::Config.send(key) rescue true) ? true : false
      end

      # Category percentages are neutral at100; family tone and the shared directional choices remain separate.
      def self.category_factor(id, side, kind)
        entry = Catalog.entry(id)
        return 100 unless entry
        key = ("audio_dir_" + entry.family.to_s + "_" + side.to_s + "_" + kind.to_s).to_sym
        PokeAccess::Config.respond_to?(key) ? PokeAccess::Config.send(key).to_i : 100
      end

      def self.category_pitches(id)
        [:north, :south, :west, :east].map { |side| category_factor(id, side, :pitch) }
      end

      def self.direction_factor(id, direction, kind)
        side = Catalog::DIRECTION_KEYS.keys.find { |key| Catalog::DIRECTION_KEYS[key] == direction }
        side ? category_factor(id, side, kind) / 100.0 : 1.0
      end

      # Blend only adjacent cardinal rates, matching the pitch interpolation around the listener.
      def self.repeat_factor(id, dx, dy)
        length = Math.sqrt(dx.to_f * dx + dy.to_f * dy)
        return 1.0 if length < 0.0001
        horizontal = category_factor(id, dx < 0 ? :west : :east, :rate).to_f
        vertical = category_factor(id, dy < 0 ? :north : :south, :rate).to_f
        (horizontal + (vertical - horizontal) * (dy.to_f / length).abs) / 100.0
      end

      # The seconds between a sound's pings, from its family's frequency.
      def self.ping_seconds(id, dx = 0, dy = 0)
        seconds = PokeAccess.freq_to_seconds((PokeAccess::Config.send(Catalog.key(id, :freq)) rescue 70))
        seconds / repeat_factor(id, dx, dy)
      end

      # A sound's playback rate through the positional engine, in percent: its family's tone (100 with none).
      # The 145 Hz south sample receives one octave of speaker calibration before the shared rear tilt.
      def self.pitch3d(id)
        key = Catalog.key(id, :tone)
        value = key ? PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) : 100
        value *= 2 if id == :wind_s && speaker_output?
        value
      rescue StandardError => e
        PokeAccess.swallowed(e)
        100
      end

      # Actual mono/stereo output, including a fallback from a requested surround layout.
      def self.speaker_output?
        playing = Pa3d.output_playing
        return [1, 2].include?(playing) unless playing.nil?
        [:stereo, :mono].include?(PokeAccess::Config.audio3d_output) && Native.has?(:output)
      end

      # The rate factor a tone setting gives a flat cue, kept so the pitches low and high it plays at stay inside the
      # 50-150 the flat channel takes (a pair keeps its ratio).
      def self.tone_factor(key, low = 100, high = 100)
        f = PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) / 100.0
        f = 150.0 / high if high * f > 150
        f = 50.0 / low if low * f < 50
        f
      rescue StandardError => e
        PokeAccess.swallowed(e)
        1.0
      end

      # Cardinal percentages use map directions; the family tone remains independent.
      def self.direction_pitches
        [:front, :back, :left, :right].map { |side| PokeAccess::Config.send("direction_pitch_#{side}").to_i }
      end

      def self.directional_base(entry, direction, base)
        return base unless [:stereo, :mono].include?(PokeAccess::Config.audio3d_output)
        base *= direction_factor(entry.id, direction, :pitch)
        return base if entry.place == :contact
        sides = { 8 => [:front, 120], 2 => [:back, 80], 4 => [:left, 100], 6 => [:right, 100] }
        row = sides[direction]
        return base unless row && entry.flat && entry.flat[direction]
        base * PokeAccess::Config.send("direction_pitch_#{row[0]}").to_f / row[1]
      end

      # A sound's flat factor: its family's tone, kept inside the sound's clamp (1.0 with no tone).
      def self.flat_factor(id)
        key = Catalog.key(id, :tone)
        return 1.0 unless key
        entry = Catalog.entry(id)
        lo, hi = entry.clamp || [100, 100]
        tone_factor(key, lo, hi)
      end
    end
  end
end
