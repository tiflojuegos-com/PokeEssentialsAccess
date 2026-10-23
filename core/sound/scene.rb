module PokeAccess
  module Sound
    # What sounds around the player, read on a tile change: the nearest emitters of each kind (events, marks and edge
    # exits within the sonar's range, behind walls dropped in hide mode), the nearest water, afloat the nearest shore,
    # and the distance to a wall on each side. The emitters are read again when an event that walks changes tile near
    # the player, or one comes, goes or changes near them (moved?).
    module Scene
      RANGE = 12
      WALL_RANGE = 3
      # Tiles past the farthest a sound is placed over which a source fades out (Scheduler.reach, the engine's silence).
      FADE = 2
      # Nearest emitters kept per kind.
      NEAR_MAX = 3

      @emitters = {}
      @wall = {}
      @water = nil
      @shore = nil
      @watch = []
      @stirred = false
      @rings = {}

      # The emitters by kind, as [[x, y], ...] nearest first; the distance to a wall on each side of the wind's
      # (Catalog side), nil when open; the nearest water tile and, afloat, the nearest shore tile, nil when none.
      def self.emitters; @emitters; end
      def self.walls; @wall; end
      def self.water; @water; end
      def self.shore; @shore; end

      # The events that walk, where the last scan found them: [[event, x, y], ...].
      def self.watched; @watch; end

      # Drops everything read for the map.
      def self.forget
        @emitters = {}
        @wall = {}
        @water = nil
        @shore = nil
        @watch = []
        @stirred = false
      end

      # The sonar's range in tiles.
      def self.range; (PokeAccess::Config.audio3d_range rescue RANGE).to_i; end

      # How far a wall is felt, in tiles.
      def self.wall_range; (PokeAccess::Config.audio3d_wall_range rescue WALL_RANGE).to_i; end

      # What becomes of an emitter behind a wall: :hear, :occlude (muffled) or :hide (dropped).
      def self.occlusion_mode; (PokeAccess::Config.audio3d_occlusion rescue :hide); end

      # The sound an event pings with, or nil when it does not ping: a tag override first, then the puzzle piece it is
      # (World::Mechanics), a rock to push, and the locator's kinds; a lever, a person or an object needs a graphic and
      # to be interactable, and a lever pings as a control.
      def self.family_of(ev)
        return nil if (PokeAccess::Locator.hidden?(ev) rescue false)
        ov = (PokeAccess::Locator.tag_override(ev) rescue nil)
        if ov
          return :door if ov == :exits
          return :npc if ov == :people
          return :object if ov == :objects
          return nil
        end
        piece = (PokeAccess::World::Mechanics.piece_of(ev) rescue nil)
        return (piece.moving ? :trap : :hazard) if piece && piece.role == :obstacle
        return :control if piece && piece.role == :control
        return :hazard if (PokeAccess::Locator.hazard?(ev) rescue false)
        return :push if rock?(ev)
        return :belt if (PokeAccess::Locator.push_tile?(ev) rescue false)
        return :teleporter if (PokeAccess::Locator.teleporter_event?(ev) rescue false)
        return :door if (PokeAccess::Locator.transfer_event?(ev) rescue false)
        return nil unless (PokeAccess::Locator.has_graphic?(ev) rescue false)
        return nil unless (PokeAccess::Locator.interactable?(ev) rescue true)
        return nil unless reachable_by_keys?(ev)
        return :control if (PokeAccess::Locator.lever?(ev) rescue false)
        ((PokeAccess::Locator.event_category(ev) rescue :objects) == :people) ? :npc : :object
      end

      # Whether the player can push the event, a boulder (the routes' :push facet, Routes::Effects).
      def self.rock?(ev)
        r = PokeAccess::World::Events.record_of(ev)
        r ? !PokeAccess::World::Events.facet(r, :push).nil? : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Whether the event passes the optional sonar_only_locatable filter (only what the locator keys reach); asked
      # last, so it can only drop a plain person or object.
      def self.reachable_by_keys?(ev)
        return true unless (PokeAccess::Config.sonar_only_locatable rescue false)
        (PokeAccess::Locator.in_category?(ev, :all) rescue true)
      end

      # How many events on this map ping and how many of them the locator keys cannot reach, the filter off.
      def self.census
        return "sin mapa" unless $game_map
        pings = 0
        gap = 0
        $game_map.events.values.each do |ev|
          next if unfiltered(ev).nil?
          pings += 1
          gap += 1 unless (PokeAccess::Locator.in_category?(ev, :all) rescue true)
        end
        "#{pings} pingan, #{gap} fuera del localizador"
      rescue StandardError => e
        PokeAccess.swallowed(e)
        "?"
      end

      # family_of as if the filter were off, for the census.
      def self.unfiltered(ev)
        prev = (PokeAccess::Config.sonar_only_locatable rescue false)
        PokeAccess::Config.sonar_only_locatable = false
        family_of(ev)
      ensure
        (PokeAccess::Config.sonar_only_locatable = prev rescue nil)
      end

      # True if the player can step from (x,y) toward d, as the routes read it (World::Probe), an engine error counting
      # as open.
      def self.step_open?(x, y, d)
        PokeAccess::World::Probe.step?(x, y, d, true)
      end

      # True if no wall blocks a straight-ish walk from (x0, y0) to (x1, y1), stepping along the axis with more distance
      # left (a ray, not a path search); the step into the emitter's own tile is not asked; errors read as clear.
      def self.line_clear?(x0, y0, x1, y1)
        x = x0; y = y0; guard = 0
        until x == x1 && y == y1
          guard += 1
          break if guard > 48
          dx = x1 - x; dy = y1 - y
          if dx.abs >= dy.abs && dx != 0
            d = (dx > 0) ? 6 : 4; nx = x + ((dx > 0) ? 1 : -1); ny = y
          elsif dy != 0
            d = (dy > 0) ? 2 : 8; nx = x; ny = y + ((dy > 0) ? 1 : -1)
          else
            break
          end
          break if nx == x1 && ny == y1
          return false unless step_open?(x, y, d)
          x = nx; y = ny
        end
        true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        true
      end

      # Merges emitter tiles that touch (8-connected) and share a sprite into their tile nearest the player, so a
      # structure of several tiles pings once.
      def self.cluster(list)
        n = list.length
        return list if n <= 1
        groups = PokeAccess::Util.union_groups(n) do |i, j|
          (list[i][0] - list[j][0]).abs <= 1 && (list[i][1] - list[j][1]).abs <= 1 && list[i][3] == list[j][3]
        end
        groups.map { |idxs| idxs.map { |i| list[i] }.min_by { |e| e[2] } }
      end

      # Whether a service desk within audio3d_desk_range tiles (0 = off) is heard through a wall in hide mode.
      def self.desk_bypass?(ev, d)
        dk = (PokeAccess::Config.audio3d_desk_range rescue 2).to_i
        return false if dk <= 0 || d > dk
        (PokeAccess::Locator.service_desk?(ev) rescue false)
      end

      # Reads the emitters (events, marks and edge exits in range) from (px, py), in one session of the world's probe;
      # in hide mode an emitter behind a wall is left out, save a near service desk. Notes where each event that walks
      # stands (its page moves it, or it is a puzzle's moving obstacle) for moved?.
      def self.scan(px, py)
        PokeAccess::World::Probe.session do
          lists = {}
          watch = []
          r = range
          hide = occlusion_mode == :hide
          pieces = moving_pieces
          PokeAccess::World::Events.records.each do |rec|
            ev = rec.ev
            next unless ev.x && ev.y
            watch.push([ev, ev.x, ev.y]) if pieces[ev.id] || PokeAccess::World::Events.mover?(rec)
            d = (ev.x - px).abs + (ev.y - py).abs
            next if d > r
            t = family_of(ev)
            next unless t
            next if hide && !line_clear?(px, py, ev.x, ev.y) && !desk_bypass?(ev, d)
            (lists[t] ||= []).push([ev.x, ev.y, d, (ev.character_name.to_s rescue "")])
          end
          marks(px, py, r, hide).each { |e| (lists[:mark] ||= []).push(e) }
          exits(px, py, r, hide).each { |e| (lists[:exit] ||= []).push(e) }
          @emitters = {}
          lists.each { |t, arr| @emitters[t] = cluster(arr).sort_by { |e| e[2] }[0, NEAR_MAX].map { |e| [e[0], e[1]] } }
          @watch = watch
          @stirred = false
        end
      end

      # The edge exits in range as emitters: for each map the border leads to, its tile nearest the player that a step
      # off the map is open from (Locator.connection_edges), under the same line of sight; each carries its destination,
      # so two exits side by side are not merged. The tiles are tried nearest first (ties in the border's order), as a
      # step off the map is an engine question no memo keeps.
      def self.exits(px, py, r, hide)
        out = []
        PokeAccess::Locator.connection_edges.each do |dest, tiles|
          near = []
          tiles.each_with_index do |t, i|
            d = (t[0] - px).abs + (t[1] - py).abs
            near.push([d, i, t]) if d <= r
          end
          hit = near.sort.find { |e| open_exit?(px, py, e[2], hide) }
          out.push([hit[2][0], hit[2][1], hit[0], dest]) if hit
        end
        out
      rescue StandardError => e
        PokeAccess.swallowed(e)
        []
      end

      # Whether a step off the map is open from an edge tile ([x, y, way]) the player can stand on and, in hide mode,
      # the tile is in sight. The engine opens a step off the map from the tile across alone, so a wall on the border
      # would pass.
      def self.open_exit?(px, py, tile, hide)
        x, y, way = tile
        step_open?(x, y, way) && standable?(px, py, x, y) && (!hide || line_clear?(px, py, x, y))
      end

      # Whether the player stands on (x, y) or a step into it from a tile of the map next to it is open.
      def self.standable?(px, py, x, y)
        return true if px == x && py == y
        PokeAccess::DIR_DELTA.any? do |d, delta|
          nx = x - delta[0]
          ny = y - delta[1]
          ($game_map.valid?(nx, ny) rescue false) && step_open?(nx, ny, d)
        end
      end

      # The ids of this map's moving puzzle obstacles (World::Mechanics), which other events may move.
      def self.moving_pieces
        out = {}
        PokeAccess::World::Mechanics.pieces(:obstacle).each { |p| out[p.ev.id] = true if p.moving }
        out
      rescue StandardError => e
        PokeAccess.swallowed(e)
        {}
      end

      # Whether an event that walks changed tile since the last scan within the sonar's range at either end of its
      # step (moving in it, coming into it or leaving it), or an event came, went or changed in it (stir).
      def self.moved?(px, py)
        r = range
        PokeAccess::World::Events.sync
        return true if @stirred
        @watch.any? do |ev, x, y|
          nx = ev.x
          ny = ev.y
          (nx != x || ny != y) && ((nx - px).abs + (ny - py).abs <= r || (x - px).abs + (y - py).abs <= r)
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Notes an event that came, went or changed within the sonar's range of the player (World::Events.on_change; a
      # step alone is the watch's), so moved? reads the emitters again with the player standing still.
      def self.stir(tiles, how)
        return if how == :move || $game_player.nil?
        px = $game_player.x
        py = $game_player.y
        r = range
        @stirred = true if tiles.any? { |x, y| (x - px).abs + (y - py).abs <= r }
      end

      # Reads the nearest water within the sonar's range of (px, py), and gives it.
      def self.read_water(px, py)
        @water = nearest_water(px, py, range)
      end

      # Reads, while the player surfs, the nearest tile within the sonar's range of (px, py) they could get off onto,
      # and gives it; nil on land or with none in range.
      def self.read_shore(px, py)
        afloat = ($PokemonGlobal && $PokemonGlobal.surfing) rescue false
        @shore = afloat ? nearest_shore(px, py, range) : nil
      end

      # The player's marks in range as emitters, under the same line of sight; each carries its name, so two marks side
      # by side are not merged.
      def self.marks(px, py, r, hide)
        out = []
        PokeAccess::Marks.on_map($game_map.map_id).each do |x, y, name|
          d = (x - px).abs + (y - py).abs
          next if d > r
          next if hide && !line_clear?(px, py, x, y)
          out.push([x, y, d, name])
        end
        out
      rescue StandardError => e
        PokeAccess.swallowed(e)
        []
      end

      # The nearest water tile within r, or nil, searched ring by ring outward so the first one found is the nearest.
      def self.nearest_water(px, py, r)
        t = PokeAccess::World::Terrain
        d = 0
        while d <= r
          ring(d).each do |off|
            x = px + off[0]; y = py + off[1]
            return [x, y] if t.water?(x, y)
          end
          d += 1
        end
        nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The nearest map tile within r the player cannot surf on that a step from the water next to it reaches (where
      # they get off a surf), or nil, also with them off the water; searched ring by ring outward, their tile left out.
      def self.nearest_shore(px, py, r)
        t = PokeAccess::World::Terrain
        return nil unless t.surfable?(px, py)
        d = 1
        while d <= r
          ring(d).each do |off|
            x = px + off[0]; y = py + off[1]
            return [x, y] if !t.outside?(x, y) && !t.surfable?(x, y) && landing?(x, y)
          end
          d += 1
        end
        nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Whether a step into (x, y) from a water tile next to it is open.
      def self.landing?(x, y)
        PokeAccess::DIR_DELTA.any? do |d, delta|
          wx = x - delta[0]
          wy = y - delta[1]
          PokeAccess::World::Terrain.water?(wx, wy) && step_open?(wx, wy, d)
        end
      end

      # The offsets at exactly Manhattan distance d, kept.
      def self.ring(d)
        return @rings[d] if @rings[d]
        out = []
        if d == 0
          out.push([0, 0])
        else
          i = 0
          while i < d
            j = d - i
            out.push([i, j], [j, -i], [-i, -j], [-j, i])
            i += 1
          end
        end
        @rings[d] = out
      end

      # Reads the distance to the nearest wall on each side of a wind (only on a tile change: the questions cost).
      def self.read_walls(px, py)
        @wall = {}
        Catalog.winds.each { |e| @wall[e.id] = ray(px, py, e.side) }
      end

      # The distance (1..wall_range) to the first closed step along a side ([direction, dx, dy]), or nil when open.
      def self.ray(px, py, side)
        dir, dx, dy = side
        (1..wall_range).detect do |i|
          !step_open?(px + dx * (i - 1), py + dy * (i - 1), dir)
        end
      end
    end
  end
end

# An event that comes, goes or changes near the player standing still is read at the next frame's check (moved?).
PokeAccess::World::Events.on_change { |tiles, _r, how| PokeAccess::Sound::Scene.stir(tiles, how) }
