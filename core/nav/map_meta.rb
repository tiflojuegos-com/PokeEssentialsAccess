module PokeAccess
  # A map's Essentials metadata, read the same way in both eras: gen-6 keeps it in pbGetMetadata rows by
  # numeric field, the GameData games in GameData::MapMetadata.
  module MapMeta
    # The gen-6 metadata fields, by their index in the pbGetMetadata row.
    OUTDOOR = 1
    BICYCLE_ALWAYS = 4
    HEALING_SPOT = 5
    DIVE_MAP = 8

    # One field of a map's metadata: the GameData accessor, else the gen-6 row. :none when this engine has
    # no map metadata at all, which is not the same as a map that has none.
    def self.field(mid, modern, gen6_const, gen6_index)
      if defined?(::GameData::MapMetadata)
        md = ::GameData::MapMetadata
        m = md.respond_to?(:try_get) ? md.try_get(mid) : (md.get(mid) rescue nil)
        return m ? (m.send(modern) rescue nil) : nil
      end
      return :none unless Object.private_method_defined?(:pbGetMetadata) || Kernel.respond_to?(:pbGetMetadata)
      idx = Object.const_defined?(gen6_const) ? Object.const_get(gen6_const) : gen6_index
      Kernel.send(:pbGetMetadata, mid, idx)
    rescue StandardError
      :none
    end

    # true outdoors, false indoors (a map with no metadata is indoors, as the engine reads it), nil when the
    # engine cannot say.
    def self.outdoor?(mid)
      v = field(mid, :outdoor_map, "MetadataOutdoor", OUTDOOR)
      v == :none ? nil : (v ? true : false)
    end

    # True on a map the player cannot get off the bike on (Cycling Road): the engine then refuses both
    # getting off and Surf there.
    def self.always_bicycle?(mid)
      v = field(mid, :always_bicycle, "MetadataBicycleAlways", BICYCLE_ALWAYS)
      v == :none ? false : (v ? true : false)
    end

    # True for a Pokemon Centre, the kind of map that declares where Teleport sets the player down (HealingSpot).
    def self.pokecenter?(mid)
      v = field(mid, :teleport_destination, "MetadataHealingSpot", HEALING_SPOT)
      v.is_a?(Array) && !v.empty?
    end

    # The map under the sea of mid, or nil.
    def self.dive_map(mid)
      v = field(mid, :dive_map_id, "MetadataDiveMap", DIVE_MAP)
      (v.is_a?(Integer) && v > 0) ? v : nil
    end

    # The map whose sea mid lies under, or nil: the metadata only points down, so a reverse index is built once.
    def self.surface_map(mid)
      @surface_of ||= surface_index
      @surface_of[mid]
    end

    # dive map => the map above it, for every map that declares one.
    def self.surface_index
      out = {}
      if defined?(::GameData::MapMetadata) && ::GameData::MapMetadata.respond_to?(:each)
        ::GameData::MapMetadata.each { |m| d = (m.dive_map_id rescue nil); out[d] ||= m.id if d.is_a?(Integer) && d > 0 }
      elsif Object.private_method_defined?(:pbLoadMetadata) || Kernel.respond_to?(:pbLoadMetadata)
        idx = Object.const_defined?("MetadataDiveMap") ? Object.const_get("MetadataDiveMap") : DIVE_MAP
        (Kernel.send(:pbLoadMetadata) || []).each_with_index do |row, i|
          d = row.is_a?(Array) ? row[idx] : nil
          out[d] ||= i if i > 0 && d.is_a?(Integer) && d > 0
        end
      end
      out
    rescue StandardError
      {}
    end

    # The raw terrain at (x,y) of another map, through the engine's map factory (the map it builds is kept
    # while the player stays on this one).
    def self.terrain_on(mid, x, y)
      if @foreign.nil? || @foreign[0] != mid
        f = (defined?($map_factory) && $map_factory) || (defined?($MapFactory) && $MapFactory)
        m = f.respond_to?(:getMapNoAdd) ? f.getMapNoAdd(mid) : f.getMap(mid, false)
        @foreign = [mid, m]
      end
      @foreign[1].terrain_tag(x, y)
    rescue StandardError
      nil
    end

    # Forgets the other map built for terrain_on (the map changed).
    def self.forget_foreign; @foreign = nil; end
  end
end

PokeAccess::Caches.register(:map_meta) { PokeAccess::MapMeta.forget_foreign }
