module PokeAccess
  module World
    # The map's mechanics (its puzzles): the definitions declared per map, the live instance on the current map, its
    # pieces (obstacles and statues by their graphic, controls by the flags their pages write), the state it watches,
    # and each frame's changes, queued for Puzzles to say. Built silently at the first look, it never speaks itself.
    module Mechanics
      # A piece found on the map: its role (:obstacle, :control or :statue), its event, its label (a control's watch
      # label, an obstacle's declared one) and whether an obstacle moves.
      Piece = Struct.new(:role, :ev, :label, :moving)
      # The mechanic live on the current map: its declaration, its kind (:grid, :state or :facing) and type module, the
      # map, the type's own state, the controls found once (event id => watch entry), the pieces and the event
      # generation they were found at.
      Instance = Struct.new(:spec, :kind, :type, :map_id, :data, :controls, :pieces, :gen)

      @defs = {}
      @types = {}
      @inst = nil
      @queue = []
      @near = nil

      # Registers a mechanic type under its name: a module answering enter(inst) and update(inst, out).
      def self.register_type(name, type); @types[name] = type; end

      # Declares a mechanic of a type (:grid, :state or :facing) from a profile's block (Builder) on a map or several,
      # the same declaration under each id; returns it.
      def self.define(kind, maps, &blk)
        b = Builder.new(kind)
        b.instance_eval(&blk) if blk
        Array(maps).each { |m| declare(m, b.spec) }
        b.spec
      end

      # Puts a declaration on a map, dropping the map's live instance.
      def self.declare(map_id, spec)
        @defs[map_id] = spec
        forget if @inst && @inst.map_id == map_id
      end

      # The declaration of a map's mechanic, the current map's by default, or nil.
      def self.declared(map_id = ($game_map ? $game_map.map_id : nil)); @defs[map_id]; end

      # The current map's instance, built on the first look at a map that declares a mechanic, or nil. On such a map
      # the events are synced first, so a new map or a load drops the old instance before it is looked at; an
      # instance is kept only once whole.
      def self.instance
        m = $game_map
        return nil unless m
        spec = @defs[m.map_id]
        unless spec
          forget if @inst
          return nil
        end
        Events.sync
        mid = m.map_id
        return @inst if @inst && @inst.map_id == mid
        forget
        kind = spec[:kind]
        type = @types[kind]
        return nil unless type
        inst = Instance.new(spec, kind, type, mid, {}, controls_of(spec), [], nil)
        resolve(inst)
        type.enter(inst)
        @inst = inst
      end

      # One map frame: the instance's state against the last frame's, each change queued, then whether the player
      # just came beside an obstacle.
      def self.update
        inst = instance
        return unless inst
        current(inst)
        inst.type.update(inst, @queue)
        near(inst)
      end

      # The changes queued since the last call, as arrays led by their kind, oldest first.
      def self.drain
        out = @queue
        @queue = []
        out
      end

      # The piece an event is on the current map, or nil.
      def self.piece_of(ev)
        inst = instance
        return nil unless inst && ev
        current(inst)
        inst.pieces.find { |p| p.ev.equal?(ev) }
      end

      # The current map's pieces, all or of one role.
      def self.pieces(role = nil)
        inst = instance
        return [] unless inst
        current(inst)
        role ? inst.pieces.select { |p| p.role == role } : inst.pieces
      end

      # Drops the live instance, its queue and the obstacle watch: a new map, a load, a reset.
      def self.forget
        @inst = nil
        @queue = []
        @near = nil
      end

      # True when a profile's lambda answers true; nil and a failing one are false.
      def self.truth(fn, *args)
        fn ? ((fn.call(*args) rescue false) ? true : false) : false
      end

      # Finds the pieces again when an event changed since they were found.
      def self.current(inst)
        resolve(inst) unless inst.gen == Events.gen
      end

      # The pieces among the map's events: obstacles and statues by their graphic, controls by id while their page can
      # still run.
      def self.resolve(inst)
        inst.gen = Events.gen
        spec = inst.spec
        obs = spec[:obstacles]
        statue = (spec[:kind] == :facing) ? spec[:match] : nil
        out = []
        ($game_map.events || {}).each do |id, ev|
          cn = (ev.character_name.to_s rescue "")
          hit = (obs && !cn.empty?) ? obs.find { |o| cn =~ o[:match] } : nil
          if hit
            out.push(Piece.new(:obstacle, ev, hit[:label], hit[:kind] == :mover))
          elsif statue && cn =~ statue
            out.push(Piece.new(:statue, ev, nil, false))
          elsif (w = inst.controls[id]) && acts?(ev)
            out.push(Piece.new(:control, ev, w[:label], false))
          end
        end
        inst.pieces = out
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

      # What a page sets watch entry w's flag to, one value per write: true (on), false (off), or nil for one worked out
      # as it runs (a variable added to, or set from another).
      def self.written(pg, w)
        out = []
        ((pg.list rescue nil) || []).each do |cmd|
          next unless writing?(cmd, w)
          pr = cmd.parameters
          out.push(cmd.code == 121 ? pr[2] == 0 : (pr[2] == 0 && pr[3] == 0 ? pr[4].to_i >= 1 : nil))
        end
        out
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
      def self.near(inst)
        return unless inst.spec[:obstacles]
        px = $game_player.x
        py = $game_player.y
        around = [[px - 1, py], [px + 1, py], [px, py - 1], [px, py + 1]]
        beside = inst.pieces.select { |p| p.role == :obstacle && around.include?([p.ev.x, p.ev.y]) }
        groups = beside.map { |p| [p.label, p.moving] }.uniq
        key = [px, py, inst.map_id, groups]
        return if @near == key
        was = @near ? @near[3] : []
        @near = key
        fresh = beside.reject { |p| was.include?([p.label, p.moving]) }
        @queue.push([:near, fresh]) unless fresh.empty?
      end
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::World::Mechanics.forget }
PokeAccess::World::Epoch.on(:reset) { PokeAccess::World::Mechanics.forget }
