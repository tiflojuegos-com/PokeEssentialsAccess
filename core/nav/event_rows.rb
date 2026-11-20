module PokeAccess
  # Rows of neighbouring events of one kind that run the same page (a scene's trigger tiles, a healing floor wider than
  # a tile): the locator lists each row as one target (Locator.cluster_rows) and the sonar sounds it from its middle
  # tile. Each kind registers which events belong to it.
  module EventRows
    @kinds = {}

    # Registers a kind by the events that belong to it.
    def self.kind(name, &member)
      @kinds[name] = member
    end

    # The rows of a kind on the map, each the event ids of neighbouring members (eight ways) that run the same page,
    # kept until an event changes.
    def self.groups(name)
      PokeAccess::World::Events.summary(("rows_" + name.to_s).to_sym) do
        member = @kinds[name]
        evs = member ? PokeAccess::World::Events.records.map { |r| r.ev }.select { |ev| (member.call(ev) rescue false) } : []
        sigs = evs.map { |ev| signature(ev) }
        PokeAccess::Util.union_groups(evs.length) do |a, b|
          sigs[a] == sigs[b] && (evs[a].x - evs[b].x).abs <= 1 && (evs[a].y - evs[b].y).abs <= 1
        end.map { |idxs| idxs.map { |i| evs[i].id } }
      end
    end

    # The event ids of the row an event belongs to, itself alone when it is in none.
    def self.group_of(name, ev)
      groups(name).detect { |g| g.include?(ev.id) } || [ev.id]
    end

    # Whether an event is the one its row sounds from: the middle tile, by place along the row, of those the player
    # has not hidden.
    def self.lead?(name, ev)
      ids = group_of(name, ev)
      return true if ids.length == 1
      tiles = ids.map { |id| $game_map.events[id] }.compact.reject { |e| (PokeAccess::Locator.hidden?(e) rescue false) }
      tiles = tiles.sort_by { |e| [e.x, e.y] }
      !tiles.empty? && tiles[(tiles.length - 1) / 2].equal?(ev)
    end

    # The page an event runs as something to compare: each command's code and indent, and its parameters that are
    # plain values (an object such as a move route by its class).
    def self.signature(ev)
      list = PokeAccess.ivar(ev, :@list) || []
      list.map { |c| [c.code, c.indent, plain((c.parameters rescue []))] }
    end

    # A value with every object that is not a plain value in it replaced by its class name.
    def self.plain(v)
      case v
      when Array then v.map { |x| plain(x) }
      when String, Symbol, Integer, Float, TrueClass, FalseClass, NilClass then v
      else v.class.name
      end
    end
  end
end
