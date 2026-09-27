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

    # GameData id symbol => kind, tried first on tag objects, as games may renumber the standard tags.
    IDS = { :Ledge => :ledge, :Grass => :grass, :Sand => :sand, :Rock => :rock,
            :DeepWater => :deep_water, :StillWater => :still_water, :Water => :water,
            :Waterfall => :waterfall, :WaterfallCrest => :waterfall_crest,
            :TallGrass => :tall_grass, :UnderwaterGrass => :underwater_grass, :Ice => :ice,
            :Neutral => :neutral, :SootGrass => :soot_grass, :Bridge => :bridge, :Puddle => :puddle }

    # The stable kind of a raw terrain value: the tag object's id when it maps, else its number, read through the
    # game's PBTerrain names. The Integer guard is for 1.8.7, where Object#id exists and warns.
    def self.kind_of(t)
      return nil if t.nil?
      if !t.is_a?(Integer) && t.respond_to?(:id)
        k = IDS[(t.id rescue nil)]
        return k if k
      end
      n = number(t)
      named = named_kinds
      named.has_key?(n) ? named[n] : KIND[n]
    end

    # number => kind by the game's PBTerrain constant names: a number given another name maps to nil (Insurgence's 4
    # is RockClimb), and a standard name wins over another on the same number; empty with no PBTerrain.
    def self.named_kinds
      return @named_kinds if @named_kinds
      pairs = defined?(PBTerrain) ? PBTerrain.constants.map { |c| [c, (PBTerrain.const_get(c) rescue nil)] } : []
      @named_kinds = kinds_of_names(pairs)
    rescue StandardError
      @named_kinds = {}
    end

    # number => kind for [constant name, value] pairs, in whatever order the engine lists them (see named_kinds).
    def self.kinds_of_names(pairs)
      out = {}
      pairs.each do |c, n|
        next unless n.is_a?(Integer)
        k = IDS[c.to_sym]
        out[n] = k if k || !out.has_key?(n)
      end
      out
    end

    # Drops the names read from PBTerrain, so the next lookup reads them again.
    def self.forget_named_kinds
      @named_kinds = nil
    end

    # The offset that keeps a memo key positive for the tiles just outside a map's edge.
    MEMO_EDGE = 1024
    MEMO_STRIDE = 65536

    # Asks the engine for each tile's terrain once over the block, as nothing changes the map meanwhile; nested spans
    # share the outer memo, else the one given, else the map's own with route_cache on.
    def self.memoizing(memo = nil)
      outer = @memo
      @memo ||= (memo || map_memo || {})
      yield
    ensure
      @memo = outer
    end

    # The terrain memo that outlives a search: one per map while route_cache is on (only an event changes a map's
    # tiles), dropped by Pathfinder.invalidate_cache and by switching the cache off.
    def self.map_memo
      unless (PokeAccess::Config.route_cache rescue false)
        forget_map_memo
        return nil
      end
      id = ($game_map.map_id rescue nil)
      if @map_memo.nil? || @map_memo_id != id
        @map_memo_id = id
        @map_memo = {}
      end
      @map_memo
    end

    # Drops the per-map memo, so the next lookup asks the engine again.
    def self.forget_map_memo
      @map_memo = nil
      @map_memo_id = nil
    end

    # The engine's raw terrain at (x,y) (Integer or GameData::TerrainTag), or nil; count_bridge reports a bridge tile
    # even off the bridge. Memoised per bridge state, as off it the engine reports a bridge as the water below.
    def self.raw(x, y, count_bridge = false)
      return nil unless $game_map
      memo = @memo || map_memo
      return engine_raw(x, y, count_bridge) unless memo
      on_bridge = bridge_height > 0 ? 1 : 0
      key = (((x + MEMO_EDGE) * MEMO_STRIDE + (y + MEMO_EDGE)) * 2 + (count_bridge ? 1 : 0)) * 2 + on_bridge
      return memo[key] if memo.has_key?(key)
      memo[key] = engine_raw(x, y, count_bridge)
    end

    def self.engine_raw(x, y, count_bridge)
      if count_bridge
        r = ($game_map.terrain_tag(x, y, true) rescue :err)
        return r unless r == :err
      end
      ($game_map.terrain_tag(x, y) rescue nil)
    end

    # The object the engine keeps the bridge height on: $PokemonGlobal from v16, $PokemonMap in the copies before
    # (Insurgence's); nil when neither keeps one.
    def self.bridge_holder
      g = $PokemonGlobal
      return g if g.respond_to?(:bridge)
      m = $PokemonMap
      m.respond_to?(:bridge) ? m : nil
    end

    # The bridge height the engine is at (0 off every bridge).
    def self.bridge_height
      g = $PokemonGlobal
      return g.bridge.to_i if g.respond_to?(:bridge)
      m = $PokemonMap
      m.respond_to?(:bridge) ? m.bridge.to_i : 0
    rescue StandardError
      0
    end

    # The id_number of a raw terrain value (object in modern, Integer in gen-6).
    def self.number(t)
      return nil if t.nil?
      return (t.id_number rescue nil) if t.respond_to?(:id_number)
      t.is_a?(Integer) ? t : nil
    end

    # The stable kind symbol at (x,y) (e.g. :water, :bridge), or nil for none/custom tags.
    def self.kind(x, y, count_bridge = false)
      kind_of(raw(x, y, count_bridge))
    end

    # The surface localization key at (x,y), or nil; counts bridges and falls back to water for any
    # surfable custom tag with no explicit label.
    def self.label(x, y)
      t = raw(x, y, true)
      LABEL[kind_of(t)] || (surfable?(t) ? :surf_water : nil)
    end

    # The probe every tag test shares: the modern tag's flag, then the gen-6 PBTerrain helper, then the global one of
    # copies older than v15 (pbIsSurfableTag?), then the block over the tag number.
    def self.probe(t, flag, pb_name, global_name = nil)
      return false if t.nil?
      return (t.send(flag) ? true : false) if t.respond_to?(flag)
      return PBTerrain.send(pb_name, t) if defined?(PBTerrain) && PBTerrain.respond_to?(pb_name)
      return (send(global_name, t) ? true : false) if global_name && respond_to?(global_name, true)
      yield(number(t))
    rescue StandardError
      false
    end

    # True if a raw terrain value is surfable water.
    def self.surfable?(t); probe(t, :can_surf, :isSurfable?, :pbIsSurfableTag?) { |n| SURF_NUMBERS.include?(n) }; end

    # True if a raw terrain value is a one-way ledge (tag 1).
    def self.ledge?(t); probe(t, :ledge, :isLedge?) { |n| n == 1 }; end

    # True if a raw terrain value is ice (forced slide).
    def self.ice?(t); probe(t, :ice, :isIce?) { |n| n == 12 }; end

    # True if a raw terrain value is a bridge tile.
    def self.bridge?(t); probe(t, :bridge, :isBridge?) { |n| n == 15 }; end

    # True if a raw terrain value is deep water, the one the engine dives into and surfaces through.
    def self.deep?(t); probe(t, :can_dive, :isDeepWater?) { |n| n == 5 }; end

    # True if a raw terrain value is walkable grass (plain, tall or soot).
    def self.grass?(t)
      GRASS.include?(kind_of(t))
    end

    # True if a raw terrain value carries a flag a plugin or a game adds to the modern tag (a current,
    # climbable rock, a rail, a slide); no gen-6 tag carries one.
    def self.flag?(t, flag)
      t.respond_to?(flag) && t.send(flag) ? true : false
    rescue StandardError
      false
    end

    # The terrain number at (x,y), or nil.
    def self.number_at(x, y); number(raw(x, y)); end
    # A flag of the terrain at (x,y) (see flag?).
    def self.flag_at?(x, y, flag); flag?(raw(x, y), flag); end

    # Surfable water directly at (x,y).
    def self.surfable_at?(x, y); surfable?(raw(x, y)); end
    # A one-way ledge at (x,y).
    def self.ledge_at?(x, y); ledge?(raw(x, y)); end
    # An ice tile (forced slide) at (x,y).
    def self.ice_at?(x, y); ice?(raw(x, y)); end
  end
end

PokeAccess::Caches.register(:terrain_names) { PokeAccess::Terrain.forget_named_kinds }
