module PokeAccess
  module Routes
    # What is said of a route, all of it from lang/: its legs (runs of one direction), the steps or why there is no walk
    # (the target list's suffix and the route key's line), a jump on the way, what to do where the route stops short of
    # the target, and where a forced move left the player.
    module Text
      # RPG direction code => its localization key.
      DIR_KEYS = { 8 => :dir_up, 2 => :dir_down, 4 => :dir_left, 6 => :dir_right }
      # RPG direction code => its key as the way a piece is pushed or pulled, "toward the right".
      TOWARD_KEYS = { 8 => :toward_up, 2 => :toward_down, 4 => :toward_left, 6 => :toward_right }
      # RPG direction code => its key as the side something lies on from the player, "to the right".
      SIDE_KEYS = { 8 => :side_up, 2 => :side_down, 4 => :side_left, 6 => :side_right }
      # RPG direction code => its key in a forced move's notice, "4 to the right".
      MOVED_KEYS = { 8 => :moved_up, 2 => :moved_down, 4 => :moved_left, 6 => :moved_right }
      # RPG direction code => its key as the way to step off the map from an edge's exit, "to the left".
      OUT_KEYS = { 8 => :loc_out_up, 2 => :loc_out_down, 4 => :loc_out_left, 6 => :loc_out_right }
      # What answered a plan (SearchResult#algo) => the name it is said by, where it is not its own algo_ key: the
      # player's flood is a Dijkstra.
      ALGO_KEYS = { :flood => :algo_dijkstra }
      # A plan's kind with no route => why, where it is not the plain "no route" (see none).
      NONE_KEYS = { :far => :loc_route_far, :cut => :loc_route_gave_up, :company => :loc_surf_company }

      # The name of direction d.
      def self.dir(d); PokeAccess::I18n.t(DIR_KEYS[d]); end

      # Direction d as the way a piece goes when pushed or pulled.
      def self.toward(d); PokeAccess::I18n.t(TOWARD_KEYS[d]); end

      # Direction d as the side something lies on, "to the right".
      def self.side(d); PokeAccess::I18n.t(SIDE_KEYS[d]); end

      # Direction d as the way to step off the map, "to the left".
      def self.out(d); PokeAccess::I18n.t(OUT_KEYS[d]); end

      # The way off the map from an edge's exit, "exit to the left".
      def self.exit_out(d); PokeAccess::I18n.t(:loc_exit_out, :out => out(d)); end

      # A route split into legs, runs of one direction as [direction, presses, transfer, kind]: with route_transfers
      # kept a run ends on a transfer (warps, the route's own unless given), and a press kinds marks is a leg alone.
      def self.legs(path, warps = nil, kinds = nil)
        return [] if path.nil? || path.empty?
        warps ||= path.respond_to?(:warps) ? path.warps : []
        breaks = PokeAccess::Verbosity.keep?(:route_transfers, :medium) ? warps : []
        out = []
        cur = nil
        count = 0
        path.each_with_index do |d, i|
          k = kinds && kinds[i]
          if count > 0 && (d != cur || k)
            out.push([cur, count, false])
            count = 0
          end
          if k
            out.push([d, 1, breaks.include?(i), k])
            cur = nil
            next
          end
          cur = d
          count += 1
          next unless breaks.include?(i)
          out.push([cur, count, true])
          count = 0
        end
        out.push([cur, count, false]) if count > 0
        out
      end

      # One leg as said, "3 up", or for a press that cannot be undone the same way its kind, "jump down", "slide
      # right"; with held, along ground where the key has to be kept down ("hold 3 up"); with transfer, ending on one
      # ("3 up, transfer").
      def self.leg(d, presses, held = false, transfer = false, kind = nil)
        t = PokeAccess::I18n
        s = case kind
            when :jump then jump(d)
            when :slide then t.t(:loc_slide_leg, :dir => dir(d))
            else t.t(:loc_leg, :n => presses, :dir => dir(d))
            end
        s = t.t(:loc_leg_held, :leg => s) if held
        transfer ? t.t(:loc_leg_transfer, :leg => s) : s
      end

      # A route's steps as said, "3 up, transfer, jump down, 2 left", the presses kinds marks said by their kind; that
      # the target is right beside for an empty one.
      def self.steps(path, kinds = nil)
        return PokeAccess::I18n.t(:loc_next_to) if path.empty?
        legs(path, nil, kinds).map { |d, n, transfer, kind| leg(d, n, false, transfer, kind) }.join(", ")
      end

      # Where a forced move left the player, from where it began (dx, dy tiles): "you moved 3 up and 2 to the right".
      def self.moved(dx, dy)
        parts = []
        parts.push(PokeAccess::I18n.t(MOVED_KEYS[dy < 0 ? 8 : 2], :n => dy.abs)) if dy != 0
        parts.push(PokeAccess::I18n.t(MOVED_KEYS[dx < 0 ? 4 : 6], :n => dx.abs)) if dx != 0
        PokeAccess::I18n.t(:loc_moved, :dirs => and_list(parts))
      end

      # The way a forced move went, leg by leg (moves: a direction code per tile), for the info key: "you slide 4 up,
      # 3 right and 2 down" for a slide, else "you moved ...".
      def self.moved_path(moves, slid)
        parts = legs(moves, []).map { |d, n, _transfer| leg(d, n) }
        PokeAccess::I18n.t(slid ? :loc_slid : :loc_moved_path, :legs => and_list(parts))
      end

      # Parts said as a list, "a, b and c".
      def self.and_list(parts)
        return parts[0].to_s if parts.length <= 1
        PokeAccess::I18n.t(:list_and, :rest => parts[0..-2].join(", "), :last => parts[-1])
      end

      # Why a target has no route, for the plan's kind: beyond reach (:far), a search stopped short of telling (:cut),
      # a way by water barred with someone along (:company), else none found.
      def self.none(kind)
        PokeAccess::I18n.t(NONE_KEYS[kind] || :loc_no_route)
      end

      # What the target list adds after a target for its plan (Planner): how many steps away, what stands in an
      # assisted route's way (or the line its gate carries for the list, :listing), the way by water, no route or one
      # cut short; nothing when it is within reach.
      def self.listing(plan)
        t = PokeAccess::I18n
        case plan.kind
        when :walk then plan.route.empty? ? "" : ", " + t.t(:loc_steps, :n => plan.route.length)
        when :assisted then ", " + (plan.gate[:listing] || gate_route(plan.gate))
        when :surf then ", " + t.t(:loc_surf_route)
        else ", " + none(plan.kind)
        end
      end

      # The route key's line for a plan: the steps (kinds marks the presses that cannot be undone the same way); for an
      # assisted route as assisted_line says; those to the shore, the way by water and which way to push off, only the
      # last on the shore; why there is none (see none); that no route can be got to.
      def self.line(plan, at = nil, kinds = nil)
        t = PokeAccess::I18n
        case plan.kind
        when :walk then t.t(:loc_route, :steps => steps(plan.route, kinds))
        when :assisted then assisted_line(plan, at, kinds)
        when :surf
          toward = surf_hold(plan.launch)
          return t.t(:loc_route, :steps => toward) if plan.route.empty?
          t.t(:loc_route, :steps => steps(plan.route, kinds) + ", " + t.t(:loc_surf_way, :toward => toward))
        when :cut, :far, :company then t.t(:loc_route, :steps => none(plan.kind))
        else t.t(:loc_route_none)
        end
      end

      # The route key's line for an assisted plan: the steps to its gate and what to do there (at: the player's tile),
      # off and back onto a plate underfoot (gate[:back]), then the way past the gate (past).
      def self.assisted_line(plan, at, kinds)
        t = PokeAccess::I18n
        g = plan.gate
        tail = past(g)
        if g[:back]
          back = t.t(:loc_control_step, :what => obstacle(g), :dir => side(g[:back]))
          return t.t(:loc_route, :steps => steps(plan.route, kinds)) + "; " + back + tail
        end
        return hold(g, at[0], at[1]) + tail if at && plan.route.empty?
        e = at && route_end(plan.route, at)
        there = e ? "; " + hold(g, e[0], e[1]) : ""
        t.t(:loc_route_gate, :what => gate_what(g), :steps => steps(plan.route, kinds) + there + tail)
      end

      # The tile a route from at ends on, replayed as the search made it (Moves.trace); nil when it cannot be replayed
      # to its end now.
      def self.route_end(route, at)
        pf = PokeAccess::Pathfinder
        pts = Moves.trace(at[0], at[1], pf.bridge_level, route, pf.replay_mode)
        pts.length == route.length ? pts[-1].tile : nil
      end

      # What an assisted route's gate tells of the way past it, after a "; ": the presses of a puzzle's controls that
      # open the way, in turn (:presses, see Controls), or the presses left once it is passed with their ledge hops
      # and slides (:after, :jumps and :slides, see Planner.assisted); "" when it tells neither.
      def self.past(g)
        t = PokeAccess::I18n
        names = (g[:presses] || []).map { |l| PokeAccess::Puzzles.label_of(l) }
        unless names.empty?
          key = names.length == 1 ? :loc_control_route : :loc_control_presses
          return "; " + t.t(key, :what => names.join(", "), :n => names.length)
        end
        n = g[:after].to_i
        return "" if n <= 0
        note = one_way_note(g[:jumps].to_i, g[:slides].to_i)
        "; " + t.t(:loc_route_after, :n => n) + (note ? ", " + note : "")
      end

      # How many presses of a stretch hop a ledge and how many slide, "with a jump and 2 slides"; nil with neither.
      def self.one_way_note(jumps, slides)
        t = PokeAccess::I18n
        parts = []
        parts.push(jumps == 1 ? t.t(:loc_a_jump) : t.t(:loc_jumps, :n => jumps)) if jumps > 0
        parts.push(slides == 1 ? t.t(:loc_a_slide) : t.t(:loc_slides, :n => slides)) if slides > 0
        parts.empty? ? nil : t.t(:loc_with, :what => and_list(parts))
      end

      # "blocked by a tree, use Cut": what stands in an assisted route's way (a gate, see route_gates), and what gets
      # the player past it (or that it is needed, when the player surely cannot use it, as hold says; the obstacle
      # alone where the game's rules are unchecked, FieldMoves.named?).
      def self.gate_route(g)
        t = PokeAccess::I18n
        case g[:kind]
        when :act then t.t(:loc_act_route)
        when :dismount then t.t(:loc_dismount_route)
        when :pull then t.t(:loc_gate_route_pull, :what => obstacle(g))
        when :control then t.t(:loc_control_route, :what => obstacle(g))
        else
          return t.t(:loc_gate_route_push, :what => obstacle(g)) if g[:move].nil? && g[:item].nil?
          fm = PokeAccess::FieldMoves
          return t.t(:loc_gate_route_bare, :what => obstacle(g)) unless fm.named?
          key = fm.clear?(g) == false ? :loc_gate_route_need : :loc_gate_route
          t.t(key, :what => obstacle(g), :move => fm.clearer(g))
        end
      end

      # What an assisted route leads up to, as "route to <this>" names it.
      def self.gate_what(g)
        t = PokeAccess::I18n
        case g[:kind]
        when :act then t.t(:loc_act_spot)
        when :dismount then t.t(:loc_dismount_spot)
        else obstacle(g)
        end
      end

      # The obstacle a gate stands for: a puzzle's control by its label, a pushed event as the locator names it, else
      # its label as the locator says it (Locator.said_label).
      def self.obstacle(g)
        return PokeAccess::Puzzles.label_of(g[:label]) if g[:kind] == :control
        name = g[:ev] && (PokeAccess::Locator.target_name(g[:ev]) rescue nil)
        name && !name.to_s.empty? ? name.to_s : PokeAccess::I18n.t(PokeAccess::Locator.said_label(g[:label]))
      end

      # What to do where an assisted route stops, the player on (px,py), with the side it lies on ("to the right"):
      # act, dismount, pull, press a control, push, or use its field move or item (or that it is needed).
      def self.hold(g, px, py)
        t = PokeAccess::I18n
        case g[:kind]
        when :act then return t.t(:loc_act_here, :dir => side(g[:face]))
        when :dismount then return t.t(:loc_dismount_here, :dir => side(g[:face]))
        when :pull
          return t.t(:loc_gate_pull, :what => obstacle(g), :dir => side(g[:face]), :toward => toward(10 - g[:face]))
        end
        dx = g[:x] - px
        dy = g[:y] - py
        d = dx < 0 ? 4 : (dx > 0 ? 6 : (dy < 0 ? 8 : 2))
        what = obstacle(g)
        if g[:kind] == :control
          return t.t(g[:step] ? :loc_control_step : :loc_control_press, :what => what, :dir => side(d))
        end
        if g[:move].nil? && g[:item].nil?
          key = g[:act] ? :loc_gate_push_act : :loc_gate_push
          return t.t(key, :what => what, :dir => side(d), :toward => toward(d))
        end
        fm = PokeAccess::FieldMoves
        return t.t(:loc_gate_bare, :what => what, :dir => side(d)) unless fm.named?
        key = fm.clear?(g) == false ? :loc_gate_need : :loc_gate_use
        t.t(key, :what => what, :dir => side(d), :move => fm.clearer(g))
      end

      # Where a route by water stops, on the shore: push off toward d ("toward the right"), or from here with no way
      # told.
      def self.surf_hold(d)
        d.nil? ? PokeAccess::I18n.t(:loc_surf_here) : PokeAccess::I18n.t(:loc_surf_toward, :dir => toward(d))
      end

      # A ledge hop ahead, toward d: "jump up".
      def self.jump(d); PokeAccess::I18n.t(:loc_jump, :dir => dir(d)); end

      # A plan's search as said (route_stats): what answered, how many tiles it examined and in how many milliseconds
      # (to a tenth, which keeps their plural right), or that it was cut short; nil when no search was made.
      def self.stats(plan)
        s = plan.stats
        return nil unless s && s[:algo]
        t = PokeAccess::I18n
        algo = t.t(ALGO_KEYS[s[:algo]] || :"algo_#{s[:algo]}")
        key = plan.kind == :cut ? :route_stats_cut : :route_stats
        t.t(key, :algo => algo, :n => s[:expanded].to_i, :ms => t.number(s[:ms].to_f))
      end
    end
  end
end
