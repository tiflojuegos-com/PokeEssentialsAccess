module PokeAccess
  # Locator part 2 of 4: terrain surfaces as navigation targets. Scans tiles around the player for
  # interesting surfaces and exposes the nearest of each as a synthetic SurfaceTarget, cached per tile.
  module Locator
    # A synthetic target standing for a map tile of a given surface, so navigation works on terrain like
    # on events. key is the language-neutral surface symbol (:surf_water...) for type matching.
    SurfaceTarget = Struct.new(:x, :y, :name, :key) do
      def character_name; ""; end
    end

    # kind => localization key for navigable surfaces (the per-tile resolution lives in Terrain.label).
    def self.surface_label_map
      PokeAccess::Terrain::LABEL
    end

    # Nearest tile of each interesting surface the player can actually get to, as synthetic targets, cached
    # per player tile.
    #
    # The pathfinder answers, not a box around the player: straight-line distance is not what a navigation
    # menu is about, and a box is wrong in both directions at once -- too small for the grass at the far end
    # of a route the guide would happily walk to, too big for a lake behind a locked door. This reuses the
    # flood already computed for this tile and shared with the unreachable filter, inheriting its route_reach
    # limit for free. The LIST only: the sonar keeps its own short range, since what you can hear and where
    # you can walk are different questions.
    #
    # The border ring is what keeps water on the list. You cannot stand on water, so the flood never enters
    # it, but you can stand beside it, which is what the guide is for, with surf_launch taking over there.
    def self.surface_targets
      pos = [$game_player.x, $game_player.y, ($game_map.map_id rescue 0)]
      return @surface_cache if @surface_cache && @surface_cache_pos == pos
      @surface_cache_pos = pos
      @surface_cache = scan_surfaces(pos[0], pos[1])
    end

    # One pass over the reachable tiles and the ring around them, keeping the nearest tile of each surface.
    def self.scan_surfaces(px, py)
      pf = PokeAccess::Pathfinder
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      seen = {}
      best = {}
      look = lambda do |tx, ty|
        next if tx < 0 || ty < 0 || tx >= w || ty >= h
        k = pf.pkey(tx, ty)
        next if seen[k]
        seen[k] = true
        lbl = PokeAccess::Terrain.label(tx, ty)
        next if lbl.nil?
        d = (tx - px).abs + (ty - py).abs
        best[lbl] = [d, tx, ty] if best[lbl].nil? || d < best[lbl][0]
      end
      (pf.reachable_set rescue {}).each_key do |k|
        x = k / pf::PKEY_STRIDE; y = k % pf::PKEY_STRIDE
        look.call(x, y)
        pf::DIRS.each { |dir| look.call(x + dir[0], y + dir[1]) }
      end
      best.map { |lbl, info| SurfaceTarget.new(info[1], info[2], PokeAccess::I18n.t(lbl), lbl) }
    rescue StandardError
      []
    end

    # The connections involving a map, across engines. Two shapes answer to the same method name, so the
    # shape is probed and never assumed: gen-6 returns ONE flat list, each entry a connection row, while
    # both Infinite Fusion games return an array INDEXED BY MAP ID whose entries are the lists touching that
    # map, with nil in every unused id and no eachConnectionForMap to give the shape away. Read flat, that
    # compares a nested list against an integer and raises on the nil holes.
    def self.connections_for(id)
      if MapFactoryHelper.respond_to?(:eachConnectionForMap)
        list = []
        (MapFactoryHelper.eachConnectionForMap(id) { |c| list.push(c) } rescue nil)
        return list
      end
      c = (MapFactoryHelper.getMapConnections rescue nil)
      return [] unless c.is_a?(Array)
      indexed?(c) ? (c[id].is_a?(Array) ? c[id] : []) : c
    rescue StandardError
      []
    end

    # True when the connection table is indexed by map id: its entries are lists OF connection rows rather
    # than connection rows themselves.
    def self.indexed?(table)
      table.any? { |e| e.is_a?(Array) && e[0].is_a?(Array) }
    rescue StandardError
      false
    end

    # The map id reached by stepping onto off-map (ox, oy) via a connection, or nil. Uses the engine's
    # own connection math, so it agrees exactly with where the game would transfer the player.
    def self.connection_dest(conns, id, ox, oy)
      conns.each do |conn|
        if conn[0] == id
          dims = (MapFactoryHelper.getMapDims(conn[3]) rescue [0, 0])
          nx = (conn[4] - conn[1]) + ox; ny = (conn[5] - conn[2]) + oy
          return conn[3] if dims[0] > 0 && nx >= 0 && nx < dims[0] && ny >= 0 && ny < dims[1]
        elsif conn[3] == id
          dims = (MapFactoryHelper.getMapDims(conn[0]) rescue [0, 0])
          nx = (conn[1] - conn[4]) + ox; ny = (conn[2] - conn[5]) + oy
          return conn[0] if dims[0] > 0 && nx >= 0 && nx < dims[0] && ny >= 0 && ny < dims[1]
        end
      end
      nil
    end

    # Synthetic exit targets for map-EDGE connections (walk off the edge into the next map): keeps the
    # nearest border tile per destination, labelled "salida a <map>". Without this, edge exits are
    # invisible to the locator (engines without MapFactoryHelper get none).
    # One exit target per connected destination. Cached per map_id (the cache self-invalidates when the
    # player changes map, since id then differs): the border scan below is O(perimeter x connections) and
    # otherwise ran on EVERY rebuild_targets (each event-end) -- the source of the occasional map_poll spike.
    def self.connection_targets
      return [] unless defined?(MapFactoryHelper) && $game_map && $game_player
      id = $game_map.map_id
      return @conn_targets if @conn_targets && @conn_targets_mid == id
      @conn_targets_mid = id
      @conn_targets = build_connection_targets(id)
    end

    # Builds the per-map exit targets, choosing one representative border tile per destination relative to
    # the map centre (the cache is per-map, not per-player-position, and any tile on a connected edge is a
    # valid exit for pathfinding).
    def self.build_connection_targets(id)
      conns = connections_for(id)
      return [] if conns.empty?
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return [] if w <= 0 || h <= 0
      cx = w / 2; cy = h / 2
      best = {}
      check = lambda do |tx, ty, ox, oy|
        dest = (connection_dest(conns, id, ox, oy) rescue nil)
        return unless dest
        d = (tx - cx).abs + (ty - cy).abs
        best[dest] = [d, tx, ty] if best[dest].nil? || d < best[dest][0]
      end
      (0...w).each { |x| check.call(x, 0, x, -1); check.call(x, h - 1, x, h) }
      (0...h).each { |y| check.call(0, y, -1, y); check.call(w - 1, y, w, y) }
      best.map do |dest, info|
        nm = (map_name(dest) rescue nil)
        label = nm ? PokeAccess::I18n.t(:loc_exit_to, :map => nm) : PokeAccess::I18n.t(:loc_exit)
        SurfaceTarget.new(info[1], info[2], label, nil)
      end
    rescue StandardError
      []
    end
  end
end
