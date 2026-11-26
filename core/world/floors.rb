module PokeAccess
  module World
    # The map's events as the engine would show them with its floor switch the other way (Routes::Effects.level_switch):
    # each event whose page that switch turns has a stand-in, a copy set up on the page it would show. While a search
    # looks at that floor (view), the records, facets, summaries, flags and the probe's answers are its own; the game's
    # state is never touched, the stand-ins being shown to the engine only while it is asked about a step.
    module Floors
      @view = nil
      @built = nil
      @hooks = []
      @stale_hooks = []

      # Registers a block told the view's key ([switch, value], nil for the floor as it stands) whenever it changes.
      def self.on_view(&blk); @hooks.push(blk); end

      # Registers a block run when what was kept for the other floor is dropped (check), so that floor's answers go too.
      def self.on_stale(&blk); @stale_hooks.push(blk); end

      # The floor looked at: [switch, value] while it is not the one that stands, else nil.
      def self.key; @view; end

      # True while a search looks at the floor that does not stand.
      def self.active?; !@view.nil?; end

      # Looks at the floor with switch sw set to on for what is asked next: the one that stands when it is set so, or sw
      # is nil.
      def self.view(sw, on)
        want = sw.nil? || live?(sw) == (on ? true : false) ? nil : [sw, on ? true : false]
        set(want) unless want == @view
      end

      # Runs the block looking at the floor with switch sw set to on, the view before it put back whatever happens.
      def self.looking(sw, on)
        was = @view
        view(sw, on)
        begin
          yield
        ensure
          set(was) unless was == @view
        end
      end

      # Runs the block looking at the floor that stands, the view put back after whatever happens.
      def self.live
        was = @view
        return yield if was.nil?
        set(nil)
        begin
          yield
        ensure
          set(was)
        end
      end

      # The value switch id is looked at with: the view's while it looks at that switch, else nil.
      def self.override(id)
        v = @view
        v && v[0] == id ? v[1] : nil
      end

      # Whether switch id is on on the floor looked at.
      def self.on?(id)
        o = override(id)
        o.nil? ? live?(id) : o
      end

      # Whether switch id is on as the game stands.
      def self.live?(id); $game_switches && $game_switches[id] ? true : false; end

      # Takes view v and tells the hooks.
      def self.set(v)
        @view = v
        @hooks.each { |blk| blk.call(v) }
      end

      # The stand-ins of the floor looked at, event id => Events::Record, made once per events generation and view;
      # {} on the floor that stands.
      def self.stand_ins
        v = @view
        return {} if v.nil?
        built[:stands]
      end

      # The stand-in record of event id on the floor looked at, or nil.
      def self.stand_in(id)
        @view ? built[:stands][id] : nil
      end

      def self.stand_in?(r); @view ? built[:stands][r.id].equal?(r) : false; end

      # What the view keeps for the floor looked at: its stand-ins, the page choices' reads, the records in the engine's
      # order and per tile, its facets and summaries, and the engine's events with the stand-ins in their places.
      def self.built
        key = [Events.gen, @view, ($game_map.events rescue nil).object_id]
        return @built[1] if @built && @built[0] == key
        stands, deps = Flags.reading { make_stand_ins(@view[0], @view[1]) }
        b = { :stands => stands, :deps => deps, :cover => {}, :facets => {}, :summaries => {}, :engine => nil }
        b[:records] = Events.live_records.map { |r| stands[r.id] || r }
        @built = [key, b]
        b
      end

      # The stand-ins of the events whose page switch sw set to on turns, event id => record.
      def self.make_stand_ins(sw, on)
        out = {}
        Events.live_records.each do |r|
          pages = Mechanics::Links.pages(r.ev)
          next unless pages.any? { |pg| shows_by?(pg, sw) }
          page = page_with(r.ev, pages, sw, on)
          next if page.equal?(r.page)
          out[r.id] = Events.stand_in_record(r, copy(r.ev, page), page)
        end
        out
      end

      # True when page pg shows only with switch sw on, by either of its switch conditions.
      def self.shows_by?(pg, sw)
        c = (pg.condition rescue nil)
        return false unless c
        ((c.switch1_valid rescue false) && c.switch1_id == sw) || ((c.switch2_valid rescue false) && c.switch2_id == sw)
      end

      # The page the engine shows event ev with switch sw set to on, the other conditions read through Flags; nil for an
      # erased event or one no page of shows.
      def self.page_with(ev, pages, sw, on)
        return nil if PokeAccess.ivar(ev, :@erased)
        mid = ($game_map.map_id rescue 0)
        pages.reverse.find do |pg|
          c = pg.condition
          next true unless c
          next false if (c.switch1_valid rescue false) && !(c.switch1_id == sw ? on : Flags.switch(c.switch1_id))
          next false if (c.switch2_valid rescue false) && !(c.switch2_id == sw ? on : Flags.switch(c.switch2_id))
          next false if (c.variable_valid rescue false) && Flags.variable(c.variable_id).to_i < c.variable_value.to_i
          !(c.self_switch_valid rescue false) || Flags.self_switch([mid, ev.id, c.self_switch_ch])
        end
      end

      # A copy of event ev set up on page as the engine's refresh sets an event on its page: graphic, facing,
      # Through, trigger and list; with no page, nothing to show, Through on.
      def self.copy(ev, page)
        c = ev.dup
        put(c, :@page, page)
        put(c, :@interpreter, nil)
        if page.nil?
          [[:@tile_id, 0], [:@character_name, ""], [:@character_hue, 0], [:@move_type, 0], [:@through, true],
           [:@trigger, nil], [:@list, nil]].each { |k, v| put(c, k, v) }
          return c
        end
        g = page.graphic
        dir = (g.direction rescue nil)
        put(c, :@direction, dir) if dir && PokeAccess.ivar(ev, :@original_direction) != dir
        [[:@tile_id, (g.tile_id rescue 0)], [:@character_name, (g.character_name rescue "")],
         [:@character_hue, (g.character_hue rescue 0)], [:@opacity, (g.opacity rescue 255)],
         [:@move_type, (page.move_type rescue 0)], [:@direction_fix, (page.direction_fix rescue false)],
         [:@through, (page.through rescue false) ? true : false], [:@always_on_top, (page.always_on_top rescue false)],
         [:@trigger, (page.trigger rescue 0)], [:@list, (page.list rescue nil)]].each { |k, v| put(c, k, v) }
        c
      end

      def self.put(obj, ivar, v); obj.instance_variable_set(ivar, v); end

      # True when a stand-in of the floor looked at covers a tile within one of the tile of key k (Events.key): a step
      # from or to that tile may be shown other events than on the floor that stands.
      def self.near_stand_in?(k)
        b = built
        near = b[:near]
        unless near
          near = b[:near] = {}
          b[:stands].each_value do |r|
            r.tiles.each { |x, y| (-1..1).each { |dx| (-1..1).each { |dy| near[Events.key(x + dx, y + dy)] = true } } }
          end
        end
        near[k] ? true : false
      end

      # The records of the floor looked at, in the engine's order.
      def self.records; built[:records]; end

      # The records of the floor looked at whose area covers tile key k: list, the live records there, with stand-ins.
      def self.cover(k, list)
        b = built
        hit = b[:cover][k]
        return hit if hit
        s = b[:stands]
        b[:cover][k] = s.empty? ? list : list.map { |r| s[r.id] || r }
      end

      # The engine's events with the stand-ins in their places, made from live once per view.
      def self.engine_events(live)
        b = built
        e = b[:engine]
        return e[1] if e && e[0].equal?(live)
        h = {}
        live.each { |id, ev| h[id] = ev }
        b[:stands].each { |id, r| h[id] = r.ev if h.key?(id) }
        b[:engine] = [live, h]
        h
      end

      # Runs the block with the engine shown the floor looked at, its events put back whatever happens.
      def self.engine
        map = $game_map
        return yield unless @view && map
        live = map.instance_variable_get(:@events)
        map.instance_variable_set(:@events, engine_events(live))
        begin
          yield
        ensure
          map.instance_variable_set(:@events, live)
        end
      end

      # True when reads (Flags pairs) include the switch looked at.
      def self.reads?(reads)
        sw = @view && @view[0]
        reads.any? { |k, _v| k[0] == :switch && k[1] == sw }
      end

      # A facet of record r on the floor looked at, kept with its reads while they still give what they gave; the block
      # gives [value, reads]. Nothing is kept while events are lent through.
      def self.facet(r, name)
        f = built[:facets]
        k = [r.id, name]
        hit = f[k]
        return hit[0] if hit && Flags.current?(hit[1])
        v, deps = yield
        f[k] = [v, deps] unless Probe.lending?
        v
      end

      # A summary of the floor looked at (Events.summary), kept with its view and events generation.
      def self.summary(key)
        s = built[:summaries]
        return s[key][0] if s.key?(key)
        v = yield
        s[key] = [v] unless Probe.lending?
        v
      end

      # Drops what was kept for a floor whose page choices or facets read something that has changed since, each read
      # under the view it was made in; called as a search starts.
      def self.check
        return unless @built
        v = @built[0][1]
        b = @built[1]
        stale = false
        with_key(v) do
          stale = !Flags.current?(b[:deps]) || b[:facets].values.any? { |f| !Flags.current?(f[1]) }
        end
        return unless stale
        @built = nil
        @stale_hooks.each { |blk| blk.call }
      end

      # Runs the block with the view set to v without telling the hooks: only flags are read meanwhile.
      def self.with_key(v)
        was = @view
        @view = v
        begin
          yield
        ensure
          @view = was
        end
      end

      # Drops every floor kept and looks at the floor that stands.
      def self.forget
        @built = nil
        set(nil) if @view
      end
    end
  end
end

PokeAccess::Caches.register(:floors) { PokeAccess::World::Floors.forget }
