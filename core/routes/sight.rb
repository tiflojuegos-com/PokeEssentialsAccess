module PokeAccess
  module Routes
    # What the map's watchers see: the events a profile declares (watchers) and, with avoid_trainers, the trainers still
    # to battle. Each sees its own tiles and those ahead of it as Essentials' pbEventCanReachPlayer? reads them, from
    # every pose its page's moves take it to (poses). Walks keep off what they see while another way exists
    # (Planner.searched_off), the guide plans again when it changes (stamp) and the free camera says who sees a tile.
    module Sight
      # A declaration: the map ids it holds on (nil for every map), what picks its events (ids, a Regexp of the name, a
      # block of the event; nil for those named for their sight), how far they see (a number or a block of the event;
      # nil for the name's number) and whether their sight passes what stops them (nil as the engine: when they walk
      # through).
      Watch = Struct.new(:maps, :pick, :range, :through)
      # A watcher as read: its World::Events record, how far it sees and whether its sight passes walls and events.
      Watcher = Struct.new(:rec, :range, :through)

      # The sight range Essentials reads from a watcher's name: from the GameData era on, "trainer(n)" or "sight(n)"
      # anywhere in it, whatever the case; before it, the name "Trainer(n)" alone.
      NAME_RE = /(?:sight|trainer)\((\d+)\)/i
      OLD_NAME_RE = /^Trainer\((\d+)\)$/
      # How far from where it was read a watcher that moves at random or by the player is taken to roam, in tiles.
      ROAM = 2
      # The keys watchers takes.
      OPTS = [:events, :range, :through]
      # The steps of the four ways an event faces.
      STEP = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
      FACES = [2, 4, 6, 8]
      # Move route commands: the four steps with the way each faces, the diagonals, the moves and turns at random or by
      # the player (any way may follow them), and the quarter turns.
      MOVES = { 1 => [0, 1, 2], 2 => [-1, 0, 4], 3 => [1, 0, 6], 4 => [0, -1, 8] }
      DIAGONALS = { 5 => [-1, 1], 6 => [1, 1], 7 => [-1, -1], 8 => [1, -1] }
      LOOSE_MOVES = [9, 10, 11]
      LOOSE_TURNS = [23, 24, 25, 26]
      RIGHT = { 2 => 4, 4 => 8, 6 => 2, 8 => 6 }
      LEFT = { 2 => 6, 4 => 2, 6 => 8, 8 => 4 }
      NONE = {}.freeze

      @watches = []
      @declared = 0
      @stamp = 0
      @rounds = {}

      # Declares watchers on maps (a map id, a list of them, nil for every map) with opts :events, :range and :through
      # (see Watch); a key it does not know, or options in place of the maps, is an error, so a misspelt declaration
      # cannot silence a watcher.
      def self.declare(maps, opts = {})
        raise ArgumentError, "watchers takes the maps first" if maps.is_a?(Hash)
        bad = opts.keys.reject { |k| OPTS.include?(k) }
        raise ArgumentError, "unknown watchers key #{bad[0].inspect}" unless bad.empty?
        @watches.push(Watch.new(maps.nil? ? nil : [maps].flatten, opts[:events], opts[:range], opts[:through]))
        @declared += 1
        forget
      end

      # Forgets every declaration.
      def self.clear
        @watches = []
        @declared += 1
        forget
      end

      # Forgets what was read of the map's watchers, read again at the next question.
      def self.forget
        @view = nil
        @key = nil
        @at = nil
        @now = nil
        @rounds = {}
      end

      # True when watchers may see on this map: a declaration holds here, or avoid_trainers is on.
      def self.watched?
        return true if (PokeAccess::Config.avoid_trainers rescue false)
        return false if @watches.empty?
        id = ($game_map.map_id rescue nil)
        @watches.any? { |w| w.maps.nil? || w.maps.include?(id) }
      end

      # The tiles the map's watchers see now, as pkey => the engine event of the first that sees it: read at most once a
      # frame, and again when a watcher leaves the poses read for it, comes or goes, or an event's end or the vehicle
      # (Pathfinder.event_epoch) or the tiles may have changed what stops a sight. Where none may see, nothing; leaving
      # tiles seen behind so (avoid_trainers turned off, another map) counts as a change.
      def self.seen
        unless watched?
          @stamp += 1 if @view && !@view.empty?
          @view = nil
          @key = nil
          return NONE
        end
        f = PokeAccess::World::Epoch.frame
        return @view if @view && @at == f
        @at = f
        list = watchers
        key = [PokeAccess::Pathfinder.event_epoch, list.map { |w| [w.rec.id, w.range, w.through, round_of(w.rec).__id__] }]
        return @view if @view && key == @key
        @key = key
        view = {}
        list.each { |w| sights(w, view) }
        @stamp += 1 unless view == @view
        @view = view
      end

      # The tiles the map's watchers see from where they stand and face now, and their own, as pkey => the engine event
      # (one that sees a tile before one that stands on it), read at most once a frame: what the free camera says and a
      # profile's hints by the frame read where a patrol's round is crossed in time (seen holds the whole round).
      def self.seen_now
        return NONE unless watched?
        f = PokeAccess::World::Epoch.frame
        return @now if @now && @now_at == f
        @now_at = f
        out = {}
        list = watchers
        list.each { |w| line(w.rec.ev, w.rec.ev.x, w.rec.ev.y, w.rec.ev.direction.to_i, w.range, w.through, out) }
        list.each { |w| w.rec.tiles.each { |tx, ty| out[Routes.pkey(tx, ty)] ||= w.rec.ev } }
        @now = out
      end

      # True when a watcher sees (x,y) now (seen).
      def self.seen?(x, y); seen.key?(Routes.pkey(x, y)); end

      # How many times what the watchers see has changed: a route planned under another stamp is planned again.
      def self.stamp
        seen
        @stamp
      end

      # What the free camera says of (x,y) when a watcher sees it from where it stands and faces now (seen_now), as a
      # sighted player sees: in sight of whom, by the name the locator gives it (the player's tag first); nothing on the
      # watcher's own tiles.
      def self.camera_line(x, y)
        ev = seen_now[Routes.pkey(x, y)]
        return nil if ev.nil? || PokeAccess::World::Events.tiles_of(ev).include?([x, y])
        PokeAccess::I18n.t(:sight_in_view, :name => PokeAccess::Locator.target_name(ev))
      end

      # The map's watchers that watch now, kept until any event or declaration changes: each declared one while drawn
      # (one picked by its name's sight, as the engine, only on a page started by event touch), and with avoid_trainers
      # each trainer still to battle (trainer?).
      def self.watchers
        trainers = (PokeAccess::Config.avoid_trainers rescue false) ? true : false
        id = ($game_map.map_id rescue nil)
        PokeAccess::World::Events.summary([:sight, id, trainers, @declared]) do
          here = @watches.select { |w| w.maps.nil? || w.maps.include?(id) }
          out = []
          PokeAccess::World::Events.records.each do |r|
            w = here.find { |h| picks?(h.pick, r) && drawn?(r) && (!h.pick.nil? || r.trigger == 2) }
            if w
              out.push(Watcher.new(r, range_of(w.range, r), w.through.nil? ? r.through : w.through))
            elsif trainers && trainer?(r)
              out.push(Watcher.new(r, r.name.to_s[name_re, 1].to_i, r.through))
            end
          end
          out
        end
      end

      # The way the running era reads a watcher's sight from its name (NAME_RE, OLD_NAME_RE).
      def self.name_re; PokeAccess::Engine.gamedata? ? NAME_RE : OLD_NAME_RE; end

      # True when a declaration's pick takes record r's event: its id among a list, its name matching a Regexp, a yes from
      # a block of the event; nil takes those named for their sight.
      def self.picks?(pick, r)
        case pick
        when nil then !(r.name.to_s =~ name_re).nil?
        when Regexp then !(r.name.to_s =~ pick).nil?
        when Proc then pick.call(r.ev) ? true : false
        else [pick].flatten.include?(r.id)
        end
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # How far a declared watcher of record r sees: the number given, a block's answer for its event, else the number of
      # its name; 0 for its own tiles alone.
      def self.range_of(range, r)
        n = range.respond_to?(:call) ? range.call(r.ev) : range
        (n.nil? ? r.name.to_s[name_re, 1] : n).to_i
      rescue StandardError => e
        PokeAccess.swallowed(e)
        0
      end

      # True when record r's event is drawn on a page: a sprite or a tile.
      def self.drawn?(r)
        !r.page.nil? && (!r.char.to_s.empty? || r.tile.to_i > 0)
      end

      # True for a trainer still to battle as the engine starts one by sight: named for its sight, drawn, its page started
      # by event touch, and not one the player would stand over (over_trigger?).
      def self.trainer?(r)
        return false unless r.trigger == 2 && drawn?(r) && !(r.name.to_s =~ name_re).nil?
        !(r.ev.respond_to?(:over_trigger?) && r.ev.over_trigger?)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # The poses the watcher of record r takes (poses), kept while it stands on one of them with the same page and the
      # same route forced on it, or none: a scene's route is forgotten as it ends.
      def self.round_of(r)
        ev = r.ev
        forced = forced_route(ev)
        kept = @rounds[r.id]
        if kept && kept[0].equal?(r.page) && kept[1].equal?(forced) && kept[2].include?([ev.x, ev.y, ev.direction.to_i])
          return kept[2]
        end
        poses = poses(ev)
        @rounds[r.id] = [r.page, forced, poses]
        poses
      end

      # The move route an event command forces on ev while it walks it, nil for none.
      def self.forced_route(ev)
        PokeAccess.ivar(ev, :@move_route_forcing) ? PokeAccess.ivar(ev, :@move_route) : nil
      end

      # The poses [x, y, d] an engine event takes on its moves from where it stands: those of the route an event command
      # forces on it (a parallel event's patrol, repeated or given again, or a scene's), else its own alone when it
      # keeps still, the four ways on every tile it may roam to (roam) when it moves at random or by the player, or those
      # its page's move route takes it through (walk).
      def self.poses(ev)
        x = ev.x
        y = ev.y
        d = ev.direction.to_i
        forced = forced_route(ev)
        page = PokeAccess.ivar(ev, :@page)
        type = forced ? 3 : (PokeAccess.ivar(ev, :@move_type) || (page.move_type rescue 0)).to_i
        return [[x, y, d]] if type == 0
        return roam(x, y) unless type == 3
        route = forced || (page.move_route rescue nil) || PokeAccess.ivar(ev, :@move_route)
        list = (route.list rescue nil)
        return [[x, y, d]] unless list.is_a?(Array) && !list.empty?
        walk(list, (route.repeat rescue true) ? true : false, PokeAccess.ivar(ev, :@move_route_index).to_i, [x, y, d],
             PokeAccess.ivar(ev, :@direction_fix) ? true : false)
      end

      # The four ways at (x,y).
      def self.around(x, y); FACES.map { |f| [x, y, f] }; end

      # The four ways on each tile within ROAM steps of (x,y) that can be stood on: where a watcher moving at random or by
      # the player may be, kept while it stays there so its steps do not change what it is taken to see.
      def self.roam(x, y)
        m = $game_map
        out = []
        (-ROAM..ROAM).each do |dx|
          left = ROAM - dx.abs
          (-left..left).each do |dy|
            tx = x + dx
            ty = y + dy
            next unless (dx == 0 && dy == 0) || ((m.valid?(tx, ty) && m.passable?(tx, ty, 0)) rescue false)
            out.concat(around(tx, ty))
          end
        end
        out
      end

      # The poses a move route list takes an event through from command i and pose [x, y, d], its direction fixed with
      # fix: one round, two at most, up to a command it comes back to in a pose it was in, as the route walks it
      # whatever stands in the way. Where it moves at random or by the player, where it may roam from there (roam) and
      # no further; where it turns so, the four ways there.
      def self.walk(list, repeat, i, pose, fix)
        x, y, d = pose
        out = [[x, y, d]]
        been = {}
        n = list.length
        (n * 2).times do
          i = 0 if i >= n
          state = [i, x, y, d]
          break if been[state]
          been[state] = true
          c = list[i]
          code = (c.code rescue 0).to_i
          i += 1
          if code == 0
            break unless repeat
            i = 0
          elsif (m = MOVES[code])
            x += m[0]
            y += m[1]
            d = m[2] unless fix
          elsif (m = DIAGONALS[code])
            x += m[0]
            y += m[1]
            d = diagonal_facing(m, d) unless fix
          elsif code == 12 || code == 13
            s = STEP[d] || [0, 0]
            k = code == 12 ? 1 : -1
            x += s[0] * k
            y += s[1] * k
          elsif code == 14
            jx, jy = (c.parameters rescue [0, 0])
            x += jx.to_i
            y += jy.to_i
            d = jump_facing(jx.to_i, jy.to_i, d) unless fix
          elsif code >= 16 && code <= 22
            d = turned(code, d) unless fix
          elsif LOOSE_MOVES.include?(code)
            return (out + roam(x, y)).uniq
          elsif LOOSE_TURNS.include?(code)
            out.concat(around(x, y))
          elsif code == 35 || code == 36
            fix = code == 35
          end
          out.push([x, y, d])
        end
        out.uniq
      end

      # The way an event facing d faces after a diagonal step m ([dx, dy]), as RPG Maker turns it: the step's side when
      # it faced the other.
      def self.diagonal_facing(m, d)
        h = m[0] < 0 ? 4 : 6
        v = m[1] < 0 ? 8 : 2
        return h if d == 10 - h
        d == 10 - v ? v : d
      end

      # The way an event faces after a jump of (jx, jy): toward its longer leg, as before for a jump in place.
      def self.jump_facing(jx, jy, d)
        return d if jx == 0 && jy == 0
        jx.abs > jy.abs ? (jx < 0 ? 4 : 6) : (jy < 0 ? 8 : 2)
      end

      # The way an event facing d faces after a turn command (16 to 22): down, left, right, up, a quarter right or left,
      # half round.
      def self.turned(code, d)
        case code
        when 20 then RIGHT[d] || d
        when 21 then LEFT[d] || d
        when 22 then 10 - d
        else FACES[code - 16]
        end
      end

      # Adds to view what watcher w sees from each pose of its round: the tiles it stands on there (all its tiles where
      # it stands now) and those ahead (line); the first watcher to see a tile names it.
      def self.sights(w, view)
        ev = w.rec.ev
        w.rec.tiles.each { |tx, ty| view[Routes.pkey(tx, ty)] ||= ev }
        round_of(w.rec).each do |x, y, d|
          view[Routes.pkey(x, y)] ||= ev
          line(ev, x, y, d, w.range, w.through, view)
        end
      end

      # Adds to view the tiles a watcher ev facing d from (x,y) sees out to n: each one ahead while the watcher could
      # walk on to the one before it (open?), as pbEventCanReachPlayer? asks, or every one with through.
      def self.line(ev, x, y, d, n, through, view)
        s = STEP[d]
        return unless s
        m = $game_map
        n.times do
          nx = x + s[0]
          ny = y + s[1]
          break unless (m.valid?(nx, ny) rescue false)
          view[Routes.pkey(nx, ny)] ||= ev
          break unless through || open?(m, ev, x, y, d, nx, ny)
          x = nx
          y = ny
        end
      end

      # True when watcher ev could step from (x,y) toward d onto (nx,ny): the map's passability lets it both ways, and no
      # other event that keeps still and blocks stands there (a walker's place changes, the player is whom it looks for).
      def self.open?(m, ev, x, y, d, nx, ny)
        return false unless passes?(m, x, y, d, ev) && passes?(m, nx, ny, 10 - d, ev)
        PokeAccess::World::Events.at(nx, ny).none? do |r|
          !r.ev.equal?(ev) && !r.through && !PokeAccess::World::Events.mover?(r)
        end
      end

      # The map's passability of (x,y) toward d for ev, handed to Game_Map#passable? where it takes the event; false
      # where it cannot be read.
      def self.passes?(m, x, y, d, ev)
        unless @four_of.equal?(m.class)
          a = (m.method(:passable?).arity rescue 3)
          @four = a == 4 || a <= -4 || a == -1
          @four_of = m.class
        end
        (@four ? m.passable?(x, y, d, ev) : m.passable?(x, y, d)) ? true : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end
    end
  end
end

PokeAccess::World::Epoch.on(:tiles) { PokeAccess::Routes::Sight.forget }
PokeAccess::Caches.register(:sight) { PokeAccess::Routes::Sight.forget }

# The free camera says who sees the tile it steps on.
PokeAccess::Camera.tile_reader { |x, y| PokeAccess::Routes::Sight.camera_line(x, y) }
