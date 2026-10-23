module PokeAccess
  module World
    # The map's events as the world keeps them: one record per event, synced at most once a frame and when a search
    # starts, the tiles each covers in the engine's order (which runs where two share a tile), and facets kept while
    # the record and the flags they read stand. on_change tells the tiles, the record and the kind of each change.
    module Events
      # One event as last seen: the engine's object and id, its place in the engine's order, its generation, the
      # fields compared to tell it changed, the tiles it covers, and its facets ([value, flags read]) by name.
      Record = Struct.new(:ev, :id, :order, :gen, :x, :y, :w, :h, :page, :trigger, :char, :tile, :through, :name,
                          :tiles, :facets, :seen)

      # The packing of a tile into one index key, the routes' own (Routes.pkey).
      STRIDE = 100000
      NONE = [].freeze
      # The move route commands that take a step: the four ways and the diagonals, at random, toward or away from the
      # player, forward, backward and a jump.
      STEP_CODES = (1..14)

      @providers = {}
      @changes = []

      # Registers a meaning of an event, computed from its record on first use; a failing block gives nil.
      def self.facet_provider(name, &blk)
        @providers[name] = blk
        (@records || {}).each_value { |r| r.facets.delete(name) }
      end

      # Registers what to do when events change: the block gets the tiles each change left or reached, the record and
      # how it changed (:come, :go, :move when only its place did, or :change).
      def self.on_change(&blk); @changes.push(blk); end

      # True when the event walks about by itself: its page moves it at random, toward the player, or along a route
      # that takes a step.
      def self.mover?(r)
        pg = r.page
        return false if pg.nil?
        t = (pg.move_type rescue 0)
        return true if t == 1 || t == 2
        return false unless t == 3
        list = (pg.move_route.list rescue nil)
        list.is_a?(Array) && list.any? { |c| STEP_CODES.include?((c.code rescue 0)) }
      end

      # The engine's events that walk about by themselves (mover?) and block the way.
      def self.walkers
        records.select { |r| !r.through && mover?(r) }.map { |r| r.ev }
      end

      # The index key of a tile, Routes.pkey's packing.
      def self.key(x, y); x * STRIDE + y; end

      # Forgets every record (a new map), to be read afresh at the next sync.
      def self.forget
        @records = {}
        @list = []
        @cover = {}
        @with_deps = {}
        @summaries = {}
        @synced = nil
        @gen = (@gen || 0) + 1
        @turns = (@turns || 0) + 1
      end

      # The generation of the events as a whole, bumped by any change.
      def self.gen; @gen; end

      # Bumped when a page that may change a route turns (an action or touch event's), such an event comes or goes,
      # or a facet goes because what it read changed.
      def self.turns; @turns; end

      # Brings the records level with the engine's events: forced as a search starts, else at most once a frame; never
      # while events are lent through, a borrowed state of the engine and no change of the world.
      def self.sync(force = false)
        return if Probe.lending?
        Epoch.settle
        f = Epoch.frame
        return if !force && @synced == f
        @synced = f
        diff
        check_flags
      end

      # The records whose area covers (x,y), in the engine's order.
      def self.at(x, y)
        sync
        @cover[key(x, y)] || NONE
      end

      # The records standing on (x,y) itself, in the engine's order.
      def self.anchored(x, y)
        at(x, y).select { |r| r.x == x && r.y == y }
      end

      # The tiles the records covered as last read, as [x, y], without reading the events again (a map being left).
      def self.covered
        (@cover || {}).keys.map { |k| [k / STRIDE, k % STRIDE] }
      end

      # Every record, in the engine's order.
      def self.records
        sync
        @list
      end

      # The record of an engine event, or nil for one not among them.
      def self.record_of(ev)
        sync
        r = @records[(ev.id rescue nil)]
        r && r.ev.equal?(ev) ? r : nil
      end

      # The tiles event ev covers: its record's, else read now.
      def self.tiles_of(ev)
        r = @records[(ev.id rescue nil)]
        return r.tiles if r && r.ev.equal?(ev) && r.x == ev.x && r.y == ev.y
        area(ev.x, ev.y, PokeAccess.ivar(ev, :@width), PokeAccess.ivar(ev, :@height), (ev.name rescue nil))
      end

      # A facet of a record, computed on first use and kept while the record and the flags it read stand.
      def self.facet(r, name)
        f = r.facets[name]
        return f[0] if f
        prov = @providers[name]
        return nil unless prov
        v, deps = Flags.reading { (prov.call(r) rescue nil) }
        return v if Probe.lending?
        r.facets[name] = [v, deps]
        @with_deps[r.id] = r unless deps.empty?
        v
      end

      # A value derived from every record's facets, kept until any event changes; the block computes it.
      def self.summary(key)
        sync
        hit = @summaries[key]
        g = @gen
        return hit[1] if hit && hit[0] == g
        v = yield
        @summaries[key] = [g, v] unless Probe.lending? || g != @gen
        v
      end

      # Compares the engine's events with the records: new ones are added, changed ones refreshed, gone ones dropped;
      # the index follows the engine's order.
      def self.diff
        evs = ($game_map.events rescue nil)
        return unless evs.respond_to?(:each_value)
        @stamp = (@stamp || 0) + 1
        order = 0
        reorder = false
        evs.each_value do |ev|
          id = (ev.id rescue nil)
          next if id.nil?
          r = @records[id]
          if r && !r.ev.equal?(ev)
            drop(r)
            r = nil
          end
          if r.nil?
            r = add(ev, id, order)
            reorder = true
          else
            reorder = true if r.order != order
            r.order = order
            refresh(r)
          end
          r.seen = @stamp
          order += 1
        end
        gone = @records.values.select { |r| r.seen != @stamp }
        gone.each { |r| drop(r) }
        rebuild_order if reorder || !gone.empty?
      end

      # A record for a newly seen event, indexed.
      def self.add(ev, id, order)
        r = Record.new(ev, id, order, 0)
        r.facets = {}
        read(r)
        @records[id] = r
        r.tiles.each { |x, y| (@cover[key(x, y)] ||= []).push(r) }
        changed(r.tiles, routed?(r.trigger), r, :come)
        r
      end

      # Drops a record and its place in the index.
      def self.drop(r)
        @records.delete(r.id)
        @with_deps.delete(r.id)
        uncover(r)
        changed(r.tiles, routed?(r.trigger), r, :go)
      end

      # Reads the event again and, when any compared field differs, takes the new state, moves it in the index and
      # bumps its generation.
      def self.refresh(r)
        ev = r.ev
        page = PokeAccess.ivar(ev, :@page)
        trig = PokeAccess.ivar(ev, :@trigger)
        name = (ev.name rescue nil)
        kept = page.equal?(r.page) && trig == r.trigger && ev.character_name == r.char &&
               (ev.tile_id rescue nil) == r.tile && ((ev.through rescue false) ? true : false) == r.through &&
               name == r.name && PokeAccess.ivar(ev, :@width) == r.w && PokeAccess.ivar(ev, :@height) == r.h
        return if kept && ev.x == r.x && ev.y == r.y
        old = r.tiles
        turned = !page.equal?(r.page)
        was = r.trigger
        uncover(r)
        read(r)
        r.tiles.each { |x, y| insert(r, key(x, y)) }
        r.gen += 1
        r.facets = {}
        @with_deps.delete(r.id)
        changed(old | r.tiles, turned && (routed?(was) || routed?(r.trigger)), r, kept ? :move : :change)
      end

      # Takes the event's fields into its record.
      def self.read(r)
        ev = r.ev
        r.x = ev.x
        r.y = ev.y
        r.page = PokeAccess.ivar(ev, :@page)
        r.trigger = PokeAccess.ivar(ev, :@trigger)
        r.char = ev.character_name
        r.tile = (ev.tile_id rescue nil)
        r.through = (ev.through rescue false) ? true : false
        r.name = (ev.name rescue nil)
        r.w = PokeAccess.ivar(ev, :@width)
        r.h = PokeAccess.ivar(ev, :@height)
        r.tiles = area(r.x, r.y, r.w, r.h, r.name)
      end

      # True for the triggers whose pages a route reads: the action button and the two touches.
      def self.routed?(trigger); trigger == 0 || trigger == 1 || trigger == 2; end

      # Counts a change, a turn too when asked, and tells the listeners its tiles, the record and how (see on_change).
      def self.changed(tiles, turn, r, how)
        @gen += 1
        @turns += 1 if turn
        return if tiles.empty?
        @changes.each { |blk| blk.call(tiles, r, how) }
      end

      # Reads again the facets whose flags changed; a record whose facets now give another value is a turn.
      def self.check_flags
        return if @with_deps.empty?
        @with_deps.values.each do |r|
          stale = r.facets.select { |_n, f| !f[1].empty? && !Flags.current?(f[1]) }
          next if stale.empty?
          differs = false
          stale.each do |n, f|
            r.facets.delete(n)
            differs = true unless facet(r, n) == f[0]
          end
          @with_deps.delete(r.id) unless r.facets.values.any? { |f| !f[1].empty? }
          changed(r.tiles, true, r, :change) if differs
        end
      end

      # The tiles an event covers: w x h right and up from (x, y), the size the engine keeps (v19+) or the size(w,h) in
      # the name (gen 6), else one tile.
      def self.area(x, y, w, h, name)
        w, h = size_in(name) unless w.is_a?(Integer) && h.is_a?(Integer)
        out = []
        [w, 1].max.times { |i| [h, 1].max.times { |j| out.push([x + i, y - j]) } }
        out
      end

      # The size(w,h) a name gives, [1, 1] without one; kept per name.
      def self.size_in(name)
        @sizes ||= {}
        hit = @sizes[name]
        return hit if hit
        m = name.to_s.match(/size\(\s*(\d+)\s*,\s*(\d+)\s*\)/i)
        @sizes[name] = m ? [m[1].to_i, m[2].to_i] : [1, 1]
      end

      # Puts a record on a tile's list at its place in the engine's order.
      def self.insert(r, k)
        list = (@cover[k] ||= [])
        i = list.index { |o| o.order > r.order } || list.length
        list.insert(i, r)
      end

      # Takes a record off its tiles' lists.
      def self.uncover(r)
        r.tiles.each do |x, y|
          k = key(x, y)
          list = @cover[k]
          next unless list
          list.delete(r)
          @cover.delete(k) if list.empty?
        end
      end

      # Rebuilds the order list and every tile's list after events came, went or were reordered, and bumps the
      # generation: what a change's listener read from the records before the lists were whole is read again.
      def self.rebuild_order
        @list = @records.values.sort_by { |r| r.order }
        @cover.each_value { |list| list.sort! { |a, b| a.order <=> b.order } }
        @gen += 1
      end

      forget
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::World::Events.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Events.forget }
