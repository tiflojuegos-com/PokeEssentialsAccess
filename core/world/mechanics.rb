module PokeAccess
  module World
    # The map's mechanics (its puzzles): the definitions declared per map, the live instance on the current map, its
    # pieces (obstacles and statues by their graphic, controls by the flags their pages write), the state it watches,
    # and each frame's changes, queued for Puzzles to say. Built silently at the first look, it never speaks itself.
    module Mechanics
      # A piece found on the map: its role (:obstacle, :control, :statue or :named), its event, its label (a control's
      # watch label, an obstacle's declared one, the one a name gives), whether an obstacle moves and whether a name
      # gave the label, with the assist alone when that name asks for it (:assist).
      Piece = Struct.new(:role, :ev, :label, :moving, :named, :assist, :listed)
      # A mechanic live on the current map: its declaration, its kind (:grid, :state or :facing) and type module, the
      # map, the type's own state, the controls found once (event id => watch entry), the pieces, the event generation
      # they were found at, and the obstacle groups beside the player as last seen.
      Instance = Struct.new(:spec, :kind, :type, :map_id, :data, :controls, :pieces, :gen, :near)

      NONE = [].freeze

      @defs = {}
      @types = {}
      @insts = nil
      @at = nil
      @queue = []

      # Registers a mechanic type under its name: a module answering enter(inst) and update(inst, out).
      def self.register_type(name, type); @types[name] = type; end

      # Declares a mechanic of a type (:grid, :state or :facing) from a profile's block (Builder) on a map or several,
      # the same declaration under each id; returns it. A map takes one mechanic per :part: declaring a part again
      # replaces it, and another part stands beside it, each with its own win, line and pieces.
      def self.define(kind, maps, opts = {}, &blk)
        b = Builder.new(kind)
        b.instance_eval(&blk) if blk
        Array(maps).each { |m| declare(m, b.spec, opts[:part]) }
        b.spec
      end

      # Puts a declaration on a map under a part, dropping the map's live instances.
      def self.declare(map_id, spec, part = nil)
        @defs[map_id] = (@defs[map_id] || []).reject { |p, _s| p == part }.push([part, spec])
        forget if @at == map_id
      end

      # The current map's instances, built on the first look at a map that declares a mechanic; none on any other. On
      # such a map the events are synced first, so a new map or a load drops the old instances before they are looked
      # at; they are kept only once whole.
      def self.instances
        m = $game_map
        return NONE unless m
        list = @defs[m.map_id]
        unless list
          forget if @insts
          return NONE
        end
        Events.sync
        mid = m.map_id
        return @insts if @insts && @at == mid
        forget
        built = list.map { |_part, spec| build(spec, mid) }.compact
        @at = mid
        @insts = built
      end

      # The current map's first instance, or nil.
      def self.instance; instances.first; end

      # The instance of a declaration live on the current map, or nil.
      def self.instance_of(spec); instances.find { |inst| inst.spec.equal?(spec) }; end

      # A declaration's instance on a map, its pieces found and its type's state taken; nil for an unknown type.
      def self.build(spec, mid)
        type = @types[spec[:kind]]
        return nil unless type
        inst = Instance.new(spec, spec[:kind], type, mid, {}, controls_of(spec), [], nil, nil)
        resolve(inst)
        type.enter(inst)
        inst
      end

      # One map frame, per instance: its state against the last frame's, each change queued, then whether the player
      # just came beside an obstacle.
      def self.update
        instances.each do |inst|
          current(inst)
          out = []
          inst.type.update(inst, out)
          near(inst, out)
          out.each { |c| @queue.push([inst.spec, c]) }
        end
      end

      # The changes queued since the last call, oldest first, as [declaration, change], a change an array led by its
      # kind.
      def self.drain
        out = @queue
        @queue = []
        out
      end

      # Queues what the player's use of an event says, for each declaration that has a line for it (on_use).
      def self.used(ev)
        instances.each do |inst|
          (inst.spec[:uses] || []).each do |u|
            next unless picks?(u[:events], ev)
            @queue.push([inst.spec, [:use, u.dup.merge!(:label => label_now(u[:label], ev))]])
          end
        end
      end

      # A line's label asked now: a lambda with one parameter gets the event, any other lambda nothing.
      def self.label_now(label, ev)
        return label unless label.respond_to?(:call)
        label.arity == 1 ? label.call(ev) : label.call
      end

      # The entries a verb of the current map's declarations holds for an event.
      def self.entries_for(key, ev)
        instances.map { |inst| (inst.spec[key] || []).select { |e| picks?(e[:events], ev) } }.flatten
      end

      # True when a declaration of the current map says an event is no silent control (not_control). It reads the declarations
      # alone: the events' own facets ask this while they are being read.
      def self.not_control?(ev)
        (@defs[$game_map.map_id] || []).any? do |_part, spec|
          (spec[:not_controls] || []).any? { |what| picks?(what, ev) }
        end
      end

      # The piece an event is on the current map, or nil.
      def self.piece_of(ev)
        return nil unless ev
        instances.each do |inst|
          current(inst)
          hit = inst.pieces.find { |p| p.ev.equal?(ev) }
          return hit if hit
        end
        nil
      end

      # The current map's pieces, all or of one role.
      def self.pieces(role = nil)
        instances.map { |inst| pieces_in(inst, role) }.flatten
      end

      # An instance's pieces, all or of one role.
      def self.pieces_in(inst, role = nil)
        current(inst)
        role ? inst.pieces.select { |p| p.role == role } : inst.pieces
      end

      # Drops the live instances and their queue: a new map, a load, a reset.
      def self.forget
        @insts = nil
        @at = nil
        @queue = []
      end

      # What a verb's events come as, ready for picks?: an id, a range or a list of them as id => true, a pattern as it
      # is.
      def self.picked(what)
        return what if what.is_a?(Regexp)
        out = {}
        [what].flatten.each { |x| (x.is_a?(Range) ? x.to_a : [x]).each { |id| out[id] = true } }
        out
      end

      # True when an event is among those picked: by its id, or a pattern on its name or its graphic.
      def self.picks?(what, ev)
        return what[ev.id] ? true : false unless what.is_a?(Regexp)
        !(ev.name.to_s =~ what).nil? || !(ev.character_name.to_s =~ what).nil?
      end

      # A counter as the types read it: :switches and :selfs ([events, letter]) turned into the watch entries of :flags,
      # out of how many there are unless it says.
      def self.counter(opts)
        c = opts.dup
        flags = (c[:flags] || []).dup
        ids_of(c.delete(:switches)).each { |id| flags.push(:switch => id) } if c[:switches]
        if c[:selfs]
          what, letter, map = c.delete(:selfs)
          ids_of(what).each { |id| flags.push(:self => [id, letter, map].compact) }
        end
        unless flags.empty?
          c[:flags] = flags
          c[:of] ||= flags.length
        end
        c
      end

      # The ids a count reads: a pattern has no events to match while a profile loads.
      def self.ids_of(what)
        raise ArgumentError, "a count takes ids, not a pattern" if what.is_a?(Regexp)
        picked(what).keys
      end

      # True when a profile's lambda answers true; nil and a failing one are false.
      def self.truth(fn, *args)
        fn ? ((fn.call(*args) rescue false) ? true : false) : false
      end

      # Finds the pieces again when an event changed since they were found.
      def self.current(inst)
        resolve(inst) unless inst.gen == Events.gen
      end

      # The pieces among the map's events: obstacles and statues by how they are drawn, a wall only while its page
      # blocks, controls by id while their page can still run, then what a name lists while it is drawn or can run.
      def self.resolve(inst)
        inst.gen = Events.gen
        spec = inst.spec
        obs = spec[:obstacles]
        statue = (spec[:kind] == :facing) ? spec[:match] : nil
        out = []
        ($game_map.events || {}).each do |id, ev|
          cn = (ev.character_name.to_s rescue "")
          hit = obs ? obs.find { |o| takes?(o, ev, cn, (ev.tile_id rescue 0)) } : nil
          hit = nil if hit && hit[:kind] == :wall && walked_through?(ev)
          nm = named_as(inst, ev)
          if hit
            out.push(Piece.new(:obstacle, ev, nm ? nm[0] : hit[:label], hit[:kind] == :mover, !nm.nil?, nm && nm[1]))
          elsif statue && cn =~ statue
            out.push(Piece.new(:statue, ev, nil, false))
          elsif (w = inst.controls[id]) && acts?(ev)
            out.push(Piece.new(:control, ev, nm ? nm[0] : w[:label], false, !nm.nil?, nm && nm[1], nm && nm[2]))
          elsif nm && (!cn.empty? || (ev.tile_id rescue 0).to_i > 0 || acts?(ev))
            out.push(Piece.new(:named, ev, nm[0], false, true, nm[1], nm[2]))
          end
        end
        inst.pieces = out
      end

      # True when an obstacle's entry takes in an event drawn as name and tile: by its graphic, its tile, its id or its
      # own name; never one not drawn.
      def self.takes?(o, ev, name, tile)
        return false if name.empty? && tile.to_i <= 0
        return !(name =~ o[:match]).nil? if o[:match]
        return o[:tile] == tile.to_i if o[:tile]
        return picks?(o[:events], ev) if o[:events]
        o[:named] ? !(ev.name.to_s =~ o[:named]).nil? : false
      end

      # The label, assist flag and test for being listed a declaration's name gives an event, numbered where it asks for
      # that, or nil.
      def self.named_as(inst, ev)
        entry = (inst.spec[:names] || []).find { |n| picks?(n[:events], ev) }
        return nil unless entry
        [label_for(inst, entry, ev), entry[:assist], entry[:when]]
      end

      # A name's label for an event: a lambda with one parameter asked each time it is read, so it follows the flags and the
      # assist; a numbered one with its place added.
      def self.label_for(inst, entry, ev)
        label = entry[:label]
        return lambda { label.call(ev) } if label.respond_to?(:arity) && label.arity == 1
        return label unless entry[:numbered]
        key, opts = label.is_a?(Array) ? label : [label, {}]
        [key, opts.dup.merge!(:n => number_of(inst, entry, ev))]
      end

      # An event's place among those a numbered name picks, in reading order of where the map puts them.
      def self.number_of(inst, entry, ev)
        mine = ($game_map.events || {}).values.select { |e| picks?(entry[:events], e) }
        spots = mine.map do |e|
          raw = PokeAccess.ivar(e, :@event)
          [(raw.y rescue e.y), (raw.x rescue e.x), e.id]
        end
        spots.sort.index { |s| s[2] == ev.id } + 1
      end

      # A test for a phase: the player stands in the box, in map tiles.
      def self.at(x0, x1, y0, y1)
        lambda { me = $game_player; me.x >= x0 && me.x <= x1 && me.y >= y0 && me.y <= y1 }
      end

      # What a phase lists (:hidden) with the assist alone: the events, a tile, rope or door, that go on.
      def self.right_way(*events)
        { :events => events, :label => :puzzle_right_way, :assist => true }
      end

      # True when the event's live page lets the player through: drawn or not, it blocks nothing (spikes drawn lowered).
      def self.walked_through?(ev)
        page = PokeAccess.ivar(ev, :@page)
        page && (page.through rescue false) ? true : false
      end

      # True while the event's current page can run: the engine starts one only with a command besides the closing
      # one, so a single-use control whose page emptied is done.
      def self.acts?(ev)
        list = PokeAccess.ivar(ev, :@list)
        list.is_a?(Array) && list.any? { |cmd| (cmd.code rescue 0) != 0 }
      end

      # The events whose page, fired by the player (action button or touch), writes a flag the declaration watches
      # (event id => the first such watch entry), for a declaration that asks for controls; found once per map: their
      # commands never change. Autorun and parallel controllers are left out.
      def self.controls_of(spec)
        out = {}
        watch = spec[:watch]
        return out unless spec[:controls] && watch && !watch.empty? && $game_map
        ($game_map.events || {}).each do |id, ev|
          rev = PokeAccess.ivar(ev, :@event)
          pages = ((rev && rev.pages) || []).select { |pg| (pg.trigger rescue 5) <= 2 }
          w = watch.find { |e| pages.any? { |pg| writes?(pg, e) } }
          out[id] = w if w
        end
        out
      end

      # True if a page's commands set the switch (121) or variable (122) a watch entry tracks.
      def self.writes?(pg, w)
        ((pg.list rescue nil) || []).any? { |cmd| writing?(cmd, w) }
      end

      # True if one command sets watch entry w's switch (121) or variable (122).
      def self.writing?(cmd, w)
        code = (cmd.code rescue nil)
        pr = (cmd.parameters rescue nil) || []
        id = (code == 121 && w[:switch]) || (code == 122 && w[:var])
        id && pr[0] && pr[1] && id >= pr[0] && id <= pr[1] ? true : false
      end

      # What a page sets watch entry w's switch to, one value per write: true (on) or false (off).
      def self.written(pg, w)
        ((pg.list rescue nil) || []).select { |cmd| writing?(cmd, w) }.map { |cmd| cmd.parameters[2] == 0 }
      end

      # Watch entry w's variable after a page runs, from value: its one write of a constant as written (set, add or take away),
      # any other flipped between 0 and 1, as it is worked out as the page runs.
      def self.var_after(pg, w, value)
        writes = ((pg.list rescue nil) || []).select { |cmd| writing?(cmd, w) }.map { |cmd| cmd.parameters[2, 3] }.uniq
        return value if writes.empty?
        op, kind, n = writes[0]
        return (value >= 1 ? 0 : 1) unless writes.length == 1 && kind == 0 && op <= 2
        [n, value + n, value - n][op].to_i
      end

      # The event's own self switches a page sets (123), as [letter, on] per write.
      def self.self_written(pg)
        ((pg.list rescue nil) || []).select { |cmd| (cmd.code rescue nil) == 123 }.map do |cmd|
          [cmd.parameters[0], cmd.parameters[1] == 0]
        end
      end

      # Queues [:near, pieces] the frame the player comes beside obstacles of a group (their label and whether they
      # move) not beside them the frame before, with those groups' pieces beside them; on arrival too, and again each
      # time after leaving it; an obstacle moving up to a player standing still counts.
      def self.near(inst, out)
        return unless inst.spec[:obstacles]
        px = $game_player.x
        py = $game_player.y
        around = [[px - 1, py], [px + 1, py], [px, py - 1], [px, py + 1]]
        beside = inst.pieces.select { |p| p.role == :obstacle && around.include?([p.ev.x, p.ev.y]) }
        groups = beside.map { |p| group_of(p) }.uniq
        key = [px, py, inst.map_id, groups]
        return if inst.near == key
        was = inst.near ? inst.near[3] : []
        inst.near = key
        fresh = beside.reject { |p| was.include?(group_of(p)) }
        out.push([:near, fresh]) unless fresh.empty?
      end

      # What groups obstacles side by side: their label as it reads now, and whether they move.
      def self.group_of(p); [p.label.respond_to?(:call) ? p.label.call : p.label, p.moving]; end
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::World::Mechanics.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Mechanics.forget }
