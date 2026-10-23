module PokeAccess
  module Sound
    # The sound glossary the config menu browses: the catalog's sounds that have a row there, each with its name, the
    # help saying where it fires and its sample, which plays flat through the SE channel.
    module Glossary
      # The sounds listed, in order.
      def self.entries; Catalog.entries.select { |e| e.glossary }; end

      # The listed sound with an id, or nil.
      def self.entry(id)
        e = Catalog.entry(id)
        e && e.glossary ? e : nil
      end

      # The sound a volume, tone or switch row plays as its value moves: the first listed of its family (the people's
      # for the master volume); nil for any other row.
      def self.preview_of(key)
        return :npc if key == :audio3d_volume
        f = Catalog.families.find { |x| [x.vol, x.tone, x.on].any? { |r| r && r[0] == key } }
        e = f && entries.find { |x| x.family == f.id }
        e ? e.id : nil
      end

      # Plays a sound's sample at a 0-100 volume, flat and pitched by its family's tone, after stopping the last one
      # (the loops would pile up); true when a sound was asked for.
      def self.play(e, vol = 100)
        return false unless e
        Flat.stop
        Flat.play(e.glossary[2], vol, flat_pitch(e))
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # A sound's pitch through its family's tone as the flat channel can play it (50 to 150).
      def self.flat_pitch(e)
        [(e.glossary[3] * factor(e, true)).round, 150].min
      end

      # A sound's pitch through its family's tone as the positional engine plays it (no ceiling).
      def self.engine_pitch(e)
        (e.glossary[3] * factor(e, false)).round
      end

      # A sound's tone factor: 1.0 without a tone; the guide's for the sounds on its tone; Mixer.flat_factor for a side
      # chime, or flat for a clamped sound; else the family's tone as the engine plays it or, flat, Mixer.tone_factor
      # for the sound's own pitch (kept inside 50-150).
      def self.factor(e, flat)
        key = Catalog.key(e.id, :tone)
        return 1.0 unless key
        return Mixer.flat_factor(:guide) if key == :guide_tone
        return Mixer.flat_factor(e.id) if e.place == :side || (flat && e.clamp)
        p = e.glossary[3]
        flat ? Mixer.tone_factor(key, p, p) : PokeAccess.tone_to_pitch(PokeAccess::Config.send(key)) / 100.0
      end
    end
  end
end
