module PokeAccess
  module Routes
    # The free camera's trail (Camera) as the player's presses: each camera step taken as the game plays its press, a
    # ledge or ice covering several trail tiles with one; what the player cannot or should not take (the routes' own
    # rules) gone round by the shortest way to the next trail tile they can stop on, else the trail cut there.
    module Trail
      # How many trail tiles past a stretch the player cannot take are tried as where a way round rejoins it.
      REJOIN_TRIES = 3

      # A stretch not taken as the camera went: at, the trail index it starts from; to, where the way round rejoins
      # (nil when cut there); kind, :detour or why it is cut (:blocked, :exit, :warp, :carried, :company, or :cut where
      # the search ran out of budget); presses, the way round's.
      Break = Struct.new(:at, :to, :kind, :presses)

      # A trail as presses: the route, its stretches not taken as the camera went, the trail index it reaches, the state
      # [x, y, level] it ends in, and surf, the way to push off onto water where it stops on a shore, or nil.
      Conversion = Struct.new(:route, :breaks, :reached, :state, :surf)

      # The direction code of the step from tile a to the tile b beside it.
      def self.dir_between(a, b)
        dx = b[0] - a[0]
        dy = b[1] - a[1]
        dx < 0 ? 4 : (dx > 0 ? 6 : (dy < 0 ? 8 : 2))
      end

      # The index of the trail tile (each [x, y, level], level 0 when left out) the state st [x, y, level] stands on, or
      # nil; on a bridge or not, whatever ramp step set the level.
      def self.index_of(tiles, st)
        tiles.index { |t| t[0] == st[0] && t[1] == st[1] && (t[2].to_i > 0) == (st[2].to_i > 0) }
      end

      # The trail tiles (each [x, y, level], none twice, each beside the last) as presses from state from [x, y, level]
      # on the first of them, with the replay's moves (Pathfinder.replay_mode), in one search operation: one budget and
      # one deadline for every way round, as for any route.
      def self.convert(tiles, from)
        PokeAccess::Pathfinder.searching { converted(tiles, from) }
      end

      # The conversion of convert, inside its search operation.
      def self.converted(tiles, from)
        index = {}
        tiles.each_with_index { |t, i| index[PokeAccess::Pathfinder.skey(t[0], t[1], t[2].to_i)] = i }
        route = PokeAccess::Pathfinder::Route.new
        breaks = []
        s = from
        i = 0
        surf = nil
        while i < tiles.length - 1
          d = dir_between(tiles[i], tiles[i + 1])
          st = Moves.try(s[0], s[1], s[2], d, mode)
          j = st && landing(tiles, index, i, st, d)
          if j
            st.presses.times { route.push(d) }
            s = [st.x, st.y, st.level]
            i = j
            next
          end
          launch = st.nil? ? launch_of(s, d, tiles[i + 1]) : nil
          if launch == :surf
            surf = d
            break
          end
          k, way, ends, cut = launch ? [nil, nil, nil, false] : rejoin(tiles, i, s)
          unless k
            breaks.push(Break.new(i, nil, launch || (cut ? :cut : why(s, d, st)), 0))
            break
          end
          breaks.push(Break.new(i, k, :detour, way.length))
          route.append(way)
          s = ends
          i = k
        end
        Conversion.new(route, breaks, i, s, surf)
      end

      # The moves a trail is taken with: the replay's, as the guides check a route.
      def self.mode
        PokeAccess::Pathfinder.replay_mode
      end

      # The trail index a move st pressed from trail tile i toward d lands on, where it lands further along the trail in
      # a straight line from i, a teleport aside; nil elsewhere.
      def self.landing(tiles, index, i, st, d)
        return nil if st.warp
        j = index[PokeAccess::Pathfinder.skey(st.x, st.y, st.level)]
        return nil unless j && j > i
        dd = PokeAccess::DIR_DELTA[d]
        (i..j).all? { |k| tiles[k][0] == tiles[i][0] + dd[0] * (k - i) && tiles[k][1] == tiles[i][1] + dd[1] * (k - i) } ? j : nil
      end

      # How the trail goes on from state s toward d onto the water tile next on it: :surf where the player may push off
      # from s (Pathfinder.may_surf?: afloat, once the trail has come ashore; the push open), :company where the game
      # bars surfing with whoever walks along, else nil.
      def self.launch_of(s, d, tile)
        return nil unless PokeAccess::World::Terrain.water?(tile[0], tile[1])
        return nil unless PokeAccess::Pathfinder.may_surf?(s[0], s[1])
        w = Moves.try(s[0], s[1], s[2], d, mode | Moves::SURF_PLAN)
        return nil unless w && w.kind == :surf
        PokeAccess::Pathfinder.surf_with_company? ? :surf : :company
      end

      # A way round from state s, stopped at trail index i, to one of the next REJOIN_TRIES trail tiles past i the player
      # could stop on: [its index, the way, the state it ends in, false]; with none, [nil, nil, nil, whether the search
      # ran out of budget]. A tile the regions already rule out (as walked so far, nothing walked now) is skipped with no
      # search; a search that runs out of ways settles the rest too, as it went through all the player can get to from s,
      # and one cut short by the budget ends the tries.
      def self.rejoin(tiles, i, s)
        tries = 0
        k = i + 1
        while k < tiles.length && tries < REJOIN_TRIES
          t = tiles[k]
          if stop?(t[0], t[1]) && !Planner.unreachable?(Goal.onto(t[0], t[1]))
            tries += 1
            r = Search.fresh(Goal.onto(t[0], t[1]), mode, s)
            return [nil, nil, nil, r.status == :cut] unless r.status == :found
            ends = Moves.trace(s[0], s[1], s[2], r.route, mode).last
            return [k, r.route, [ends.x, ends.y, ends.level], false] if ends && ends.x == t[0] && ends.y == t[1]
          end
          k += 1
        end
        [nil, nil, nil, false]
      end

      # Whether the player could come to a stop on (x, y): a step into it is open, and it is no ice slid over nor a ledge
      # hopped.
      def self.stop?(x, y)
        t = PokeAccess::World::Terrain
        return false if t.ice?(x, y) || t.ledge?(x, y)
        PokeAccess::Sound::Scene.standable?(nil, nil, x, y)
      end

      # Why the press from state s toward d is not taken as the camera went: a teleport or a carry off the trail, an exit
      # or barrier, else what stops a step.
      def self.why(s, d, st)
        return :exit if st && st.kind == :exit
        return(st.warp || st.kind == :warp ? :warp : :carried) if st
        dd = PokeAccess::DIR_DELTA[d]
        e = (Effects.touch_at(s[0] + dd[0], s[1] + dd[1], d, true) rescue nil)
        e && (e[0] == :exit || e[0] == :barrier) ? :exit : :blocked
      end

      # The way along trail tiles for the guides, from the player's state, and the progress it leaves (the farthest
      # trail index the player has stood on; nil until they stand on its first tile): until then, the way to that first
      # tile, where the trail starts; after, from the player's tile when they stand on the trail, else the best way to the
      # trail tile from the progress on that lies nearest them on foot (nearest_ahead) and along the trail from there. A
      # way to that tile that is no plain walk (assisted, by water, none) is the plan as it is. Kept (Planner.kept) under
      # id, the trail's.
      def self.plan(tiles, progress, id)
        st = PokeAccess::Guide.player_state
        on = index_of(tiles, st)
        progress = 0 if progress.nil? && on == 0
        if progress.nil?
          return [Planner.kept([:trail, id, :join, 0]) { make_join(tiles, 0, st) }, nil]
        end
        progress = on if on && on > progress
        made = if on
                 Planner.kept([:trail, id, :on, on]) { joined(nil, convert(tiles[on..-1], st), on) }
               else
                 k = nearest_ahead(tiles, progress)
                 Planner.kept([:trail, id, :join, k]) { make_join(tiles, k, st) }
               end
        [made, progress]
      end

      # The trail index from progress on whose tile lies the fewest presses from the player on foot, as the regions
      # count them (Regions#presses_to; the first of the nearest); progress itself, the last trail tile they stood on,
      # while the regions reach none.
      def self.nearest_ahead(tiles, progress)
        reg = Regions.foot
        best = progress
        far = nil
        (progress...tiles.length).each do |k|
          w = reg.presses_to([[tiles[k][0], tiles[k][1]]])
          next if w.nil? || (far && w >= far)
          far = w
          best = k
        end
        best
      end

      # The plan from the player's state st off the trail: the best way onto trail tile k, then the trail from there.
      def self.make_join(tiles, k, st)
        start = tiles[k]
        join = Planner.plan(start[0], start[1], true)
        return join unless join.kind == :walk && join.route
        ends = Moves.trace(st[0], st[1], st[2], join.route, mode).last
        from = ends ? [ends.x, ends.y, ends.level] : st
        joined(join.route, convert(tiles[k..-1], from), k)
      end

      # A plan of the way to the trail (head, or nil) and the trail converted from it (conv), whose first tile is trail
      # index offset: a walk, or a surf that stops on the shore to push off; its stats tell the trail index reached, why
      # it is cut (nil for not), how many stretches are gone round, and, for a way round that ran out of budget, that it
      # is not to be kept (:cut_short).
      def self.joined(head, conv, offset)
        route = PokeAccess::Pathfinder::Route.new
        route.append(head) if head
        route.append(conv.route)
        cut = conv.breaks.reverse.detect { |b| b.to.nil? }
        stats = { :trail_reached => offset + conv.reached, :trail_cut => cut && cut.kind,
                  :trail_detours => conv.breaks.select { |b| b.kind == :detour }.length,
                  :cut_short => !cut.nil? && cut.kind == :cut }
        return Plan.new(:surf, route, nil, stats, conv.surf) if conv.surf
        Plan.new(:walk, route, nil, stats)
      end
    end
  end
end
