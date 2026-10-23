module PokeAccess
  module World
    # The one place the world asks the engine whether the player can take a step, answers kept per mode until the map,
    # its tiles, a changed event's tiles or an event's end (unless plain!); never off the map (the neighbouring map's to
    # answer), touching a tile lent through or while unstable. An engine error is kept: closed for a route, open for
    # the sonar. A step into the player's own tile, which every engine refuses, is asked with the player on its origin.
    module Probe
      CLOSED = 0
      OPEN = 1
      ERROR = 2
      # How many modes keep their answers at once (on foot, on the bike, afloat).
      MODES_KEPT = 3
      STRIDE = Events::STRIDE

      @memos = {}
      @order = []
      @memo = nil
      @sig = nil
      @stable = true
      @lent = nil
      @asking = 0
      @open = 0
      @plain = false
      @loose_pushes = false
      @placers = []
      @readers = []

      # Declares that the game's passability reads nothing an event's end can change besides the tiles, the events and
      # the mode: its answers then outlive an event's end.
      def self.plain!; @plain = true; end

      # True when the game declared its passability plain.
      def self.plain?; @plain; end

      # Declares that the game pushes its pushables after the plain passable? check, its strict one left out (the
      # Reborn engine, Sevii): event_movable? asks that one.
      def self.loose_pushes!; @loose_pushes = true; end

      # Registers state the game's passability reads besides the vehicle (a lava surf, a mount): its value joins the
      # mode the answers are kept under.
      def self.mode_reader(&blk)
        @readers.push(blk)
        forget
      end

      # Registers when the game answers from where the player stands (Insurgence afloat): while the block says so, a
      # step is asked with the player placed on its origin, facing its way.
      def self.place_player_when(&blk); @placers.push(blk); end

      # Takes the mode and the stair state afresh: once a frame, as a session opens, and at the first question after
      # the answers were dropped.
      def self.refresh
        @stable = stable_now?
        sig = signature
        return if sig == @sig && @memo
        @sig = sig
        @memo = (@memos[sig] ||= {})
        @order.delete(sig)
        @order.push(sig)
        @memos.delete(@order.shift) while @order.length > MODES_KEPT
      end

      # Runs the block as one session of questions: the world is brought level once as it opens (tiles compared,
      # events synced, the mode taken) instead of at every question. A nested session shares the outer one.
      def self.session
        return yield if @open > 0
        Epoch.settle(true)
        Events.sync(true)
        refresh
        @open += 1
        begin
          yield
        ensure
          @open -= 1
        end
      end

      # Drops every answer kept.
      def self.forget
        @memos = {}
        @order = []
        @memo = nil
        @sig = nil
      end

      # The answers kept, for Visits to keep with the map left: [answers by mode, the modes' order].
      def self.saved; [@memos, @order]; end

      # Puts back answers saved with a map (saved).
      def self.restore(s)
        @memos, @order = s
        @memo = nil
        @sig = nil
      end

      # Drops the answers into and out of each tile given, in every mode kept.
      def self.forget_tiles(tiles)
        return if @memos.empty?
        tiles.each do |x, y|
          [[0, -1, 8], [0, 1, 2], [-1, 0, 4], [1, 0, 6]].each do |dx, dy, d|
            [0, 1].each do |b|
              k1 = memo_key(x - dx, y - dy, d, b)
              k2 = memo_key(x, y, d, b)
              @memos.each_value { |m| m.delete(k1); m.delete(k2) }
            end
          end
        end
      end

      # True when the player can step from (x,y) in direction d; on_error is the answer an engine error gives.
      def self.step?(x, y, d, on_error = false)
        v = answer(x, y, d)
        v == OPEN || (v == ERROR && on_error)
      end

      # True when the engine lets a jump from (x,y) facing d land on (lx,ly): its passable?(lx, ly, 0), the check a jump
      # makes, asked with the player placed on the jump's origin as the game has them. Asked of the engine every time.
      def self.lands?(x, y, d, lx, ly)
        engine(lx, ly, 0, [x, y, d]) == OPEN
      end

      # The tile (x, y) if the player could stand on it (some step out of it is open), else nil.
      def self.landing(x, y)
        return nil unless ($game_map.valid?(x, y) rescue false)
        [2, 4, 6, 8].any? { |d| step?(x, y, d) } ? [x, y] : nil
      end

      # True if an event could move one tile toward d from (x,y) by the game's own push check, its through flag off;
      # with stand, [event x, event y, player x, player y], both are posed there and the followers set aside meanwhile.
      def self.event_movable?(ev, x, y, d, stand = nil)
        was = (ev.through rescue false)
        (ev.through = false) rescue nil
        @asking += 1
        back = stand && [ev.x, ev.y, $game_player.x, $game_player.y]
        aside = back ? set_aside(followers) : []
        pose(ev, stand) if back
        if @loose_pushes
          ev.passable?(x, y, d) ? true : false
        elsif ev.respond_to?(:can_move_in_direction?)
          ev.passable?(x, y, d, true) ? true : false
        elsif ev.respond_to?(:passableStrict?)
          ev.passableStrict?(x, y, d) ? true : false
        else
          ev.passable?(x, y, d) ? true : false
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      ensure
        pose(ev, back) if back
        put_back(aside) if aside
        @asking -= 1
        (ev.through = was) rescue nil
      end

      # The characters that walk behind the player: Essentials' followers (v20+) and the gen-6 dependent events.
      def self.followers
        out = []
        fac = ($game_temp.followers rescue nil)
        fac.each_follower { |ev, _f| out.push(ev) } if fac.respond_to?(:each_follower)
        dep = ($PokemonTemp.dependentEvents rescue nil)
        real = dep ? PokeAccess.ivar(dep, :@realEvents) : nil
        out.concat(real) if real.is_a?(Array)
        out.compact
      end

      # Moves chars off the map, as [char, x, y] to put each back.
      def self.set_aside(chars)
        chars.map do |ch|
          spot = [ch, ch.x, ch.y]
          assign(ch, :x=, :@x, -100)
          assign(ch, :y=, :@y, -100)
          spot
        end
      end

      def self.put_back(spots)
        spots.each do |ch, x, y|
          assign(ch, :x=, :@x, x)
          assign(ch, :y=, :@y, y)
        end
      end

      # Puts an event on (s[0],s[1]) and the player on (s[2],s[3]), each facing as before.
      def self.pose(ev, s)
        assign(ev, :x=, :@x, s[0])
        assign(ev, :y=, :@y, s[1])
        pl = $game_player
        place(pl, s[2], s[3], pl.direction)
      end

      # Runs the block with events lent through to the engine (obstacles set aside, boulders walked into), their
      # tiles kept out of the memo meanwhile; every event is put back whatever happens, one listed twice too.
      def self.lend_through(events)
        return yield if events.empty?
        outer = @lent
        saved = []
        begin
          tiles = outer ? outer.dup : {}
          events.uniq.each do |ev|
            Events.tiles_of(ev).each { |x, y| tiles[key(x, y)] = true }
            saved.push([ev, (ev.through rescue false)])
            (ev.through = true) rescue nil
          end
          @lent = tiles
          yield
        ensure
          @lent = outer
          saved.each { |ev, t| (ev.through = t) rescue nil }
        end
      end

      # True while events are lent through (the world's events are as before, whatever the engine now says).
      def self.lending?; !@lent.nil?; end

      # The tiles lent through now, sorted, or nil while none are: what a memo made meanwhile depends on.
      def self.lent_tiles; @lent && @lent.keys.sort; end

      # Runs the block with the player off the bike for the engine, its answers kept in the on-foot mode's memo; the
      # bike is put back afterwards.
      def self.on_foot
        g = $PokemonGlobal
        was = g.bicycle
        return yield unless was
        g.bicycle = false
        refresh
        yield
      ensure
        if was
          g.bicycle = was
          refresh
        end
      end

      # True for a step out of a tile that is not water while afloat: off the water the engine has ended the surf
      # (pbEndSurf), so the step is asked on foot and walking back onto water is closed, as the game has it. A neutral
      # tile is laid over water (gen 6 reads its tag above the water's), so it stays afloat.
      def self.ashore?(x, y)
        @sig && @sig[0] == 1 && (Terrain.cell(x, y) & Terrain::SURF) == 0 && Terrain.kind(x, y) != :neutral
      end

      # Runs the block with the player afloat for the engine (a planned surf's water moves), its answers kept in the
      # afloat mode's memo; the surf flag is put back afterwards.
      def self.afloat(&blk); with_surf(true, &blk); end

      # Runs the block with the surf flag set to afloat, switching to that mode's memo and back without taking the mode
      # afresh, so it is cheap enough to run for one question.
      def self.with_surf(afloat)
        refresh if @memo.nil?
        g = $PokemonGlobal
        now = (g.surfing rescue false) ? true : false
        return yield if now == afloat || @sig.nil?
        keep = [@sig, @memo]
        sig = @sig.dup
        sig[0] = afloat ? 1 : 0
        g.surfing = afloat
        @sig = sig
        @memo = (@memos[sig] ||= {})
        yield
      ensure
        if keep
          g.surfing = now
          @sig, @memo = keep
        end
      end

      # True while a probe is asking the engine: a game whose passability check plays sounds keeps them quiet then.
      def self.quiet?; @asking > 0; end

      # True while the engine's answers can be kept: not partway up a side stair, not in the debug walk-through. Taken
      # once a frame, as the world settles.
      def self.stable?
        Epoch.settle
        @stable
      end

      # The kept or fresh answer for a step (OPEN, CLOSED or ERROR).
      def self.answer(x, y, d)
        Events.sync if @open == 0
        refresh if @memo.nil? || (@open == 0 && signature != @sig)
        return with_surf(false) { answer(x, y, d) } if ashore?(x, y)
        memo = @memo
        dd = PokeAccess::DIR_DELTA[d]
        return engine(x, y, d) if dd.nil? || !@stable
        nx = x + dd[0]
        ny = y + dd[1]
        return clear(x, y, d, nx, ny) if Terrain.outside?(nx, ny) || (@lent && (@lent[key(x, y)] || @lent[key(nx, ny)]))
        k = memo_key(x, y, d, height_bit(x, y, nx, ny))
        v = memo[k]
        v.nil? ? fill(k, x, y, d, nx, ny) : v
      end

      # step? for a step between two tiles of the map, neither a bridge's (as Routes::Moves.fast knows them): the same
      # answer, without the checks such tiles need not.
      def self.flat_step?(x, y, d, nx, ny)
        return step?(x, y, d) if @open == 0 || @memo.nil? || !@stable || @lent || ashore?(x, y)
        k = ((y + x * STRIDE) * 16 + d) * 2
        v = @memo[k]
        v = fill(k, x, y, d, nx, ny) if v.nil?
        v == OPEN
      end

      # The answer for a step not yet kept (clear), kept under k.
      def self.fill(k, x, y, d, nx, ny)
        @memo[k] = clear(x, y, d, nx, ny)
      end

      # The engine's answer for a step into (nx,ny); one refused into the player's own tile is asked again with the
      # player on the step's origin, where the step would find them, so it holds wherever they stand.
      def self.clear(x, y, d, nx, ny)
        v = engine(x, y, d)
        v == CLOSED && into_player?(nx, ny) ? engine(x, y, d, [x, y, d]) : v
      end

      # The engine's answer for a step, with the player's through lent off and, where the game asks for it, the
      # player placed on the step's origin; an error is ERROR. Whatever is lent is put back, whatever fails.
      # param at [x, y, facing] to place the player on whatever the game asks for (a jump's origin)
      def self.engine(x, y, d, at = nil)
        pl = $game_player
        return CLOSED if pl.nil?
        @asking += 1
        through = false
        spot = nil
        begin
          through = (pl.through rescue false)
          at ||= [x, y, d] if placing?
          if at
            spot = [pl.x, pl.y, pl.direction]
            place(pl, at[0], at[1], at[2])
          end
          pl.through = false if through
          pl.passable?(x, y, d) ? OPEN : CLOSED
        ensure
          pl.through = through if through
          place(pl, spot[0], spot[1], spot[2]) if spot
          @asking -= 1
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        ERROR
      end

      # True while a game's block asks for the player to be placed on each step's origin.
      def self.placing?
        @placers.any? { |b| (b.call rescue false) }
      end

      # Puts the player on (x, y) facing d: through its writers where the engine has them (Insurgence), else its
      # fields (the Reborn engine's player only has readers).
      def self.place(pl, x, y, d)
        assign(pl, :x=, :@x, x)
        assign(pl, :y=, :@y, y)
        assign(pl, :direction=, :@direction, d)
      end

      # Sets one of the player's fields through its writer, or the field itself where it has none.
      def self.assign(pl, writer, ivar, v)
        pl.respond_to?(writer) ? pl.send(writer, v) : pl.instance_variable_set(ivar, v)
      end

      # True if (x, y) is the tile the player stands on, which every engine refuses the player while they stand there.
      def self.into_player?(x, y)
        pl = $game_player
        !pl.nil? && x == pl.x && y == pl.y
      end

      # The mode the answers are kept under: surfing, diving, the bike, and what the game's readers add.
      def self.signature
        g = $PokemonGlobal
        sig = [(g.surfing rescue false) ? 1 : 0, (g.diving rescue false) ? 1 : 0, (g.bicycle rescue false) ? 1 : 0]
        @readers.each { |b| sig.push((b.call rescue nil)) }
        sig
      end

      # Whether answers can be kept now: false partway up a side stair (Marin's plugin answers every question from
      # the stair) or walking through walls in a debug build.
      def self.stable_now?
        pl = $game_player
        return true if pl.nil?
        return false if pl.respond_to?(:on_middle_of_stair?) && pl.on_middle_of_stair?
        return false if !pl.respond_to?(:on_middle_of_stair?) && pl.respond_to?(:on_stair?) && pl.on_stair?
        !($DEBUG && (Input.press?(Input::CTRL) rescue false))
      rescue StandardError => e
        PokeAccess.swallowed(e)
        true
      end

      # The bridge bit of a step's key: 1 while the bridge height can change it, a bridge tile at either end.
      def self.height_bit(x, y, nx, ny)
        return 0 unless Terrain.bridge_at?(x, y) || Terrain.bridge_at?(nx, ny)
        Engine.bridge_height > 0 ? 1 : 0
      end

      # A tile's key.
      def self.key(x, y); y + x * STRIDE; end

      # A step's key in the memo: its origin, direction and bridge bit.
      def self.memo_key(x, y, d, b); ((y + x * STRIDE) * 16 + d) * 2 + b; end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::World::Probe.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Probe.forget }
PokeAccess::World::Epoch.on(:frame) { PokeAccess::World::Probe.refresh }
PokeAccess::World::Events.on_change { |tiles, _r, _how| PokeAccess::World::Probe.forget_tiles(tiles) }
PokeAccess::World::Visits.keeper(lambda { PokeAccess::World::Probe.saved },
                                 lambda { |s| PokeAccess::World::Probe.restore(s) })
