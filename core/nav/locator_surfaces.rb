module PokeAccess
  # Locator part 2 of 3: terrain surfaces as navigation targets. Scans tiles around the player for
  # interesting surfaces and exposes the nearest of each as a synthetic SurfaceTarget, cached per tile.
  module Locator
    # A synthetic target for a map tile; key is its surface symbol (:surf_water...), :mark, or nil for a map edge; ref,
    # what it was made for where its tile does not tell it (a map edge's destination, an event's id, :surface for the
    # nearest tile of a surface), for its identity.
    SurfaceTarget = Struct.new(:x, :y, :name, :key, :ref) do
      def character_name; ""; end
    end

    # kind => localization key for navigable surfaces (the per-tile resolution lives in World::Terrain.label).
    def self.surface_label_map
      PokeAccess::World::Terrain::LABEL
    end

    # The nearest tile of each surface on or beside a tile the player can get to (Routes::Regions), as synthetic
    # targets, nearest as the order chosen counts it (surface_rank); cached per player tile, order, vehicle and reach,
    # and until an event ends (refresh_on_event_end).
    def self.surface_targets
      reach = [(PokeAccess::Pathfinder.vehicle_state rescue nil), (PokeAccess::Routes::Regions.foot.tiles.length rescue 0),
               (PokeAccess::Config.target_order rescue :near)]
      pos = [$game_player.x, $game_player.y, ($game_map.map_id rescue 0), reach]
      return @surface_cache if @surface_cache && @surface_cache_pos == pos
      @surface_cache_pos = pos
      @surface_cache = scan_surfaces(pos[0], pos[1])
    end

    # One pass over the reachable tiles and the ring around them, keeping the tile of each surface that ranks first
    # (surface_rank).
    def self.scan_surfaces(px, py)
      rt = PokeAccess::Routes
      reg = (PokeAccess::Config.target_order rescue :near) == :walk ? rt::Regions.foot : nil
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      seen = {}
      best = {}
      look = lambda do |tx, ty|
        next if tx < 0 || ty < 0 || tx >= w || ty >= h
        k = rt.pkey(tx, ty)
        next if seen[k]
        seen[k] = true
        lbl = PokeAccess::World::Terrain.label(tx, ty)
        next if lbl.nil?
        r = surface_rank(tx, ty, px, py, reg, false)
        best[lbl] = [r, tx, ty] if best[lbl].nil? || (r <=> best[lbl][0]) < 0
      end
      (rt::Regions.foot.tiles rescue []).each do |x, y|
        look.call(x, y)
        rt::DIRS.each { |dir| look.call(x + dir[0], y + dir[1]) }
      end
      dive = dive_spots(px, py, reg)
      best.delete(:surf_deepwater) if dive[:surf_dive]
      best.merge!(dive)
      best.map { |lbl, info| SurfaceTarget.new(info[1], info[2], PokeAccess::I18n.t(lbl), lbl, :surface) }
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # How a surface's tile ranks to stand for it, the least first: with reg (the walk order's regions on foot) the
    # fewest presses to it as the list orders and routes to it (Planner.goal_for; stood on with onto), those with no
    # way told after; then the nearest counting no walls.
    def self.surface_rank(x, y, px, py, reg, onto)
      d = (x - px).abs + (y - py).abs
      return [d] unless reg
      w = reg.presses_to(PokeAccess::Routes::Planner.goal_for(x, y, onto).tiles)
      w ? [0, w, d] : [1, d]
    end

    # The places to dive and to come up that rank first (surface_rank with reg), as { label => [rank, x, y] }: deep
    # water over a dive map (unless the party surely cannot dive), and underwater tiles under the upper map's deep
    # water.
    def self.dive_spots(px, py, reg)
      rg = PokeAccess::Routes::Regions
      mid = ($game_map.map_id rescue 0)
      out = {}
      if PokeAccess::MapMeta.dive_map(mid) && PokeAccess::FieldMoves.can?(:DIVE) != false
        tiles = ($PokemonGlobal.surfing rescue false) ? rg.foot.tiles : rg.water.tiles
        nearest_where(tiles, px, py, reg, out, :surf_dive) { |x, y| PokeAccess::World::Terrain.deep?(x, y) }
      end
      up = ($PokemonGlobal.diving rescue false) ? PokeAccess::MapMeta.surface_map(mid) : nil
      if up && !surface_anywhere?
        nearest_where(rg.foot.tiles, px, py, reg, out, :surf_surface) do |x, y|
          (PokeAccess::World::Terrain.tag_bits(PokeAccess::MapMeta.terrain_on(up, x, y)) & PokeAccess::World::Terrain::DEEP) != 0
        end
      end
      out
    rescue StandardError => e
      PokeAccess.swallowed(e)
      {}
    end

    # Records in out[label] the tile of tiles the block accepts that ranks first to be stood on (surface_rank).
    def self.nearest_where(tiles, px, py, reg, out, label)
      tiles.each do |x, y|
        next unless yield(x, y)
        r = surface_rank(x, y, px, py, reg, true)
        out[label] = [r, x, y] if out[label].nil? || (r <=> out[label][0]) < 0
      end
    end

    # A synthetic target's name in the language chosen now: a surface by its label, a map edge by its destination's
    # name now (edge_name); any other keeps the name it was built with.
    def self.synthetic_name(t)
      return PokeAccess::I18n.t(t.key) if t.ref == :surface
      edge?(t) ? edge_name(t.ref) : t.name.to_s
    end

    # What a map edge leading to map dest is called: an exit to it by its name, or a bare exit for a map with none.
    def self.edge_name(dest)
      nm = (map_name(dest) rescue nil)
      nm ? PokeAccess::I18n.t(:loc_exit_to, :map => nm) : PokeAccess::I18n.t(:loc_exit)
    end

    # The arrival line of a spot the player acts on where it lies (dive, surface), or nil for any other target.
    def self.dive_key(t)
      return nil unless t.is_a?(SurfaceTarget)
      { :surf_dive => :loc_dive_here, :surf_surface => :loc_surface_here }[t.key]
    end

    # The way to step off the map from a map edge's exit, the player standing on its tile: that border tile's way out
    # (an open one first, where a corner leads off two ways), else nil.
    def self.edge_out(t)
      return nil unless edge?(t) && $game_player && $game_player.x == t.x && $game_player.y == t.y
      ways = ((@conn_edges || {})[t.ref] || []).select { |x, y, _w| x == t.x && y == t.y }
      e = ways.find { |w| edge_open?(w) } || ways[0]
      e && e[2]
    end

    # What a target stood on says with the player on it: what to do there (dive, surface), the way off the map on an
    # edge's exit ("you have arrived, exit to the left", and for the route key "route: exit to the left"), else that
    # the player has arrived.
    def self.arrived_line(t, route = false)
      d = edge_out(t)
      return PokeAccess::I18n.t(dive_key(t) || :loc_arrived) if d.nil?
      way = PokeAccess::Routes::Text.exit_out(d)
      route ? PokeAccess::I18n.t(:loc_route, :steps => way) : PokeAccess::I18n.t(:loc_arrived_exit, :exit => way)
    end

    # True when the game lets the player come up from anywhere underwater, so no surfacing spot is listed.
    def self.surface_anywhere?
      return ::Settings::DIVING_SURFACE_ANYWHERE ? true : false if defined?(::Settings) && ::Settings.const_defined?(:DIVING_SURFACE_ANYWHERE)
      defined?(DIVINGSURFACEANYWHERE) && DIVINGSURFACEANYWHERE ? true : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
      connection_tile(connections_for(id), id, ox, oy)
    rescue StandardError => e
      PokeAccess.swallowed(e)
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

    # The border tiles that lead off this map, by destination map id, as [x, y, the way out]; none on a map with no
    # connections.
    def self.connection_edges
      connection_targets
      @conn_targets_mid == ($game_map && $game_map.map_id) ? (@conn_edges || {}) : {}
    end

    # Builds the per-map exit targets: per destination, the border tile nearest the map centre, with every border tile
    # leading there kept by destination, with its way out, for aim_connection and the sonar.
    def self.build_connection_targets(id)
      @conn_edges = {}
      conns = connections_for(id)
      return [] if conns.empty?
      w = ($game_map.width rescue 0); h = ($game_map.height rescue 0)
      return [] if w <= 0 || h <= 0
      cx = w / 2; cy = h / 2
      best = {}
      edges = {}
      check = lambda do |tx, ty, ox, oy, way|
        far = (connection_tile(conns, id, ox, oy) rescue nil)
        return unless far
        dest = far[0]
        (edges[dest] ||= []).push([tx, ty, way])
        d = (tx - cx).abs + (ty - cy).abs
        best[dest] = [d, tx, ty] if best[dest].nil? || d < best[dest][0]
      end
      (0...w).each { |x| check.call(x, 0, x, -1, 8); check.call(x, h - 1, x, h, 2) }
      (0...h).each { |y| check.call(0, y, -1, y, 4); check.call(w - 1, y, w, y, 6) }
      best.map do |dest, info|
        @conn_edges[dest] = edges[dest]
        SurfaceTarget.new(info[1], info[2], edge_name(dest), nil, dest)
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
      []
    end

    # A map-edge exit aimed at its open border tile (edge_open?) the fewest presses away on foot (edge_on_foot); when
    # the regions cannot tell, at its own tile if open and not known out of reach, else at the nearest open one that can
    # be got to or, its own being shut, of them all; else left as it is. Nil when no tile of the edge is open.
    def self.aim_connection(t)
      all = (@conn_edges || {})[t.ref]
      return t if all.nil?
      edges = all.select { |e| edge_open?(e) }
      return nil if edges.empty?
      own = edges.any? { |e| e[0] == t.x && e[1] == t.y }
      return t if own && edges.length == 1
      reg = PokeAccess::Routes::Regions.foot
      px = $game_player.x; py = $game_player.y
      x, y = edge_on_foot(edges, reg, px, py)
      if x.nil?
        return t if own && reg.status([[t.x, t.y]])[0] != :no
        open = edges.select { |ex, ey| reg.status([[ex, ey]])[0] == :yes }
        open = edges if open.empty? && !own
        return t if open.empty?
        x, y = open.min_by { |ex, ey| (ex - px).abs + (ey - py).abs }
      end
      x == t.x && y == t.y ? t : SurfaceTarget.new(x, y, t.name, t.key, t.ref)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      t
    end

    # True if the engine lets the player step off the map from a border tile [x, y, the way out] (World::Probe, as the
    # sonar asks it); a tile with no way out given counts as open.
    def self.edge_open?(e)
      e[2].nil? || PokeAccess::World::Probe.step?(e[0], e[1], e[2], true)
    end

    # The border tile of edges the fewest presses away on foot (Routes::Regions#presses_to), the nearest counting no
    # walls among those as near; nil while the regions cannot tell, or when they reach none.
    def self.edge_on_foot(edges, reg, px, py)
      best = nil
      edges.each do |x, y|
        d = reg.presses_to([[x, y]])
        next if d.nil?
        k = [d, (x - px).abs + (y - py).abs]
        best = [k, x, y] if best.nil? || (k <=> best[0]) < 0
      end
      best && best[1, 2]
    end
  end
end
