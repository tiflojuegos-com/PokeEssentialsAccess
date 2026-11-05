module PokeAccess
  module World
    # The engine's own answers where the eras differ, behind one name each: the terrain tag (the Reborn engine's takes
    # no bridge argument), where the bridge height is kept ($PokemonGlobal from v16, $PokemonMap before, as in
    # Insurgence), the map factory's name and the shape of the map connections.
    module Engine
      @bridge_arg = nil

      # The engine's raw terrain tag at (x,y), an Integer or a GameData::TerrainTag, or nil when it cannot answer;
      # count_bridge takes a bridge tile at any height, where the engine's tag can be told to.
      def self.terrain_tag(x, y, count_bridge = false)
        m = $game_map
        return nil unless m
        return m.terrain_tag(x, y) unless count_bridge && bridge_arg?
        begin
          m.terrain_tag(x, y, true)
        rescue ArgumentError
          @bridge_arg = false
          m.terrain_tag(x, y)
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # True while the map's terrain_tag is taken to accept the bridge argument: judged once by the arity of the map
      # object's own method, and dropped for good the first time a call with it is refused.
      def self.bridge_arg?
        return @bridge_arg unless @bridge_arg.nil?
        a = ($game_map.method(:terrain_tag).arity rescue -1)
        @bridge_arg = a < 0 || a >= 3
      end

      # The object the engine keeps the bridge height on, or nil when it keeps none.
      def self.bridge_holder
        g = $PokemonGlobal
        return g if g.respond_to?(:bridge)
        m = $PokemonMap
        m.respond_to?(:bridge) ? m : nil
      end

      # The bridge height the engine is at, 0 off every bridge.
      def self.bridge_height
        h = bridge_holder
        h ? h.bridge.to_i : 0
      rescue StandardError => e
        PokeAccess.swallowed(e)
        0
      end

      # Sets the engine's bridge height, where it keeps one.
      def self.set_bridge(lvl)
        h = bridge_holder
        h.bridge = lvl if h
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The engine's map factory, nil before it has one ($map_factory from v20, $MapFactory before).
      def self.map_factory
        (defined?($map_factory) && $map_factory) || (defined?($MapFactory) && $MapFactory) || nil
      end

      # The connections involving a map: those the data provider keeps (Data.optional), else eachConnectionForMap where
      # it exists, else getMapConnections, a flat list on gen-6 but indexed by map id in both Infinite Fusion games
      # (probed by indexed?).
      def self.connections(id)
        kept = PokeAccess::Data.optional(:map_connections)
        return kept if kept.is_a?(Array)
        if MapFactoryHelper.respond_to?(:eachConnectionForMap)
          list = []
          (MapFactoryHelper.eachConnectionForMap(id) { |c| list.push(c) } rescue nil)
          return list
        end
        c = (MapFactoryHelper.getMapConnections rescue nil)
        return [] unless c.is_a?(Array)
        indexed?(c) ? (c[id].is_a?(Array) ? c[id] : []) : c
      rescue StandardError => e
        PokeAccess.swallowed(e)
        []
      end

      # True when the connection table is indexed by map id: its entries are lists of connection rows.
      def self.indexed?(table)
        table.any? { |e| e.is_a?(Array) && e[0].is_a?(Array) }
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # The map reached by stepping onto off-map (ox, oy) via a connection and the tile there, as [map id, x, y], or nil,
      # by the engine's connection math.
      def self.connection_tile(conns, id, ox, oy)
        conns.each do |conn|
          if conn[0] == id
            dest = conn[3]
            nx = (conn[4] - conn[1]) + ox; ny = (conn[5] - conn[2]) + oy
          elsif conn[3] == id
            dest = conn[0]
            nx = (conn[1] - conn[4]) + ox; ny = (conn[2] - conn[5]) + oy
          else
            next
          end
          dims = (MapFactoryHelper.getMapDims(dest) rescue [0, 0])
          return [dest, nx, ny] if dims[0] > 0 && nx >= 0 && nx < dims[0] && ny >= 0 && ny < dims[1]
        end
        nil
      end

      # The tile across a connection from off-map (ox, oy) of the current map, as connection_tile; nil on a map with no
      # connections.
      def self.across(ox, oy)
        return nil unless defined?(MapFactoryHelper) && $game_map
        id = $game_map.map_id
        connection_tile(connections(id), id, ox, oy)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end
    end
  end
end
