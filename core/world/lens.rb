module PokeAccess
  module World
    # Drimer's "Eye/Lens of Truth for Essentials", as the copies of it run: Z's, on a timer that Scene_Map counts down
    # (eye_of_truth_time); Edas' and Perseida's, a flag of Scene_Map the player raises and lowers (eye_of_truth); Vitro's,
    # LensOfTruth.active?, turned on and off with the Dowsing Machine. While it is in use, each event it marks within its
    # RANGE of the player turns: a HIDE one goes through and a SHOW one stops being through; out of reach or with the lens
    # down, the other way round. The routes take the lens in use as reaching every event they pass, since a route always
    # passes beside them (posed), up to where it would be down again (renew_cut); with the puzzle assist and the lens
    # down, a route may cross what it opens, or end at a SHOW event, by using the lens there (gate_at, show_cut).
    module Lens
      # The comments the Perseida and Vitro copies also mark an event by, read as pbEventCommentInput reads them.
      COMMENTS = { "hideEvent" => :hide, "showEvent" => :show }
      # The frames a walking step takes at 40 frames a second (move speed 4), what Z's timer runs down by.
      FRAMES_PER_TILE = 8

      @index = nil
      @bridges = nil
      @declared = {}
      @bare = false

      # Drops the map's index of marked events.
      def self.forget
        @index = nil
        @bridges = nil
      end

      # What a profile tells of its game's copy, where the script does not say it: :name, the i18n key of a lens no item
      # works (a power the story gives); :usable, a lambda answering whether the player can use it now (true, false or
      # nil); :comments, true when the copy also reads hideEvent and showEvent comments; :ends_on_events, true when any
      # event that runs puts it down, or a lambda answering it as things stand. nil forgets them.
      def self.declare(opts)
        @declared = opts ? opts.dup : {}
      end

      # True when the game runs a copy of the script.
      def self.present?
        Object.const_defined?(:LensOfTruth)
      end

      # True for Z's copy, on a timer: it wears off by itself and cannot be put away.
      def self.timed?
        s = $scene
        s.is_a?(::Scene_Map) ? s.respond_to?(:eye_of_truth_time) : ::Scene_Map.method_defined?(:eye_of_truth_time)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # True for Vitro's copy, kept by LensOfTruth.active?.
      def self.toggled?
        present? && ::LensOfTruth.respond_to?(:active?)
      end

      # True while the lens is in use: Vitro's LensOfTruth.active?, else what Scene_Map keeps (scene_on?).
      def self.on?
        return (::LensOfTruth.active? ? true : false) if toggled?
        scene_on?
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # True while Scene_Map keeps the lens in use: Z's timer counting down, or the flag of Edas' and Perseida's copies.
      def self.scene_on?
        s = $scene
        return false unless s.is_a?(::Scene_Map)
        return s.eye_of_truth_time.to_i > 0 if s.respond_to?(:eye_of_truth_time)
        s.respond_to?(:eye_of_truth) && s.eye_of_truth == true
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # How far the lens reaches from the player, in tiles: the copy's RANGE as it reads it (RANGE % 5).
      def self.range
        (::LensOfTruth::RANGE.to_i % 5)
      rescue StandardError => e
        PokeAccess.swallowed(e)
        3
      end

      # :hide, :show or nil: what the lens does to ev, as the copy reads it. Z's takes "#EOT" in the name and Edas',
      # Perseida's and Vitro's "EOT" (a game without the script, "#EOT"); then HIDE in it, or a hideEvent comment where
      # the copy reads them (comments?), before SHOW or a showEvent comment.
      def self.kind(ev)
        name = (ev.name.to_s rescue "")
        return nil unless name =~ (present? && !timed? ? /EOT/ : /#EOT/)
        said = comments? ? commented(ev) : nil
        return :hide if name =~ /HIDE/ || said == :hide
        return :show if name =~ /SHOW/ || said == :show
        nil
      end

      # True when the copy reads comments too: Vitro's, or one a profile declares so.
      def self.comments?
        (toggled? || @declared[:comments]) ? true : false
      end

      # The kind the first hideEvent or showEvent comment on ev's page gives it, a comment line (108) or its continuation
      # (408) equal to it, or nil.
      def self.commented(ev)
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array)
        list.each do |c|
          code = (c.code rescue 0)
          next unless code == 108 || code == 408
          k = COMMENTS[(c.parameters[0] rescue nil)]
          return k if k
        end
        nil
      end

      # True while the lens reaches ev: in use, and ev within its range of the player, as the copy's InRange? measures.
      def self.reaches?(ev)
        pl = $game_player
        on? && Math.hypot(ev.x - pl.x, ev.y - pl.y) <= range
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # The map's marked events by tile: key => [[event, kind], ...], taken again whenever the events change.
      def self.index
        return nil unless present?
        stamp = [($game_map.map_id rescue 0), Events.gen]
        return @index[1] if @index && @index[0] == stamp
        idx = {}
        Events.records.each do |r|
          k = kind(r.ev)
          next unless k
          r.tiles.each { |x, y| (idx[Events.key(x, y)] ||= []).push([r.ev, k]) }
        end
        @index = [stamp, idx]
        @bridges = nil
        idx
      end

      # The map's marked events, each once, with their kinds: [[event, kind], ...].
      def self.events
        idx = index
        idx ? idx.values.flatten(1).uniq : []
      end

      # The first event of kind k on (x,y), or nil.
      def self.event_at(x, y, k)
        idx = index
        hit = idx && idx[Events.key(x, y)]
        pair = hit && hit.find { |_ev, kk| kk == k }
        pair && pair[0]
      end

      # True when a marked event stands on (x,y).
      def self.marked_at?(x, y)
        idx = index
        idx && idx[Events.key(x, y)] ? true : false
      end

      # True when a SHOW event is all that lets the player stand on its tile on foot: with it through, as the lens down
      # leaves it, the map's own tile there takes no step, or is water (a bridge the lens lays). Kept with the index.
      def self.bridge?(ev)
        @bridges ||= {}
        k = ev.object_id
        return @bridges[k] unless @bridges[k].nil?
        was = (ev.through rescue false)
        begin
          (ev.through = true) rescue nil
          wet = (Terrain.cell(ev.x, ev.y) & Terrain::SURF) != 0
          @bridges[k] = wet || !($game_map.passable?(ev.x, ev.y, 0) rescue true)
        ensure
          (ev.through = was) rescue nil
        end
      end

      # True when (x,y) holds what only the lens lets the player stand on: a HIDE event, or a SHOW one that is a bridge.
      def self.lensed_at?(x, y)
        idx = index
        hit = idx && idx[Events.key(x, y)]
        hit ? hit.any? { |ev, k| k == :hide || bridge?(ev) } : false
      end

      # Runs the engine's question about the step from (x,y) toward d (onto (x,y) itself without a way, as a jump's
      # landing) with the marked events on its tiles as a route passing them finds them while the lens is in use, each
      # HIDE one through and each SHOW one not: a SHOW one turns as the player comes within reach, before stepping on,
      # and stays so beneath them. Events lent (lent, the Probe's tiles) are left so. Anything else asks as it stands.
      def self.posed(x, y, d, lent)
        idx = on? && !@bare ? index : nil
        return yield if idx.nil? || idx.empty?
        dd = PokeAccess::DIR_DELTA[d]
        saved = []
        seen = {}
        begin
          pose(idx, x, y, lent, saved, seen)
          pose(idx, x + dd[0], y + dd[1], lent, saved, seen) if dd
          yield
        ensure
          saved.reverse_each { |ev, t| (ev.through = t) rescue nil }
        end
      end

      # Sets the through flag of the marked events on (x,y) as posed takes them, keeping each one's own in saved, once
      # (seen) for an event on both tiles.
      def self.pose(idx, x, y, lent, saved, seen)
        k = Events.key(x, y)
        hit = idx[k]
        return if hit.nil? || (lent && lent[k])
        hit.each do |ev, kind|
          next if seen[ev.object_id]
          seen[ev.object_id] = true
          saved.push([ev, (ev.through rescue false)])
          (ev.through = (kind == :hide)) rescue nil
        end
      end

      # Runs the block, a read of what ev does (Routes::Effects.fires_on_arrival?), with ev as posed has a route meet it
      # while the lens is in use, the lens's state noted for the facet read (Flags.lens).
      def self.met(ev)
        k = kind(ev)
        return yield if k.nil?
        Flags.lens
        return yield unless on?
        was = (ev.through rescue false)
        begin
          (ev.through = (k == :hide)) rescue nil
          yield
        ensure
          (ev.through = was) rescue nil
        end
      end

      # True when an assisted route may use the lens: the puzzle assist on, the lens down and a marked event on the map.
      def self.assisting?
        return false unless PokeAccess::Puzzles.assist? && present? && !on?
        idx = index
        idx && !idx.empty? ? true : false
      end

      # The marked events an assisted search lends to the engine (Pathfinder.with_gates_open): [[event, through], ...],
      # each HIDE one through as the lens in use leaves it, and a SHOW bridge not through. Any other SHOW one stays through,
      # as the way up to the lens is walked with it down.
      def self.lent
        return [] unless assisting?
        out = []
        events.each do |ev, k|
          if k == :hide then out.push([ev, true])
          elsif bridge?(ev) then out.push([ev, false])
          end
        end
        out
      end

      # The gate of a step of an assisted search onto (x,y) facing d: using the lens, where the step goes onto a marked
      # event from the player's tile or from ground the lens does not lay (a row of HIDE events or of bridges costs one
      # use) and the lens down would not let it (open_unaided?); nil anywhere else.
      def self.gate_at(x, y, d)
        return nil unless assisting?
        hit = index[Events.key(x, y)]
        dd = PokeAccess::DIR_DELTA[d]
        return nil if hit.nil? || dd.nil?
        ox = x - dd[0]
        oy = y - dd[1]
        pl = $game_player
        row = !(ox == pl.x && oy == pl.y) && lensed_at?(ox, oy)
        return nil if row || open_unaided?(hit, ox, oy, d)
        gate(hit[0][0], x, y)
      end

      # The gate of using the lens before ev on (x,y).
      def self.gate(ev, x, y)
        { :kind => :lens, :label => :loc_lens, :ev => ev, :x => x, :y => y }
      end

      # True when the engine takes the step from (ox,oy) toward d with the marked events ahead, hit, as the lens down
      # leaves them, a HIDE one in the way and a SHOW one passed over, and nothing posed (bare).
      def self.open_unaided?(hit, ox, oy, d)
        saved = hit.map { |ev, _k| [ev, (ev.through rescue false)] }
        was = @bare
        begin
          @bare = true
          hit.each { |ev, k| (ev.through = (k == :show)) rescue nil }
          Probe.engine(ox, oy, d) == Probe::OPEN
        ensure
          @bare = was
          saved.reverse_each { |ev, t| (ev.through = t) rescue nil }
        end
      end

      # A walk to a SHOW event at (tx,ty) the lens is down for, as [presses, gate] for the assisted plan: the route up
      # to the press that would step onto it, and the gate there with :show. nil without the puzzle assist or such an
      # event.
      def self.show_cut(route, tx, ty)
        return nil unless assisting?
        ev = event_at(tx, ty, :show)
        return nil if ev.nil?
        n = traced(route).index { |p| p.x == tx && p.y == ty } || route.length
        g = gate(ev, tx, ty)
        g[:show] = true
        [PokeAccess::Pathfinder.head_of(route, n), g]
      end

      # A walk taken with the lens in use, cut as [presses, gate] before its first press onto what only the lens lets it
      # take once the lens is down again: past what is left of Z's timer (FRAMES_PER_TILE a press), or after a press
      # onto an event that runs, in a copy that any running event puts down (ends_on_events?). nil when the lens lasts.
      def self.renew_cut(route)
        return nil unless present? && on?
        idx = index
        return nil if idx.nil? || idx.empty?
        left = timed? ? ($scene.eye_of_truth_time.to_i rescue 0) : nil
        ends = ends_on_events?
        return nil if left.nil? && !ends
        pl = $game_player
        ox = pl.x
        oy = pl.y
        down = false
        traced(route).each_with_index do |p, i|
          down ||= !left.nil? && i * FRAMES_PER_TILE >= left
          hit = idx[Events.key(p.x, p.y)]
          if down && hit && !open_unaided?(hit, ox, oy, route[i])
            return [PokeAccess::Pathfinder.head_of(route, i), gate(hit[0][0], p.x, p.y)]
          end
          down ||= ends && runs_at?(p.x, p.y)
          ox = p.x
          oy = p.y
        end
        nil
      end

      # The frames of Z's lens in use a route needs left, up to its last press onto what only the lens lets it take
      # (FRAMES_PER_TILE a press, as renew_cut counts them), for a plan kept to last while they are (Planner.keep);
      # nil for a route that needs none, or with no timer running.
      def self.frames_needed(route)
        return nil unless route && present? && timed? && on?
        idx = index
        return nil if idx.nil? || idx.empty?
        pl = $game_player
        ox = pl.x
        oy = pl.y
        last = nil
        traced(route).each_with_index do |p, i|
          hit = idx[Events.key(p.x, p.y)]
          last = i if hit && !open_unaided?(hit, ox, oy, route[i])
          ox = p.x
          oy = p.y
        end
        last ? last * FRAMES_PER_TILE + 1 : nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # True while a kept plan that needs frames of Z's lens (frames_needed) still has them, or needs none.
      def self.lasts?(frames)
        frames.nil? || ($scene.eye_of_truth_time.to_i rescue 0) >= frames
      end

      # True when any event that runs puts the lens down: Vitro's copy (AUTO_DEACTIVATE_ON_EVENTS), or one a profile
      # declares so.
      def self.ends_on_events?
        v = @declared[:ends_on_events]
        v = v.call if v.respond_to?(:call)
        return true if v
        return false unless toggled? && ::LensOfTruth.const_defined?(:AUTO_DEACTIVATE_ON_EVENTS)
        ::LensOfTruth::AUTO_DEACTIVATE_ON_EVENTS ? true : false
      end

      # True when stepping onto (x,y) starts an event: a touch event there with something on its page.
      def self.runs_at?(x, y)
        Events.at(x, y).any? do |r|
          list = PokeAccess.ivar(r.ev, :@list)
          (r.trigger == 1 || r.trigger == 2) && list.is_a?(Array) && list.any? { |c| (c.code rescue 0) != 0 }
        end
      end

      # A route replayed from the player as the guide replays it.
      def self.traced(route)
        pf = PokeAccess::Pathfinder
        PokeAccess::Routes::Moves.trace($game_player.x, $game_player.y, pf.bridge_level, route, pf.replay_mode)
      end

      # The item that works the lens, or nil for a copy worked by none (a power the story gives, or one a profile names,
      # declare): the Dowsing Machine for Vitro's, LENSOFTRUTH where the game has it.
      def self.item
        return nil if @declared[:name]
        return :DOWSINGMACHINE if toggled?
        (PokeAccess::Data.item_id(:LENSOFTRUTH)[0] rescue nil) ? :LENSOFTRUTH : nil
      end

      # The lens as the game names it: the profile's word (declare), its item, else the core's word (lens_name).
      def self.item_name
        return PokeAccess::I18n.t(@declared[:name]) if @declared[:name]
        it = item
        it ? PokeAccess::FieldMoves.item_name(it) : PokeAccess::I18n.t(:lens_name)
      end

      # true / false / nil: whether the player can use the lens now, as the profile tells (declare), else by its item in
      # the bag; nil with neither to tell.
      def self.usable?
        u = @declared[:usable]
        if u
          v = u.call
          return v.nil? ? nil : (v ? true : false)
        end
        it = item
        it ? PokeAccess::FieldMoves.bag_has?(it) : nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end
    end
  end
end

PokeAccess::World::Probe.mode_reader { PokeAccess::World::Lens.on? }
PokeAccess::Caches.register(:lens) { PokeAccess::World::Lens.forget }
