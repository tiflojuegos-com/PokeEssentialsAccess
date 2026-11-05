module PokeAccess
  module World
    # The maps across this map's edges, as the engine reads them to answer a step off the map. Asked about one it has
    # not loaded, the engine builds a fresh copy for every question, its file and all its events, and throws it away.
    # With neighbour_cache the last neighbour_cache_size copies are kept and lent to its factory for the question. A copy
    # answers as a fresh one would: its events stand where the map places them, the game never updates it, and their
    # pages are taken afresh once a frame. A neighbour the game has loaded answers for itself.
    module Neighbours
      # The fewest map frames between two maps built ahead of any question (warm).
      WARM_GAP = 10

      # A kept map: its id, the copy and the world frame its pages were last taken.
      Copy = Struct.new(:id, :map, :frame)

      @kept = []
      @warm_at = 0
      @tried = []

      # Runs the block, which asks the engine about a step onto off-map (ox, oy), with the copy of the map across lent to
      # the factory, which looks among its maps before building one. A step the engine runs out of stack on is closed:
      # stock Essentials 20.1, without its hotfix, can rebuild a map for ever, and no ordinary rescue stops that.
      def self.lending(ox, oy)
        maps = on? ? factory_maps : nil
        far = maps && Engine.across(ox, oy)
        copy = far && maps.none? { |m| m.map_id == far[0] } ? copy_of(far[0]) : nil
        return yield unless copy
        maps.push(copy)
        begin
          yield
        ensure
          maps.delete(copy)
        end
      rescue SystemStackError => e
        PokeAccess.swallowed(e)
        Probe::CLOSED
      end

      # Map id as the engine would read it now: the one it has loaded, else a copy; nil when neither can be had.
      def self.map(id)
        maps = factory_maps
        return nil unless maps
        maps.find { |m| m.map_id == id } || copy_of(id)
      rescue SystemStackError => e
        PokeAccess.swallowed(e)
        nil
      end

      # One map frame with neighbours_background on and the player still: builds the first neighbour of this map not yet
      # tried, neither kept nor loaded, at most one every WARM_GAP map frames.
      def self.warm
        return unless on? && (PokeAccess::Config.neighbours_background rescue false)
        now = PokeAccess::Frame.serial
        return if now < @warm_at || ($game_player.moving? rescue true)
        maps = factory_maps
        id = maps && $game_map ? missing(maps) : nil
        return unless id
        @warm_at = now + WARM_GAP
        @tried.push(id)
        build(id)
      rescue StandardError, SystemStackError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The ids of the maps kept, oldest first.
      def self.maps; @kept.map { |c| c.id }; end

      # Forgets every map kept.
      def self.forget; @kept = []; end

      # Whether copies are kept.
      def self.on?; (PokeAccess::Config.neighbour_cache rescue true) ? true : false; end

      # The maps the engine's factory holds, nil with no factory that builds a map apart from them.
      def self.factory_maps
        f = Engine.map_factory
        f && f.respond_to?(:getMapNoAdd) ? PokeAccess.ivar(f, :@maps) : nil
      end

      # The copy of map id with its pages as they are now, built if none is kept; nil when it cannot be had, for the
      # engine to answer by itself.
      def self.copy_of(id)
        c = @kept.find { |k| k.id == id }
        if c
          @kept.delete(c)
          @kept.push(c)
          refresh(c)
        else
          c = build(id)
        end
        c && c.map
      rescue StandardError => e
        PokeAccess.swallowed(e)
        @kept.delete_if { |k| k.id == id }
        nil
      end

      # Builds the copy of map id, as the engine builds one to answer, and keeps it with the cache on; the oldest goes
      # past neighbour_cache_size.
      def self.build(id)
        map = apart { Engine.map_factory.getMapNoAdd(id) }
        return nil unless map
        c = Copy.new(id, map, Epoch.frame)
        return c unless on?
        @kept.push(c)
        @kept.shift while @kept.length > PokeAccess::Config.neighbour_cache_size
        c
      end

      # Takes a copy's pages afresh, once a frame: the game itself picks each event's page for the state it reads.
      def self.refresh(c)
        now = Epoch.frame
        return if c.frame == now
        c.frame = now
        apart { c.map.events.each_value { |ev| ev.refresh } }
      end

      # The first neighbour of this map not yet tried on it, neither kept nor loaded, or nil.
      def self.missing(maps)
        here = $game_map.map_id
        @tried = [here] unless @tried[0] == here
        Engine.connections(here).each do |c|
          id = c[0] == here ? c[3] : (c[3] == here ? c[0] : nil)
          next if id.nil? || @tried.include?(id) || @kept.any? { |k| k.id == id } || maps.any? { |m| m.map_id == id }
          return id
        end
        nil
      end

      # Runs the block with the game kept out of it. There is no scene, as a plugin that draws from an event's refresh
      # (Event Indicators) would put a copy's events on the screen in the place of the map's own, and the switches and
      # variables are put back, as a map's setup may set them as if the player had come in (Rejuvenation's AtebitDesire).
      def self.apart
        scene = $scene
        flags = [$game_switches, $game_variables].map { |s| PokeAccess.ivar(s, :@data) }.select { |d| d.is_a?(Array) }
        kept = flags.map { |d| d.dup }
        $scene = nil
        begin
          yield
        ensure
          $scene = scene
          flags.each_with_index { |d, i| d.replace(kept[i]) }
        end
      end
    end
  end
end
