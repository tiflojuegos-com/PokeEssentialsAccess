module PokeAccess
  module Routes
    # Platforms that carry the player between stops as they run by themselves (a lift): an event with a page the engine
    # runs at once (autorun or parallel) that moves them with Through on when the player stands on a tile it tests. Each
    # stop is ground the platform lays as it rests there (grounded), and arriving on a stop it leaves from rides to the
    # other one.
    module Rides
      # The triggers of a page the engine runs as soon as it shows.
      AT_ONCE = [3, 4]

      @machine = nil

      # One event's :ride facet, for Effects.touch_index: pkey of each stop => [true, its carry for every facing (none
      # on a stop it only arrives at), :ride, the platform, x, y]; nil for an event that carries no one so.
      def self.facet(r)
        rides = rides_of(r.ev)
        return nil if rides.empty?
        out = {}
        rides.each do |ax, ay, bx, by|
          c = [:carry, bx - ax, by - ay, false, nil, nil, true]
          out[Routes.pkey(ax, ay)] ||= [true, { 2 => c, 4 => c, 6 => c, 8 => c }, :ride, r.ev, ax, ay]
        end
        rides.each { |_ax, _ay, bx, by| out[Routes.pkey(bx, by)] ||= [true, {}, :ride, r.ev, bx, by] }
        out
      end

      # The rides of event ev as [stop x, stop y, x, y it lands the player on], from each page its running reaches.
      def self.rides_of(ev)
        pages = (PokeAccess.ivar(ev, :@event).pages rescue nil)
        return [] unless pages.is_a?(Array)
        live = pages.index(PokeAccess.ivar(ev, :@page))
        out = []
        pages.each_with_index do |pg, i|
          out.concat(page_rides(pg, ev)) if reachable?(pages, i, live)
        end
        out.uniq
      end

      # The rides of one page of event ev, as rides_of gives them; none for a page the engine does not run at once.
      def self.page_rides(pg, ev)
        return [] unless pg && AT_ONCE.include?((pg.trigger rescue 0).to_i)
        list = (pg.list rescue nil)
        return [] unless list.is_a?(Array)
        out = []
        Effects.place_tests(list, -1).map { |x, y, _i| [x, y] }.uniq.each do |x, y|
          o = PokeAccess::EventPages.walk(list, 2, ev, [x, y])
          next unless o && o.move && o.through && !o.talks && !o.transfer && !o.unknown && !o.battle
          out.push([x, y, x + o.move[0], y + o.move[1]])
        end
        out
      end

      # True when the event's own running may show page i of pages, live the one shown now: it is that one, or every
      # page between them can turn off (a condition the map's machines set) and page i can turn on.
      def self.reachable?(pages, i, live)
        return true if i == live
        return false unless runs?(pages[i])
        return true if live.nil? || i > live
        ((i + 1)..live).all? { |j| conditioned?(pages[j]) && runs?(pages[j]) }
      end

      # True when a page's conditions are none but variables the map's at-once pages set (machine_vars).
      def self.runs?(pg)
        c = (pg.condition rescue nil)
        return true unless c
        return false if (c.switch1_valid rescue false) || (c.switch2_valid rescue false) || (c.self_switch_valid rescue false)
        !(c.variable_valid rescue false) || machine_vars[c.variable_id.to_i]
      end

      def self.conditioned?(pg)
        c = (pg.condition rescue nil)
        return false unless c
        [:switch1_valid, :switch2_valid, :variable_valid, :self_switch_valid].any? { |m| (c.send(m) rescue false) }
      end

      # Forgets the variables read for the map (machine_vars).
      def self.forget; @machine = nil; @waiting = nil; end

      # The variables a page the engine runs at once sets on this map, as id => true, read once a map.
      def self.machine_vars
        key = [($game_map.map_id rescue nil), ($game_map.events rescue nil).object_id]
        return @machine[1] if @machine && @machine[0] == key
        vars = {}
        (($game_map.events rescue nil) || {}).each_value do |ev|
          ((PokeAccess.ivar(ev, :@event).pages rescue nil) || []).each do |pg|
            next unless AT_ONCE.include?((pg.trigger rescue 0).to_i)
            ((pg.list rescue nil) || []).each do |c|
              next unless (c.code rescue 0) == 122
              (c.parameters[0].to_i..c.parameters[1].to_i).each { |id| vars[id] = true }
            end
          end
        end
        @machine = [key, vars]
        vars
      end

      # Runs the block with the platform of each ride stop given (Effects.touch_index entries, nil for none) resting on
      # it.
      def self.grounded(here, there, &blk)
        stops = [here, there].select { |t| t && t[2] == :ride }
        lay(stops, &blk)
      end

      # Runs the block with each stop's platform posed on it, one within the other.
      def self.lay(stops, &blk)
        return yield if stops.empty?
        t = stops[0]
        PokeAccess::World::Probe.grounding(t[3], t[4], t[5]) { lay(stops[1..-1], &blk) }
      end

      # The presses of a route looked through for a step back onto the stop the player waits on (waiting?).
      BACK = 4

      # True while the player stands on a stop the platform rests on and leaves from by the page it shows now, and the
      # presses left step off it and back on within BACK: the platform takes them off as it sets out, so the guide
      # waits.
      def self.waiting?(left)
        return false if left.nil? || left.empty?
        p = $game_player
        here = Routes.pkey(p.x, p.y)
        t = Effects.touch_index[here]
        return false unless t && t[2] == :ride && !t[1].empty? && t[3].x == p.x && t[3].y == p.y
        page = PokeAccess.ivar(t[3], :@page)
        key = [($game_map.map_id rescue nil), here, page.object_id, PokeAccess::Pathfinder.bridge_level, left[0, BACK]]
        return @waiting[1] if @waiting && @waiting[0] == key
        @waiting = [key, waits_on?(page, t[3], p, here, left)]
        @waiting[1]
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Whether the platform leaves the player's tile by its page and the presses left step off the stop and back on
      # (waiting?).
      def self.waits_on?(page, platform, p, here, left)
        rides = page_rides(page, platform)
        return false unless rides.any? { |ax, ay, _bx, _by| ax == p.x && ay == p.y }
        pf = PokeAccess::Pathfinder
        pts = Moves.trace(p.x, p.y, pf.bridge_level, left[0, BACK], pf.replay_mode)
        pts.any? { |s| s.entry == here || (s.x == p.x && s.y == p.y) }
      end

      # Where a ride that lands on (x,y) leaves the player: that stop, with its platform resting on it, when some step
      # off it is open; nil otherwise.
      def self.landing(x, y)
        t = Effects.touch_index[Routes.pkey(x, y)]
        return PokeAccess::World::Probe.landing(x, y) unless t && t[2] == :ride
        PokeAccess::World::Probe.grounding(t[3], x, y) { PokeAccess::World::Probe.landing(x, y) }
      end
    end
  end
end

PokeAccess::World::Events.facet_provider(:ride) { |r| PokeAccess::Routes::Rides.facet(r) }
PokeAccess::Caches.register(:rides) { PokeAccess::Routes::Rides.forget }
