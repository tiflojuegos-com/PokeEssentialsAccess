module PokeAccess
  # Dual-engine terrain queries: gen-6 returns an Integer tag (with PBTerrain.isX?), modern a
  # GameData::TerrainTag object (with boolean flags). This normalises both, falling back to the tag
  # number (identical across versions) when neither shape answers.
  module Terrain
    # Standard Essentials terrain-tag id_number => stable kind symbol (same numbering gen-6/modern).
    KIND = { 1 => :ledge, 2 => :grass, 3 => :sand, 4 => :rock, 5 => :deep_water, 6 => :still_water,
             7 => :water, 8 => :waterfall, 9 => :waterfall_crest, 10 => :tall_grass,
             11 => :underwater_grass, 12 => :ice, 13 => :neutral, 14 => :soot_grass,
             15 => :bridge, 16 => :puddle }
    # kind => localization key for surface awareness (cues and navigation targets).
    LABEL = { :tall_grass => :surf_tallgrass, :grass => :surf_grass, :sand => :surf_sand,
              :rock => :surf_rock, :water => :surf_water, :still_water => :surf_water,
              :deep_water => :surf_deepwater, :waterfall => :surf_waterfall,
              :waterfall_crest => :surf_waterfall, :ice => :surf_ice, :bridge => :surf_bridge,
              :puddle => :surf_puddle, :soot_grass => :surf_sootgrass }
    GRASS = [:grass, :tall_grass, :soot_grass]
    SURF_NUMBERS = [5, 6, 7, 8, 9]

    # The engine's raw terrain at (x,y) (Integer or GameData::TerrainTag), or nil. count_bridge reports
    # bridge tiles even when not standing on the bridge; uses the cross-map lookup for seamless edges.
    def self.raw(x, y, count_bridge = false)
      return nil unless $game_map
      if count_bridge
        r = ($game_map.terrain_tag(x, y, true) rescue :err)
        return r unless r == :err
      end
      ($game_map.terrain_tag(x, y) rescue nil)
    end

    # The id_number of a raw terrain value (object in modern, Integer in gen-6).
    def self.number(t)
      return nil if t.nil?
      return (t.id_number rescue nil) if t.respond_to?(:id_number)
      t.is_a?(Integer) ? t : nil
    end

    # The stable kind symbol at (x,y) (e.g. :water, :bridge), or nil for none/custom tags.
    def self.kind(x, y, count_bridge = false)
      KIND[number(raw(x, y, count_bridge))]
    end

    # The surface localization key at (x,y), or nil; counts bridges and falls back to water for any
    # surfable custom tag with no explicit label.
    def self.label(x, y)
      t = raw(x, y, true)
      LABEL[KIND[number(t)]] || (surfable?(t) ? :surf_water : nil)
    end

    # The three-step dual-engine probe every tag test shares: the modern object's boolean flag, then the
    # gen-6 PBTerrain helper, then the block over the NORMALISED tag number. One ladder instead of four
    # near-identical copies, and the number fallback is uniform (the old surfable? compared the raw value).
    def self.probe(t, flag, pb_name)
      return false if t.nil?
      return (t.send(flag) ? true : false) if t.respond_to?(flag)
      return PBTerrain.send(pb_name, t) if defined?(PBTerrain) && PBTerrain.respond_to?(pb_name)
      yield(number(t))
    rescue StandardError
      false
    end

    # True if a raw terrain value is surfable water.
    def self.surfable?(t); probe(t, :can_surf, :isSurfable?) { |n| SURF_NUMBERS.include?(n) }; end

    # True if a raw terrain value is a one-way ledge (tag 1).
    def self.ledge?(t); probe(t, :ledge, :isLedge?) { |n| n == 1 }; end

    # True if a raw terrain value is ice (forced slide).
    def self.ice?(t); probe(t, :ice, :isIce?) { |n| n == 12 }; end

    # True if a raw terrain value is a bridge tile.
    def self.bridge?(t); probe(t, :bridge, :isBridge?) { |n| n == 15 }; end

    # True if a raw terrain value is walkable grass (plain, tall or soot).
    def self.grass?(t)
      GRASS.include?(KIND[number(t)])
    end

    # Surfable water directly at (x,y).
    def self.surfable_at?(x, y); surfable?(raw(x, y)); end
    # A one-way ledge at (x,y).
    def self.ledge_at?(x, y); ledge?(raw(x, y)); end
    # An ice tile (forced slide) at (x,y).
    def self.ice_at?(x, y); ice?(raw(x, y)); end
  end
end
