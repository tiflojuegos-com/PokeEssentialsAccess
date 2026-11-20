module PokeAccess
  # What the free camera says (Camera): a step's line at the camera_step reading's level, what stops it, the map's edge,
  # the info and coordinates keys' lines while it is open, and the line a fixed trail is said with.
  module CameraText
    # What stands on (x, y), each said once: the names of its events the locator lists, its marker, the camera's targets
    # there and what the tile readers say (Camera.tile_reader).
    def self.parts(x, y)
      out = []
      PokeAccess::World::Events.at(x, y).each do |rec|
        out.push(PokeAccess::Locator.target_name(rec.ev).to_s) if listed?(rec.ev)
      end
      mark = $game_map ? (PokeAccess::Marks.get($game_map.map_id, x, y) rescue nil) : nil
      out.push(mark.to_s) if mark
      PokeAccess::Camera.targets.each { |t| out.push(t.name.to_s) if t.x == x && t.y == y }
      out.concat(PokeAccess::Camera.tile_lines(x, y))
      out.reject { |s| s.empty? }.uniq
    end

    # Whether the locator would list an event: something to locate, not hidden by the player nor by a puzzle.
    def self.listed?(ev)
      loc = PokeAccess::Locator
      loc.in_category?(ev, :all) && !loc.tag_hidden?(ev) && !loc.hidden?(ev)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The line of a camera step onto (x, y) from the tile from, whose ground was prev: what stands there and what the
    # player's move st that way does (brief; st nil when said already), that a crossed tile cannot be stood on, or is
    # shut from that side only where a step from another is open, as the info key tells it (brief), the ground where
    # it changes (medium), and that the player cannot get there on foot (full).
    def self.step_line(x, y, from, prev, st, d, crossed)
      t = PokeAccess::I18n
      parts = parts(x, y).map { |p| [p, :brief] }
      fx = effect(from, st, d)
      parts.push([fx, :brief]) if fx
      standable = !crossed || standable?(x, y)
      parts.push([t.t(standable ? :cam_shut_side : :cam_unstandable), :brief]) if crossed
      label = ground(x, y, standable)
      parts.push([t.t(label), :medium]) if label && label != prev
      parts.push([t.t(:cam_unreachable), :full]) if standable && reach(x, y) == :no
      PokeAccess::Verbosity.line(:camera_step, parts)
    end

    # What a move st pressed from the tile from toward d does past a plain step: a jump, a slide or a ride and where it
    # ends from the tile left, a teleport; nil for a plain step or none.
    def self.effect(from, st, d)
      return nil unless st && from
      case st.kind
      when :jump then PokeAccess::Routes::Text.jump(d)
      when :slide, :carry, :run
        PokeAccess::I18n.t(:cam_slide, :where => PokeAccess::Locator.dir_phrase(st.x - from[0], st.y - from[1]))
      when :warp then PokeAccess::I18n.t(:cam_warp)
      end
    end

    # Whether the player can get to (x, y) on foot as the regions tell so far, unwalked: :yes, :no or :unknown.
    def self.reach(x, y)
      s = PokeAccess::Routes::Planner.reach(PokeAccess::Routes::Goal.onto(x, y), false)[0]
      s == :yes || s == :no ? s : :unknown
    rescue StandardError => e
      PokeAccess.swallowed(e)
      :unknown
    end

    # Whether the player could stand on (x, y): a step into it from a tile beside it is open.
    def self.standable?(x, y)
      PokeAccess::Sound::Scene.standable?(nil, nil, x, y)
    end

    # What stops the camera at (x, y): what stands there, else its ground (water, or that of a tile shut from this
    # side), else a wall.
    def self.blocked_line(x, y)
      p = parts(x, y)
      return p.join(", ") unless p.empty?
      PokeAccess::I18n.t(ground(x, y, standable?(x, y)) || :cam_wall)
    end

    # That the action button gets the player on from (x, y) facing d where walking stops, as the routes take it (an
    # event in front, or under the player, that carries them past, as a climb on a mount), else nil.
    def self.act_line(x, y, d)
      dd = PokeAccess::DIR_DELTA[d]
      fx = PokeAccess::Routes::Effects
      e = fx.act_at(x + dd[0], y + dd[1], d, false) || fx.act_at(x, y, d, true)
      e ? PokeAccess::I18n.t(:loc_act_route) : nil
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The surface of (x, y) as the camera names it: a place to dive or come up (Locator.dive_ground), else its label.
    def self.surface(x, y)
      PokeAccess::Locator.dive_ground(x, y) || PokeAccess::World::Terrain.label(x, y)
    end

    # The surface said for (x, y): its surface, but on a tile the player cannot stand on only what a surf crosses
    # (Terrain.liquid?), as the tag of a wall is no ground to walk.
    def self.ground(x, y, standable)
      label = surface(x, y)
      label && (standable || PokeAccess::World::Terrain.liquid?(x, y)) ? label : nil
    end

    # The map's edge past (x, y) toward d, with the map it leads on to where a step off it is open there.
    def self.edge_line(x, y, d)
      PokeAccess::Locator.connection_edges.each do |dest, tiles|
        next unless tiles.any? { |e| e[0] == x && e[1] == y && e[2] == d }
        name = (PokeAccess::Locator.map_name(dest) rescue nil).to_s
        return PokeAccess::I18n.t(:cam_edge_to, :map => name) unless name.empty?
      end
      PokeAccess::I18n.t(:cam_edge)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      PokeAccess::I18n.t(:cam_edge)
    end

    # Where (x, y) lies from the player: "3 left, 2 up of the player", or on them.
    def self.from_player(x, y)
      return nil unless $game_player
      dx = x - $game_player.x
      dy = y - $game_player.y
      return PokeAccess::I18n.t(:cam_at_player) if dx == 0 && dy == 0
      PokeAccess::I18n.t(:cam_from_player, :dirs => PokeAccess::Locator.dir_phrase(dx, dy))
    end

    # The info key's line on the camera's tile (x, y): its coordinates, its ground, what stands there, whether the
    # player can stand on it and get there on foot, and where it lies from them.
    def self.tile_line(x, y)
      t = PokeAccess::I18n
      standable = standable?(x, y)
      label = ground(x, y, standable)
      out = [PokeAccess::Locator.coords_text(x, y)]
      out.push(t.t(label)) if label
      out.concat(parts(x, y))
      if standable
        out.push(t.t({ :yes => :cam_reachable, :no => :cam_unreachable }[reach(x, y)] || :cam_reach_unknown))
      else
        out.push(t.t(:cam_unstandable))
      end
      out.push(from_player(x, y))
      out.compact.join(", ")
    end

    # The coordinates key's line while the camera is open: where it is and where from the player.
    def self.where_line(x, y)
      PokeAccess::I18n.t(:cam_where, :coords => PokeAccess::Locator.coords_text(x, y), :rel => from_player(x, y).to_s)
    end

    # A fixed trail as said: the camera's legs ("5 right, 3 up and 2 right"), the presses plan makes the player take,
    # the stretches gone round or where it is cut and why, and for a way that is no plain walk, the list's word for it.
    def self.trail_line(dirs, plan)
      t = PokeAccess::I18n
      rt = PokeAccess::Routes::Text
      legs = rt.legs(dirs, []).map { |d, n, _transfer| rt.leg(d, n) }
      out = [t.t(:cam_trail_set, :legs => rt.and_list(legs))]
      s = plan.stats || {}
      walked = plan.route && (plan.kind == :walk || plan.kind == :surf)
      out.push(t.t(:cam_trail_walk, :n => plan.route.length)) if walked
      n = s[:trail_detours].to_i
      out.push(n == 1 ? t.t(:cam_trail_detour) : t.t(:cam_trail_detours, :n => n)) if n > 0
      if s[:trail_cut] && walked
        out.push(t.t(:cam_trail_stops, :n => plan.route.length, :why => t.t(PokeAccess::Camera::WHY_KEYS[s[:trail_cut]])))
      end
      out.push(rt.listing(plan).sub(/\A, /, "")) unless plan.kind == :walk
      out.reject { |p| p.empty? }.join("; ")
    end
  end
end
