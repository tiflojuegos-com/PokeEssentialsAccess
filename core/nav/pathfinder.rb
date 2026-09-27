module PokeAccess
  # The pathfinder's frame: the search context, the passability memo and per-map event indexes, and the entry points.
  # Searches live in route_search (A*, the flood) and route_grid (JPS, HPA*); steps in route_terrain, route_events
  # and route_water; assisted routes in route_gates; the spoken route in route_text.
  module Pathfinder
    # Tile-coordinate packing stride: a tile packs as x*PKEY_STRIDE+y into one Integer hash key (HPA* reuses
    # the same stride to pack cluster ids). Map dimensions stay well under it.
    PKEY_STRIDE = 100000

    # Packs a tile coordinate into a single hash key.
    def self.pkey(x, y); x * PKEY_STRIDE + y; end

    # The four orthogonal steps as [dx, dy, rpg direction code], in the order the search and the flood try
    # them, and the same steps by direction code.
    DIRS = [8, 2, 4, 6].map { |d| PokeAccess::DIR_DELTA[d].dup.push(d) }
    DIR_OF = DIRS.inject({}) { |h, s| h[s[2]] = s; h }

    # One move of a route as the search makes it and the replay retraces it: the tile and bridge level it
    # leaves the player on, how many presses of the same key it takes (a run), the gate of an assisted step
    # (see route_gates), and in a replay whether it is a tile passed partway along a run (mid).
    Step = Struct.new(:x, :y, :level, :presses, :gate, :mid)

    # Step with the defaults a plain move has: one press, no gate, not partway along a run.
    class Step
      def initialize(x, y, level, presses = 1, gate = nil, mid = false)
        super
      end

      # The [x, y] tile the step leaves the player on.
      def tile; [x, y]; end
    end

    # What one search operation carries, shared by its nested searches and dropped with the outermost: the shared
    # deadline, the nesting depth, the player's starting vehicle and bridge level, whether bridge levels are live, the
    # touch index at hand, and whether it is assisted and with which obstacles set aside (see route_gates).
    SearchContext = Struct.new(:deadline, :depth, :vehicle, :level, :levels_live, :touch, :assisting, :gates_open)

    # Manhattan distance beyond which find_path first checks the target against the reachability flood.
    FLOOD_MIN = 24

    @pcache = {}
    @pcache_state = nil
    @context = nil

    # The search operation in progress, or nil between searches.
    def self.context; @context; end

    # Runs a block inside the search operation in progress, opening one when none is and closing it after,
    # whatever happens. The block gets the operation.
    def self.in_context
      return yield(@context) if @context
      @context = SearchContext.new(nil, 0)
      begin
        yield(@context)
      ensure
        @context = nil
      end
    end

    # The frame every search runs in: one time budget, the player's bridge level put back afterwards, and
    # the terrain asked once per tile.
    def self.searching
      with_budget { with_level_kept { PokeAccess::Terrain.memoizing(held_terrain) { yield } } }
    end

    # Runs a block under one deadline for everything inside it: a nested call keeps the outer deadline, and the
    # previous value is always restored.
    def self.with_budget
      in_context do |c|
        outer = c.deadline
        c.deadline = outer || fresh_deadline
        begin
          yield
        ensure
          c.deadline = outer
        end
      end
    end

    # How often, in expanded nodes, a time-budgeted search checks the clock (a power of two: it is used as a mask).
    BUDGET_CHECK = 256

    # The deadline (a clock value) the searches of the current operation share, or nil with route_auto off, when
    # astar_max bounds them by node count instead.
    def self.search_deadline
      c = @context
      (c && c.deadline) || fresh_deadline
    end

    # A brand-new deadline, ignoring any in scope. Only with_budget and search_deadline should call this.
    def self.fresh_deadline
      return nil unless (PokeAccess::Config.route_auto rescue false)
      ms = (PokeAccess::Config.route_budget_ms rescue 8).to_i
      (PokeAccess.clock rescue 0.0) + (ms / 1000.0)
    end

    # True once a search must stop: in time mode when the deadline passed (checked every BUDGET_CHECK nodes),
    # otherwise when the node count exceeds astar_max. Each stop is counted (cuts).
    def self.over_budget?(iter, deadline)
      cut = if deadline
              (iter & (BUDGET_CHECK - 1)) == 0 && (PokeAccess.clock rescue 0.0) > deadline
            else
              iter > PokeAccess::Config.astar_max
            end
      note_cut if cut
      cut
    end

    # How many searches have stopped short (budget, node cap, target beyond reach); compared before and after a
    # search, it tells a route not found from one not searched to the end.
    def self.cuts; @cuts.to_i; end

    # Counts a search stopped short (see cuts); nil, for the search to answer with.
    def self.note_cut
      @cuts = @cuts.to_i + 1
      nil
    end

    # Runs a search that may move the engine's bridge level, restoring the player's own afterwards whatever happens;
    # nested calls share the outer one, and searching? is true inside.
    def self.with_level_kept
      in_context do |c|
        c.depth += 1
        begin
          next yield if c.depth > 1
          hold_passability_to_map if @plain_passability
          sync_event_memo
          c.vehicle = vehicle_state
          c.touch = nil
          begin
            c.levels_live = ramp_map?
            was = PokeAccess::Terrain.bridge_height
            c.level = was
            yield
          ensure
            set_bridge(was) if c.levels_live
            c.levels_live = false
            c.vehicle = nil
            c.level = nil
            c.touch = nil
          end
        ensure
          c.depth -= 1
        end
      end
    end

    # True while a search is asking the engine about tiles, for a game whose passability check does more
    # than answer (plays a sound, sets a switch) and has to be kept quiet meanwhile.
    def self.searching?
      c = @context
      c ? c.depth > 0 : false
    end

    # The bridge level the player is on (0 off every bridge): inside a search, the one it started from, whatever level
    # the search has since pointed the engine at.
    def self.bridge_level
      c = @context
      (c && c.level) || PokeAccess::Terrain.bridge_height
    end

    # Points the engine at a bridge level for the passability questions about to be asked. Only a map with a
    # ramp is ever touched; with_level_kept puts the player's own level back.
    def self.use_level(lvl)
      c = @context
      set_bridge(lvl) if c && c.levels_live
    end

    # Sets the engine's bridge height, wherever the engine keeps it (Terrain.bridge_holder).
    def self.set_bridge(lvl)
      h = PokeAccess::Terrain.bridge_holder
      h.bridge = lvl if h
    rescue StandardError
      nil
    end

    # The vehicle state the event indexes are looked up under: the one the running search started with, else the live.
    def self.index_vehicle
      c = @context
      (c && c.vehicle) || vehicle_state
    end

    # Passability of a step from (cx,cy) in direction d, memoised per map, vehicle and bridge level with route_cache;
    # not memoised with the obstacles set aside (with_gates_open) or partway up a side staircase, nor a refused step
    # into the player's own tile (see into_player?).
    def self.passable_at?(cx, cy, d)
      c = @context
      return player_passable?(cx, cy, d) if (c && c.gates_open) || !(PokeAccess::Config.route_cache rescue false) || on_stair?
      st = index_vehicle
      if @pcache_state != st; @pcache_state = st; @pcache = {}; end
      k = memo_key(cx, cy, d, PokeAccess::Terrain.bridge_height > 0 ? 1 : 0)
      v = @pcache[k]
      return v unless v.nil?
      v = player_passable?(cx, cy, d)
      return v if !v && into_player?(cx, cy, d)
      @pcache[k] = v
    rescue StandardError
      player_passable?(cx, cy, d)
    end

    # True if a step from (x,y) in direction d ends on the tile the player stands on, which every engine refuses the
    # player while they stand there: an answer that stops holding once they move.
    def self.into_player?(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      pl = $game_player
      !dd.nil? && !pl.nil? && x + dd[0] == pl.x && y + dd[1] == pl.y
    end

    # The engine's player passability, asked with the player's through flag off (a scripted move turns it on); the
    # flag is put back at once.
    def self.player_passable?(x, y, d)
      pl = $game_player
      return false if pl.nil?
      was = (pl.through rescue false)
      return (pl.passable?(x, y, d) ? true : false) unless was
      begin
        pl.through = false
        pl.passable?(x, y, d) ? true : false
      ensure
        pl.through = was
      end
    rescue StandardError
      false
    end

    # True while the player stands partway up a side staircase (Marin's plugin and its v17 cousin), where the plugin
    # answers every passability question from the player's place on the stair.
    def self.on_stair?
      pl = $game_player
      return (pl.on_middle_of_stair? ? true : false) if pl.respond_to?(:on_middle_of_stair?)
      pl.respond_to?(:on_stair?) && pl.on_stair? ? true : false
    rescue StandardError
      false
    end

    # The passability memo's key for a step from (x,y) in direction d on bridge level b (0 or 1).
    def self.memo_key(x, y, d, b); (pkey(x, y) * 16 + d) * 2 + b; end

    # The key the passability memo and the event indexes are kept under: the map and whether the player surfs, dives
    # or rides the bike, packed in one Integer.
    def self.vehicle_state
      ($game_map.map_id rescue 0).to_i * 8 + (($PokemonGlobal.surfing rescue false) ? 4 : 0) +
        (($PokemonGlobal.diving rescue false) ? 2 : 0) + (($PokemonGlobal.bicycle rescue false) ? 1 : 0)
    end

    # Drops the memo's steps into every tile of each event changed, come or gone since the last search (event_state);
    # a page turn on an action-button or touch event, or one come or gone, also drops the event indexes.
    def self.sync_event_memo
      snap = {}
      ($game_map.events.values rescue []).each { |e| snap[e.id] = event_state(e) }
      old = @event_snap
      @event_snap = snap
      return if old.nil? || @event_snap_map != ($game_map.map_id rescue 0)
      ids = {}
      old.each_key { |id| ids[id] = true }
      snap.each_key { |id| ids[id] = true }
      ids.each_key do |id|
        was = old[id]; now = snap[id]
        next if was == now
        [was, now].each { |st| state_tiles(st).each { |x, y| forget_steps_into(x, y) } if st }
        next unless [was, now].any? { |st| st && (st[5] == 0 || st[5] == 1 || st[5] == 2) }
        forget_event_indexes if was.nil? || now.nil? || was[4] != now[4]
      end
    rescue StandardError
      nil
    ensure
      @event_snap_map = ($game_map.map_id rescue 0)
    end

    # What sync_event_memo compares of an event: place, through, sprite, page, trigger, tile graphic, and the size the
    # engine keeps with the name it may read one from.
    def self.event_state(e)
      [e.x, e.y, (e.through rescue false), e.character_name.to_s, PokeAccess.ivar(e, :@page).__id__,
       PokeAccess.ivar(e, :@trigger), (e.tile_id rescue nil), PokeAccess.ivar(e, :@width), PokeAccess.ivar(e, :@height),
       (e.name rescue nil)]
    end

    # The tiles an event state from event_state covers, by the same rule as event_tiles.
    def self.state_tiles(st)
      tiles_of(st[0], st[1], st[7], st[8]) { st[9] }
    end

    # A per-map index of what events do to a route, by name: built by the block (given the map id) once per vehicle
    # state and kept until forget_event_indexes; fallback is what a failed build leaves.
    def self.event_index(name, fallback = {})
      key = index_vehicle
      @event_indexes ||= {}
      hit = @event_indexes[name]
      return hit[1] if hit && hit[0] == key
      idx = begin
        yield(($game_map.map_id rescue 0))
      rescue StandardError
        fallback
      end
      @event_indexes[name] = [key, idx]
      idx
    end

    # Drops every per-map index of what events do to a route, to be rebuilt from their pages as they stand,
    # and counts the change (see event_epoch).
    def self.forget_event_indexes
      @event_indexes = {}
      @context.touch = nil if @context
      @event_turns = @event_turns.to_i + 1
    end

    # What the event indexes stand for: the vehicle state they were built under and how many times a page
    # that matters has turned. A route planned under another is checked again before it is trusted.
    def self.event_epoch
      [vehicle_state, @event_turns.to_i]
    end

    # Forgets every memoised step into and out of (x,y), on both bridge levels.
    def self.forget_steps_into(x, y)
      return if @pcache.nil? || @pcache.empty?
      DIRS.each do |dx, dy, d|
        [0, 1].each do |b|
          @pcache.delete(memo_key(x - dx, y - dy, d, b))
          @pcache.delete(memo_key(x, y, d, b))
        end
      end
    end

    # Drops the passability memo, the flood and water caches, the HPA* graph, the event indexes and the terrain memo;
    # at most once every 2 seconds (a cutscene ends many events in a row) unless force. With plain_passability the
    # search memos go only with force, as every search holds them to the map (hold_passability_to_map).
    def self.invalidate_cache(force = false)
      now = (PokeAccess.clock rescue 0)
      return if !force && @last_invalidate && (now - @last_invalidate) < 2.0
      @last_invalidate = now
      forget_passability if force || !@plain_passability
      @rs_key = nil
      @hpa = nil
      @hpa_sig = nil
      @surf_key = nil
      @surf_route = nil
      @amph_key = nil
      forget_event_indexes
      PokeAccess::Terrain.forget_map_memo
    end

    # Declares that the game's player passability reads nothing an event can change but the map's tiles, tileset and
    # events (checked against its scripts): the search memos then outlive an event's end, held to the map instead.
    def self.plain_passability
      @plain_passability = true
    end

    # Drops the passability memo, the searches' terrain memo and the map fingerprint they were held to.
    def self.forget_passability
      @pcache = {}
      @pcache_state = nil
      @held_terrain = nil
      @memo_print = nil
    end

    # The terrain memo the searches share while their memos are held to the map (plain_passability, route_cache on),
    # kept and dropped with the passability memo; nil otherwise, which leaves them the map's own.
    def self.held_terrain
      return nil unless @plain_passability && (PokeAccess::Config.route_cache rescue false)
      @held_terrain ||= {}
    end

    # Keeps the passability and search terrain memos only while the map's tiles and tileset are the ones they were
    # filled under (the events are sync_event_memo's); runs as a search starts, the only time they are filled or read.
    def self.hold_passability_to_map
      stamp = map_fingerprint
      forget_passability if stamp.nil? || stamp != @memo_print
      @memo_print = stamp
    end

    # The map id, tile layers and tileset tables, dumped whole, or nil when they cannot be.
    def self.map_fingerprint
      m = $game_map
      [m.map_id, Marshal.dump(m.data), Marshal.dump(m.passages), Marshal.dump(m.priorities), Marshal.dump(m.terrain_tags)]
    rescue StandardError
      nil
    end

    # The farthest a target can be, in Manhattan tiles, for find_path and the flood to consider it (route_reach).
    def self.reach; (PokeAccess::Config.route_reach rescue 128).to_i; end

    # A route to a tile beside the target, with ledge hops only when no walking route exists; a one-sided doorway is
    # reached on the tile it is walked into from.
    def self.find_path(tx, ty)
      searching do
        approach = door_approaches(tx, ty)
        next approach_path(approach) if approach
        px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
        dist = (px - tx).abs + (py - ty).abs
        next note_cut if dist > reach
        next nil if dist > FLOOD_MIN && blocked_target?(tx, ty)
        find_path_to(tx, ty, false) || find_path_to(tx, ty, true)
      end
    end

    # A route that ends on (tx,ty) rather than beside it: a shore to push off from, a spot to dive at.
    def self.find_path_onto(tx, ty)
      searching do
        next [] if tx == ($game_player.x rescue nil) && ty == ($game_player.y rescue nil)
        find_path_to(tx, ty, false, true) || find_path_to(tx, ty, true, true)
      end
    end

    # The tiles a one-sided doorway at (tx,ty) is walked into from, nearest the player first; nil for any other.
    def self.door_approaches(tx, ty)
      fs = door_facings(tx, ty)
      return nil if fs.nil?
      px = ($game_player.x rescue 0); py = ($game_player.y rescue 0)
      tiles = fs.map { |f| [tx - PokeAccess::DIR_DELTA[f][0], ty - PokeAccess::DIR_DELTA[f][1]] }
      tiles.sort_by { |x, y| (x - px).abs + (y - py).abs }
    end

    # The first route onto one of the approach tiles, [] when the player already stands on one.
    def self.approach_path(tiles)
      here = [($game_player.x rescue nil), ($game_player.y rescue nil)]
      return [] if tiles.include?(here)
      tiles.each do |x, y|
        p = find_path_to(x, y, false, true) || find_path_to(x, y, true, true)
        return p if p
      end
      nil
    end

    # Packs a search state -- a tile and whether the bridge is up -- into one key: on a bridge map the same
    # tile is a floor on one level and a wall on the other, and the search must keep the two apart.
    def self.skey(x, y, lvl); pkey(x, y) * 2 + (lvl.to_i > 0 ? 1 : 0); end

    # Offsets within manhattan distance 2 of a tile (matches find_path_to's "get within 2" partial route).
    NEAR2 = [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1],
             [2, 0], [-2, 0], [0, 2], [0, -2], [1, 1], [1, -1], [-1, 1], [-1, -1]]

    # True if the target is clearly unreachable: nothing within 2 tiles of it is in the cached flood. Never with
    # edge_relax on or a truncated or missing flood.
    def self.blocked_target?(tx, ty)
      return false if (PokeAccess::Config.edge_relax rescue false)
      s = reachable_set
      return false if s.nil? || s.empty?
      return false unless @rs_full
      !NEAR2.any? { |dx, dy| s[pkey(tx + dx, ty + dy)] }
    rescue StandardError
      false
    end
  end
end

# Drops the route caches on a map change, bypassing the invalidation throttle.
PokeAccess::Caches.register(:pathfinder) { PokeAccess::Pathfinder.invalidate_cache(true) }
