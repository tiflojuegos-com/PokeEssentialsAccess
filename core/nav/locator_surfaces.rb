module PokeAccess
  # Locator part 2 of 4: terrain surfaces as navigation targets. Scans tiles around the player for
  # interesting surfaces and exposes the nearest of each as a synthetic SurfaceTarget, cached per tile.
  module Locator
    # A synthetic target for a map tile; key is its surface symbol (:surf_water...), :mark, or nil for a map edge.
    SurfaceTarget = Struct.new(:x, :y, :name, :key) do
      def character_name; ""; end
    end

    # kind => localization key for navigable surfaces (the per-tile resolution lives in Terrain.label).
    def self.surface_label_map
      PokeAccess::Terrain::LABEL
    end

    # The nearest tile of each surface in or beside the pathfinder's flood, as synthetic targets, cached per player
    # tile (the ring beside the flood keeps water the player can stand next to).
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
      dive = dive_spots(px, py)
      best.delete(:surf_deepwater) if dive[:surf_dive]
      best.merge!(dive)
      best.map { |lbl, info| SurfaceTarget.new(info[1], info[2], PokeAccess::I18n.t(lbl), lbl) }
    rescue StandardError
      []
    end

    # The nearest places to dive and to come up, as { label => [distance, x, y] }: deep water over a dive map (unless
    # the party surely cannot dive), and underwater tiles under the upper map's deep water.
    def self.dive_spots(px, py)
      pf = PokeAccess::Pathfinder
      mid = ($game_map.map_id rescue 0)
      out = {}
      if PokeAccess::MapMeta.dive_map(mid) && PokeAccess::FieldMoves.can?(:DIVE) != false
        set = ($PokemonGlobal.surfing rescue false) ? pf.reachable_set : pf.amphibious_set
        nearest_where(set, px, py, out, :surf_dive) { |x, y| PokeAccess::Terrain.deep?(PokeAccess::Terrain.raw(x, y)) }
      end
      up = ($PokemonGlobal.diving rescue false) ? PokeAccess::MapMeta.surface_map(mid) : nil
      if up && !surface_anywhere?
        nearest_where(pf.reachable_set, px, py, out, :surf_surface) do |x, y|
          PokeAccess::Terrain.deep?(PokeAccess::MapMeta.terrain_on(up, x, y))
        end
      end
      out
    rescue StandardError
      {}
    end

    # Records in out[label] the tile of the set nearest (px,py) that the block accepts.
    def self.nearest_where(set, px, py, out, label)
      stride = PokeAccess::Pathfinder::PKEY_STRIDE
      (set || {}).each_key do |k|
        x = k / stride; y = k % stride
        next unless yield(x, y)
        d = (x - px).abs + (y - py).abs
        out[label] = [d, x, y] if out[label].nil? || d < out[label][0]
      end
    end

    # True when the game lets the player come up from anywhere underwater, so no surfacing spot is listed.
    def self.surface_anywhere?
      return Settings::DIVING_SURFACE_ANYWHERE ? true : false if defined?(Settings) && Settings.const_defined?(:DIVING_SURFACE_ANYWHERE)
      defined?(DIVINGSURFACEANYWHERE) && DIVINGSURFACEANYWHERE ? true : false
    rescue StandardError
      false
    end

    # The connections involving a map: eachConnectionForMap where it exists, else getMapConnections, a flat list on
    # gen-6 but indexed by map id in both Infinite Fusion games (probed by indexed?).
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

    # True when the connection table is indexed by map id: its entries are lists of connection rows.
    def self.indexed?(table)
      table.any? { |e| e.is_a?(Array) && e[0].is_a?(Array) }
    rescue StandardError
      false
    end

    # The map id reached by stepping onto off-map (ox, oy) via a connection, or nil, by the engine's connection math.
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

    # Synthetic exit targets for map-edge connections, one per destination map ("exit to <map>"), cached per map id;
    # none without MapFactoryHelper.
    def self.connection_targets
      return [] unless defined?(MapFactoryHelper) && $game_map && $game_player
      id = $game_map.map_id
      return @conn_targets if @conn_targets && @conn_targets_mid == id
      @conn_targets_mid = id
      @conn_targets = build_connection_targets(id)
    end

    # Builds the per-map exit targets: per destination, the border tile nearest the map centre, with every border tile
    # leading there kept for aim_connection.
    def self.build_connection_targets(id)
      @conn_edges = {}
      conns = connections_for(id)
      return [] if conns.empty?
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return [] if w <= 0 || h <= 0
      cx = w / 2; cy = h / 2
      best = {}
      edges = {}
      check = lambda do |tx, ty, ox, oy|
        dest = (connection_dest(conns, id, ox, oy) rescue nil)
        return unless dest
        (edges[dest] ||= []).push([tx, ty])
        d = (tx - cx).abs + (ty - cy).abs
        best[dest] = [d, tx, ty] if best[dest].nil? || d < best[dest][0]
      end
      (0...w).each { |x| check.call(x, 0, x, -1); check.call(x, h - 1, x, h) }
      (0...h).each { |y| check.call(0, y, -1, y); check.call(w - 1, y, w, y) }
      best.map do |dest, info|
        @conn_edges[[info[1], info[2]]] = edges[dest]
        nm = (map_name(dest) rescue nil)
        label = nm ? PokeAccess::I18n.t(:loc_exit_to, :map => nm) : PokeAccess::I18n.t(:loc_exit)
        SurfaceTarget.new(info[1], info[2], label, nil)
      end
    rescue StandardError
      []
    end

    # A map-edge exit moved to its reachable border tile nearest the player when its own tile is unreachable; left as
    # it is when the flood is incomplete.
    def self.aim_connection(t)
      edges = (@conn_edges || {})[[t.x, t.y]]
      return t if edges.nil? || edges.length <= 1
      pf = PokeAccess::Pathfinder
      return t unless (pf.reachable_set_complete? rescue false)
      set = pf.reachable_set
      return t if set[pf.pkey(t.x, t.y)]
      px = $game_player.x; py = $game_player.y
      open = edges.select { |x, y| set[pf.pkey(x, y)] }
      return t if open.empty?
      x, y = open.min_by { |ex, ey| (ex - px).abs + (ey - py).abs }
      SurfaceTarget.new(x, y, t.name, t.key)
    rescue StandardError
      t
    end
  end
end
