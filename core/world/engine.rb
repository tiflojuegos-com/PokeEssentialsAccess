module PokeAccess
  module World
    # The engine's own answers where the eras differ, behind one name each: the terrain tag (the Reborn engine's takes
    # no bridge argument) and where the bridge height is kept ($PokemonGlobal from v16, $PokemonMap before, as in
    # Insurgence).
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
    end
  end
end
