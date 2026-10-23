module PokeAccess
  module World
    # The map's terrain as the routes and the cues meet it: the engine's tag asked once per kind of tile (its layers'
    # tile ids) until the map or its tiles change (Epoch), each tag classed once. A bridge tile is kept per height, as
    # the engine reads it as the water below while the player is off the bridge; off the map there is no terrain.
    module Terrain
      # Standard Essentials terrain-tag numbers => stable kind (the same numbering in every era).
      KIND = { 1 => :ledge, 2 => :grass, 3 => :sand, 4 => :rock, 5 => :deep_water, 6 => :still_water,
               7 => :water, 8 => :waterfall, 9 => :waterfall_crest, 10 => :tall_grass,
               11 => :underwater_grass, 12 => :ice, 13 => :neutral, 14 => :soot_grass,
               15 => :bridge, 16 => :puddle }
      # GameData id or PBTerrain name => kind, tried first, as games may renumber the standard tags; the only way to
      # lava, which has no standard number.
      IDS = { :Ledge => :ledge, :Grass => :grass, :Sand => :sand, :Rock => :rock,
              :DeepWater => :deep_water, :StillWater => :still_water, :Water => :water,
              :Waterfall => :waterfall, :WaterfallCrest => :waterfall_crest,
              :TallGrass => :tall_grass, :UnderwaterGrass => :underwater_grass, :Ice => :ice,
              :Neutral => :neutral, :SootGrass => :soot_grass, :Bridge => :bridge, :Puddle => :puddle,
              :Lava => :lava }
      # Kind => the surface's localization key.
      LABEL = { :tall_grass => :surf_tallgrass, :grass => :surf_grass, :sand => :surf_sand,
                :rock => :surf_rock, :water => :surf_water, :still_water => :surf_water,
                :deep_water => :surf_deepwater, :waterfall => :surf_waterfall,
                :waterfall_crest => :surf_waterfall, :ice => :surf_ice, :bridge => :surf_bridge,
                :puddle => :surf_puddle, :soot_grass => :surf_sootgrass, :underwater_grass => :surf_seaweed,
                :lava => :surf_lava }
      GRASS_KINDS = [:grass, :tall_grass, :soot_grass]
      FALLING_KINDS = [:waterfall, :waterfall_crest]
      SURF_NUMBERS = [5, 6, 7, 8, 9]

      # The tag tests a class answers, as bits of its cell.
      SURF = 1
      LEDGE = 2
      ICE = 4
      DEEP = 8
      GRASS = 16
      FALLING = 32

      # Tile ids below this share their kind of tile's tag; a higher one, past any tileset's, is asked on its own.
      ID_SPAN = 8192

      @label_rules = []
      @surf_rules = []

      # Registers a game's own surface labels: the block gets (x, y) and answers a label key for its tiles, nil for
      # the rest; the first rule that answers wins over the standard label.
      def self.label_rule(&blk); @label_rules.push(blk); end

      # Registers a game's own surf test for the map it is on: the block gets a tag number and answers true where the
      # game lets the player surf on it now. With a rule, every tag is classed again when the tiles change.
      def self.surf_rule(&blk); @surf_rules.push(blk); end

      # True when a game registered a surf rule.
      def self.ruled?; !@surf_rules.empty?; end

      # Drops the tiles read (on a map or tiles change), keeping the classes of the tags seen.
      def self.forget
        @rows = {}
        @alike = {}
        @bridges = {}
        @water = {}
        @w = nil
        @h = nil
        @layers = nil
      end

      # How many tile layers the engine reads: Game_Map::LAYERS_COUNT where the game sets one (Essentials after 21.1
      # lets a game add layers), else RMXP's three.
      def self.layers
        return @layers if @layers
        n = defined?(Game_Map::LAYERS_COUNT) ? Game_Map::LAYERS_COUNT : nil
        @layers = n.is_a?(Integer) && n > 0 ? n : 3
      end

      # Drops the tiles and the classes too, so every tag is classed again (the game's PBTerrain names may differ).
      def self.reset!
        forget
        @bridge_tags = {}
        @classes = {}
        @values = [nil]
        @bits = [0]
        @numbers = [nil]
        @kinds = [nil]
        @flags = {}
        @named = nil
      end

      # What was read of the map's tiles, with the classes it points to, for Visits to keep with the map left.
      def self.saved
        [@rows, @alike, @bridges, @water, @classes, @values, @bits, @numbers, @kinds, @flags, @named, @bridge_tags]
      end

      # Puts back what saved gave; the map's size is read afresh.
      def self.restore(s)
        @rows, @alike, @bridges, @water, @classes, @values, @bits, @numbers, @kinds, @flags, @named, @bridge_tags = s
        @w = nil
        @h = nil
      end

      # The tag tests at (x,y) as cell bits (SURF, LEDGE, ICE, DEEP, GRASS, FALLING); count_bridge reads a bridge tile
      # as the bridge at any height.
      def self.cell(x, y, count_bridge = false)
        Epoch.settle
        @bits[index(x, y, count_bridge)]
      end

      # The stable kind at (x,y) (:water, :ledge...), or nil for none or a tag of the game's own.
      def self.kind(x, y, count_bridge = false)
        Epoch.settle
        @kinds[index(x, y, count_bridge)]
      end

      # The terrain tag's number at (x,y), or nil where the engine has no answer.
      def self.number(x, y, count_bridge = false)
        Epoch.settle
        @numbers[index(x, y, count_bridge)]
      end

      # True on a one-way ledge.
      def self.ledge?(x, y); (cell(x, y) & LEDGE) != 0; end
      # True on ice (a forced slide).
      def self.ice?(x, y); (cell(x, y) & ICE) != 0; end
      # True on surfable water.
      def self.surfable?(x, y, count_bridge = false); (cell(x, y, count_bridge) & SURF) != 0; end
      # True on deep water, the one dived into and surfaced through.
      def self.deep?(x, y); (cell(x, y) & DEEP) != 0; end
      # True on walkable grass (plain, tall or soot).
      def self.grass?(x, y); (cell(x, y) & GRASS) != 0; end
      # True on a waterfall or its crest.
      def self.falling?(x, y); (cell(x, y) & FALLING) != 0; end

      # True when the tag at (x,y) carries a flag a plugin or a game adds to the modern tag object (a current, a
      # climbable rock, a rail, a slide); no gen-6 tag carries one.
      def self.flag?(x, y, name)
        Epoch.settle
        i = index(x, y, false)
        memo = (@flags[name] ||= {})
        v = memo[i]
        v.nil? ? (memo[i] = flag_of(@values[i], name)) : v
      end

      # The surface's localization key at (x,y), or nil: a game's rule first, else the standard label of the tag with
      # bridges counted, else water for any surfable tag the standard names do not cover.
      def self.label(x, y)
        Epoch.settle
        @label_rules.each do |rule|
          v = (rule.call(x, y) rescue nil)
          return v if v
        end
        i = index(x, y, true)
        LABEL[@kinds[i]] || ((@bits[i] & SURF) != 0 ? :surf_water : nil)
      end

      # True on water for the sonar: any surface label naming water (still, deep, the fall), kept per tile.
      def self.water?(x, y)
        Epoch.settle
        return false if outside?(x, y)
        row = (@water[y] ||= [])
        v = row[x]
        return v unless v.nil?
        lbl = label(x, y)
        row[x] = !lbl.nil? && !lbl.to_s.index("water").nil?
      end

      # The class index of (x,y), read on first sight (read_class).
      def self.index(x, y, count_bridge)
        return 0 if outside?(x, y)
        row = (@rows[y] ||= [])
        v = (count_bridge ? 2 : 0) + (bridge_at?(x, y) && Engine.bridge_height > 0 ? 1 : 0)
        i = row[x * 4 + v]
        i.nil? ? (row[x * 4 + v] = read_class(x, y, count_bridge, v)) : i
      end

      # The class index of (x,y) in variant v (count_bridge and the bridge height, see index): the engine's tag for the
      # first tile with its three tile ids, shared by the rest; a map read past three layers asks every tile.
      def self.read_class(x, y, count_bridge, v)
        d = $game_map.data
        a = d[x, y, 0].to_i
        b = d[x, y, 1].to_i
        c = d[x, y, 2].to_i
        return class_of(Engine.terrain_tag(x, y, count_bridge)) if b >= ID_SPAN || c >= ID_SPAN || layers > 3
        memo = (@alike[a] ||= {})
        k = (c + b * ID_SPAN) * 4 + v
        i = memo[k]
        i.nil? ? (memo[k] = class_of(Engine.terrain_tag(x, y, count_bridge))) : i
      rescue StandardError => e
        PokeAccess.swallowed(e)
        class_of(Engine.terrain_tag(x, y, count_bridge))
      end

      # True when (x,y) lies off the map.
      def self.outside?(x, y)
        @w ||= ($game_map.width rescue 0).to_i
        @h ||= ($game_map.height rescue 0).to_i
        x < 0 || y < 0 || x >= @w || y >= @h
      end

      # True when a layer of (x,y) holds a tile the tileset tags as a bridge, kept per tile; an unreadable map counts
      # as one, so the bridge height is kept in play.
      def self.bridge_at?(x, y)
        return false if outside?(x, y)
        row = (@bridges[y] ||= [])
        v = row[x]
        v.nil? ? (row[x] = layered_bridge?(x, y)) : v
      end

      # Reads every layer of (x,y) for a bridge tile; an unreadable map counts as one.
      def self.layered_bridge?(x, y)
        data = $game_map.data
        tags = $game_map.instance_variable_get(:@terrain_tags)
        return true if data.nil? || tags.nil?
        (0...layers).any? do |i|
          id = data[x, y, i].to_i
          id > 0 && bridge_tag?(tags[id])
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        true
      end

      # True when a tileset's raw tag is a bridge: the engine's own TerrainTag data where it has it, else its kind; kept
      # per tag.
      def self.bridge_tag?(tag)
        return false if tag.nil? || tag == 0
        v = @bridge_tags[tag]
        return v unless v.nil?
        if defined?(GameData::TerrainTag)
          t = (GameData::TerrainTag.try_get(tag) rescue nil)
          return @bridge_tags[tag] = (t.bridge ? true : false) if t.respond_to?(:bridge)
        end
        @bridge_tags[tag] = kind_of(tag) == :bridge
      end

      # The cell bits of a raw tag value read elsewhere (another map's, through MapMeta).
      def self.tag_bits(t); @bits[class_of(t)]; end

      # The class index of a raw tag value, classed on first sight; 0 for no answer.
      def self.class_of(t)
        return 0 if t.nil?
        i = @classes[t]
        return i if i
        i = @values.length
        @values.push(t)
        @kinds.push(kind_of(t))
        @numbers.push(number_of(t))
        @bits.push(bits_of(t))
        @classes[t] = i
      end

      # The tag tests a raw value answers, as cell bits.
      def self.bits_of(t)
        k = kind_of(t)
        b = 0
        surf = surf_ruled?(t) || probe(t, :can_surf, :isSurfable?, :pbIsSurfableTag?) { |n| SURF_NUMBERS.include?(n) }
        b |= SURF if surf
        b |= LEDGE if probe(t, :ledge, :isLedge?) { |n| n == 1 }
        b |= ICE if probe(t, :ice, :isIce?) { |n| n == 12 }
        b |= DEEP if probe(t, :can_dive, :isDeepWater?) { |n| n == 5 }
        b |= GRASS if GRASS_KINDS.include?(k)
        b |= FALLING if FALLING_KINDS.include?(k)
        b
      end

      # One tag test: the modern tag's flag, then the gen-6 PBTerrain helper, then the global one of copies older than
      # v15, then the block over the tag number.
      def self.probe(t, flag, pb_name, global_name = nil)
        return (t.send(flag) ? true : false) if t.respond_to?(flag)
        return (PBTerrain.send(pb_name, t) ? true : false) if defined?(PBTerrain) && PBTerrain.respond_to?(pb_name)
        return (Kernel.send(global_name, t) ? true : false) if global_name && Kernel.respond_to?(global_name, true)
        yield(number_of(t)) ? true : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # True when a game's surf rule lets the player surf on a raw tag value here.
      def self.surf_ruled?(t)
        n = number_of(t)
        @surf_rules.any? { |r| (r.call(n) rescue false) }
      end

      # True when a raw value answers a flag a plugin adds to the tag object.
      def self.flag_of(t, name)
        t.respond_to?(name) && t.send(name) ? true : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # The number of a raw value: the modern tag's id_number, a gen-6 Integer as it is.
      def self.number_of(t)
        return nil if t.nil?
        return (t.id_number rescue nil) if t.respond_to?(:id_number)
        t.is_a?(Integer) ? t : nil
      end

      # The stable kind of a raw value: the tag object's id when it maps, else its number read through the game's
      # PBTerrain names. The Integer guard is for 1.8.7, where Object#id exists and warns.
      def self.kind_of(t)
        return nil if t.nil?
        if !t.is_a?(Integer) && t.respond_to?(:id)
          k = IDS[(t.id rescue nil)]
          return k if k
        end
        n = number_of(t)
        named = named_kinds
        named.key?(n) ? named[n] : KIND[n]
      end

      # number => kind by the game's PBTerrain constant names: a number given another name maps to nil (Insurgence's 4
      # is RockClimb), and a standard name wins over another on the same number; empty with no PBTerrain.
      def self.named_kinds
        return @named if @named
        pairs = defined?(PBTerrain) ? PBTerrain.constants.map { |c| [c, (PBTerrain.const_get(c) rescue nil)] } : []
        @named = kinds_of_names(pairs)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        @named = {}
      end

      # number => kind for [constant name, value] pairs, in whatever order the engine lists them (see named_kinds).
      def self.kinds_of_names(pairs)
        out = {}
        pairs.each do |c, n|
          next unless n.is_a?(Integer)
          k = IDS[c.to_sym]
          out[n] = k if k || !out.key?(n)
        end
        out
      end

      reset!
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) do
  t = PokeAccess::World::Terrain
  t.ruled? ? t.reset! : t.forget
end
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Terrain.reset! }
PokeAccess::World::Visits.keeper(lambda { PokeAccess::World::Terrain.saved },
                                 lambda { |s| PokeAccess::World::Terrain.restore(s) })
