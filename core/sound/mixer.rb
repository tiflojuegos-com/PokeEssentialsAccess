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

      # The seconds between a sound's pings, from its family's frequency.
      def self.ping_seconds(id)
        PokeAccess.freq_to_seconds((PokeAccess::Config.send(Catalog.key(id, :freq)) rescue 70))
      end

      # A sound's playback rate through the positional engine, in percent: its family's tone (100 with none).
      def self.pitch3d(id)
        key = Catalog.key(id, :tone)
        key ? PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) : 100
      rescue StandardError => e
        PokeAccess.swallowed(e)
        100
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

      # A sound's flat factor: its family's tone, kept inside the sound's clamp (1.0 with no tone).
      def self.flat_factor(id)
        key = Catalog.key(id, :tone)
        return 1.0 unless key
        lo, hi = Catalog.entry(id).clamp || [100, 100]
        tone_factor(key, lo, hi)
      end
    end
  end
end
