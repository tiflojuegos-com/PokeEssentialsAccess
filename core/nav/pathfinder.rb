module PokeAccess
  # The pathfinder's frame: the search operation (its Routes::Limits and the bridge level) and the route caches and
  # their keys. The route policies live in Routes::Planner, the search in Routes::Search, over the moves of
  # Routes::Moves; what the player can get to in Routes::Regions, the flood in Routes::Flood, the algorithms and the
  # heap in route_search, JPS in Routes::Jumps, HPA* in route_grid, what assisted routes share in route_gates (the
  # boulders they move in Routes::Pushes), across water in route_water, the spoken route in Routes::Text.
  module Pathfinder
    # A route's key presses, with the transfers to another spot of the map it goes through: how many (rooms, 0 unset)
    # and the presses, by index and in order, after which they land (warps).
    class Route < Array
      attr_writer :rooms, :warps
      def rooms; @rooms || 0; end
      def warps; @warps || []; end
    end

    # What one search operation carries, shared by its nested searches and dropped with the outermost: its budget
    # (Routes::Limits), the nesting depth, the player's starting bridge level, whether bridge levels are live, and
    # whether it is assisted (see route_gates).
    SearchContext = Struct.new(:limits, :depth, :level, :levels_live, :assisting)

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

    # The frame every search runs in: one budget and the player's bridge level put back afterwards. The block gets the
    # budget.
    def self.searching
      with_limits { |l| with_level_kept { yield l } }
    end

    # Runs a block under one budget for everything inside it, opened by the outermost call and kept by nested ones,
    # whatever happens. The block gets the budget.
    def self.with_limits
      in_context do |c|
        outer = c.limits
        c.limits = outer || Routes::Limits.from_config
        begin
          yield c.limits
        ensure
          c.limits = outer
        end
      end
    end

    # The budget of the operation in progress, or a fresh one outside any.
    def self.limits
      c = @context
      (c && c.limits) || Routes::Limits.from_config
    end

    # Runs a search that may move the engine's bridge level, restoring the player's own afterwards whatever happens;
    # the outermost opens the probe's session, the world brought level once for the whole search. Nested calls share
    # the outer one.
    def self.with_level_kept
      in_context do |c|
        c.depth += 1
        begin
          next yield if c.depth > 1
          PokeAccess::World::Probe.session do
            begin
              c.levels_live = Routes::Effects.ramp_map?
              was = PokeAccess::World::Engine.bridge_height
              c.level = was
              yield
            ensure
              PokeAccess::World::Engine.set_bridge(was) if c.levels_live
              c.levels_live = false
              c.level = nil
            end
          end
        ensure
          c.depth -= 1
        end
      end
    end

    # The bridge level the player is on (0 off every bridge): inside a search, the one it started from, whatever level
    # the search has since pointed the engine at.
    def self.bridge_level
      c = @context
      (c && c.level) || PokeAccess::World::Engine.bridge_height
    end

    # Points the engine at a bridge level for the passability questions about to be asked. Only a map with a
    # ramp is ever touched; with_level_kept puts the player's own level back.
    def self.use_level(lvl)
      c = @context
      PokeAccess::World::Engine.set_bridge(lvl) if c && c.levels_live
    end

    # The mode of Routes::Moves a search or a replay takes now: ledge hops when asked, a passable border tile as a step
    # with relax, and the assisted steps inside an assisted search (with_gates_open).
    def self.moves_mode(ledge, relax)
      mode = ledge ? Routes::Moves::LEDGE : 0
      mode |= Routes::Moves::RELAX if relax
      mode |= Routes::Moves::ASSIST if @context && @context.assisting
      mode
    end

    # The mode a route is replayed and checked with (Routes::Moves.trace and ok?): ledge hops, and the border tiles
    # with edge_relax, as the search allowed them.
    def self.replay_mode
      moves_mode(true, (PokeAccess::Config.edge_relax rescue false))
    end

    # The map, the probe's mode (the vehicle and what the game declares its passability reads) and what the party may
    # do on water: what the regions and the HPA* graph are kept under and the route epoch names.
    def self.vehicle_state
      [($game_map.map_id rescue 0).to_i, PokeAccess::World::Probe.signature, water_moves]
    end

    # Whether the party may surf and climb waterfalls (FieldMoves.can?), read once a frame: teaching either changes
    # the ways by water.
    def self.water_moves
      f = PokeAccess::World::Epoch.frame
      return @water_moves[1] if @water_moves && @water_moves[0] == f
      v = [PokeAccess::FieldMoves.can?(:SURF), PokeAccess::FieldMoves.can?(:WATERFALL)]
      @water_moves = [f, v]
      v
    end

    # Forgets what the party may do on water, read afresh at the next question even within the frame (a full reset).
    def self.forget_water_moves; @water_moves = nil; end

    # What the routes' reading of the events stands for: the vehicle, how often a page that matters turned (or what a
    # facet read changed), and how many events have ended. A route planned under another is checked again before it
    # is trusted.
    def self.event_epoch
      [vehicle_state, PokeAccess::World::Events.turns, @event_ends.to_i]
    end

    # At an event's end, or with force: drops the floods, ends the volatile event facets' lease and has the world
    # compare the tiles, or forget everything with force; the probe's answers, the regions and the HPA* graph go too,
    # but with a plain passability (World::Probe.plain?) only with force or a tiles change.
    def self.invalidate_cache(force = false)
      if force || !PokeAccess::World::Probe.plain?
        PokeAccess::World::Probe.forget
        Routes::Regions.forget
        hpa_forget
      end
      Routes::Flood.forget
      @event_ends = @event_ends.to_i + 1
      PokeAccess::World::Flags.event_ended!
      force ? PokeAccess::World.reset! : PokeAccess::World::Epoch.tiles_due!
    end

    # The farthest a target can be, in Manhattan tiles, for a route to be searched (route_reach).
    def self.reach; (PokeAccess::Config.route_reach rescue 128).to_i; end

    # Packs a search state -- a tile and whether the bridge is up -- into one key: on a bridge map the same
    # tile is a floor on one level and a wall on the other, and the search must keep the two apart.
    def self.skey(x, y, lvl); Routes.pkey(x, y) * 2 + (lvl.to_i > 0 ? 1 : 0); end

    # The tiles (tx,ty) is acted on from, as the game allows it: each tile the event standing there covers (area_at),
    # the four beside each, and the tile across each counter beside one; its own tiles alone for an event the engine
    # starts only with the player on it (underfoot?).
    def self.reach_tiles(tx, ty)
      area = area_at(tx, ty)
      return area if underfoot?(tx, ty)
      out = []
      area.each do |ax, ay|
        out.push([ax, ay])
        Routes::DIRS.each do |dx, dy, _d|
          out.push([ax + dx, ay + dy])
          out.push([ax + 2 * dx, ay + 2 * dy]) if ($game_map.counter?(ax + dx, ay + dy) rescue false)
        end
      end
      out.uniq
    end

    # True when the event on (tx,ty) is an action-button one that fires on arrival (Routes::Effects.fires_on_arrival?:
    # no sprite, on ground anyone stands on), which the engine's check_event_trigger_there skips from beside it.
    def self.underfoot?(tx, ty)
      ev = PokeAccess::Control.event_at(tx, ty)
      !ev.nil? && PokeAccess.ivar(ev, :@trigger) == 0 && Routes::Effects.fires_on_arrival?(ev)
    end

    # The tiles of the widest event standing on (tx,ty), as the game reaches it from any of them (its size(w,h) area,
    # World::Events); the tile alone where none spans more.
    def self.area_at(tx, ty)
      big = PokeAccess::World::Events.anchored(tx, ty).map { |r| r.tiles }.max_by { |t| t.length }
      big && big.length > 1 ? big : [[tx, ty]]
    rescue StandardError => e
      PokeAccess.swallowed(e)
      [[tx, ty]]
    end
  end
end

PokeAccess::World::Epoch.on(:reset) { PokeAccess::Pathfinder.forget_water_moves }

# Drops the route caches on a map change, bypassing the invalidation throttle.
PokeAccess::Caches.register(:pathfinder) { PokeAccess::Pathfinder.invalidate_cache(true) }
