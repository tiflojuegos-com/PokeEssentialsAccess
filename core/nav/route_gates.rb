module PokeAccess
  # Pathfinder, assisted routes: with no walkable route, a search that allows a field move, the action button or
  # getting off the bike, cut at the first such step; failing that, push_route. Each assisted step carries a gate:
  #   { :kind => :field, :label, :move, :x, :y }  an obstacle at (x,y), cleared with a field move (nil: pushed)
  #   { :kind => :act, :face, :x, :y }            the action button, pressed at (x,y) facing :face
  #   { :kind => :dismount, :face, :x, :y }       off the bike at (x,y), then on toward :face
  module Pathfinder
    # Locator label => the move that removes the obstacle.
    GATES = { :loc_cut_tree => :CUT, :loc_rock_smash => :ROCKSMASH }
    # What an assisted step costs a route beyond its own press, in steps: a detour this long is preferred to
    # stopping to clear something, and one obstacle to two.
    GATE_COST = 8
    # Scripts that push the event they run in, and the move the push needs: Strength boulders, and the carts
    # and statues some games let the player shove without it.
    PUSH_SCRIPTS = [[/pbPushThisBoulder/, :STRENGTH], [/pbPushThisEvent/, nil], [/pbMoverEstatuas/, nil]]
    # How many boulders a push route may move with the puzzle assist on, and how many states it may look at.
    PUSH_LIMIT = 12
    PUSH_NODES = 1500

    # Registers an assisted step a plugin or a game adds (a wall climbed with its own item): the block gets
    # (x, y, dir, level) and answers a Step with its gate, as move_target does, or nil.
    def self.assist_source(&blk)
      @assist_sources ||= []
      @assist_sources.push(blk)
    end

    # Per-map index of the obstacles set aside in an assisted search: pkey => [label, move, event].
    def self.gate_index
      event_index(:gate) do
        idx = {}
        ($game_map.events.values rescue []).each do |ev|
          label = (PokeAccess::Locator.fieldmove_label(ev) rescue nil)
          move = GATES[label]
          idx[pkey(ev.x, ev.y)] = [label, move, ev] if move
        end
        idx
      end
    end

    # Per-map index of what the player can push: pkey => [event, move it needs or nil].
    def self.boulder_index
      event_index(:boulder) do
        idx = {}
        ($game_map.events.values rescue []).each do |ev|
          m = push_move(ev)
          idx[pkey(ev.x, ev.y)] = [ev, m[0]] if m
        end
        idx
      end
    end

    # [move] for an event the player can push (nil move: no field move needed), or nil for any other.
    def self.push_move(ev)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      src = list.map { |c| (c.code rescue 0) == 355 || (c.code rescue 0) == 655 ? (c.parameters[0] rescue "").to_s : "" }.join("\n")
      hit = PUSH_SCRIPTS.find { |re, _m| src =~ re }
      return [hit[1]] if hit
      (PokeAccess::Locator.fieldmove_label(ev) rescue nil) == :loc_strength_boulder ? [:STRENGTH] : nil
    rescue StandardError
      nil
    end

    # True when anything could open a route walking cannot: an obstacle to clear, a boulder to push, an event to act
    # at, a registered assist, a waterfall while surfing or the bike to get off.
    def self.assist_possible?
      return true unless gate_index.empty? && boulder_index.empty? && act_index.empty?
      return true unless (@assist_sources || []).empty?
      (($PokemonGlobal.surfing rescue false) || ($PokemonGlobal.bicycle rescue false)) ? true : false
    end

    # The route up to the first assisted step on the way to (tx,ty), as [steps, gate], for a target walking
    # alone cannot reach; nil when not even that gets there, or nothing on the map could assist.
    def self.gated_path(tx, ty)
      return nil unless assist_possible?
      full = with_gates_open { searching { find_path_to(tx, ty, false) || find_path_to(tx, ty, true) } }
      cut = full ? cut_at_gate(full) : nil
      cut || push_route(tx, ty)
    rescue StandardError
      nil
    end

    # The route through boulders to push, up to its first push or other assisted step: [steps, gate], or nil.
    def self.push_route(tx, ty)
      rocks = boulder_index
      return nil if rocks.empty?
      with_gates_open { with_rocks_through(rocks) { searching { push_search(tx, ty, rocks) } } }
    rescue StandardError
      nil
    end

    # A search over the player's tile and where each moved boulder was left (keyed by its start tile); a press into a
    # boulder pushes it one tile if it could move there and no boulder is beyond, leaving the player in place.
    def self.push_search(tx, ty, rocks)
      px = $game_player.x; py = $game_player.y
      return nil if (px - tx).abs + (py - ty).abs > reach
      lvl = bridge_level
      start = [px, py, []]
      g = { start => 0 }
      came = {}; closed = {}; heap = []; iter = 0
      deadline = search_deadline
      heap_push(heap, [(px - tx).abs + (py - ty).abs, 0, px, py, start])
      until heap.empty?
        iter += 1
        return note_cut if iter > PUSH_NODES
        return nil if over_budget?(iter, deadline)
        cur = heap_pop(heap)
        st = cur[4]
        next if closed[st]
        closed[st] = true
        cx = st[0]; cy = st[1]; moved = st[2]
        return cut_pushes(came, st) if target_reached?(cx, cy, tx, ty)
        use_level(lvl)
        DIRS.each do |dir|
          nxt = push_move_from(cx, cy, dir, moved, rocks, lvl)
          next if nxt.nil?
          nst, step, cost = nxt
          next if closed[nst]
          ng = g[st] + cost
          next unless g[nst].nil? || ng < g[nst]
          g[nst] = ng
          came[nst] = [st, step]
          heap_push(heap, [ng + (nst[0] - tx).abs + (nst[1] - ty).abs, 0, nst[0], nst[1], nst])
        end
      end
      nil
    end

    # One move of the push search from (cx,cy) toward dir: [next state, [direction, presses, gate], cost], or
    # nil; the gate is a push's own or that of an obstacle the move crosses.
    def self.push_move_from(cx, cy, dir, moved, rocks, lvl)
      nx = cx + dir[0]; ny = cy + dir[1]
      rock = rock_at(nx, ny, moved, rocks)
      if rock
        return nil if moved.length >= push_limit && moved.none? { |m| m[0] == rock }
        bx = nx + dir[0]; by = ny + dir[1]
        return nil if rock_at(bx, by, moved, rocks) || !pushable?(rocks[rock][0], dir[2], nx, ny)
        nmoved = (moved.reject { |m| m[0] == rock } + [[rock, bx, by]]).sort
        move = rocks[rock][1]
        gate = { :kind => :field, :label => (move ? :loc_strength_boulder : :loc_pushable), :move => move, :x => nx, :y => ny }
        return [[cx, cy, nmoved], [dir[2], 1, gate], 1 + GATE_COST]
      end
      t = move_target(cx, cy, dir, false, false, lvl)
      return nil if t.nil? || rock_at(t.x, t.y, moved, rocks)
      [[t.x, t.y, moved], [dir[2], t.presses, t.gate], t.presses + (t.gate ? GATE_COST : 0)]
    end

    # How many boulders a route may move: with the puzzle assist on, which plans a puzzle room for the player,
    # up to PUSH_LIMIT; without it only the one that cuts the path, pushed as often as it takes.
    def self.push_limit
      PokeAccess::Puzzles.assist? ? PUSH_LIMIT : 1
    end

    # The boulder standing on (x,y) in a search state -- one pushed there, or one never moved from there --
    # as the key of the tile it started on, or nil.
    def self.rock_at(x, y, moved, rocks)
      moved.each { |m| return m[0] if m[1] == x && m[2] == y }
      k = pkey(x, y)
      return nil unless rocks[k]
      moved.any? { |m| m[0] == k } ? nil : k
    end

    # The steps of a push route up to its first push or obstacle, with that step's gate; nil when it has none.
    def self.cut_pushes(came, st)
      steps = []
      while (c = came[st])
        steps.unshift(c[1])
        st = c[0]
      end
      path = []
      steps.each do |d, presses, gate|
        return [path, gate] if gate
        presses.times { path.push(d) }
      end
      nil
    end

    # Runs a block with every pushable boulder through for the engine, putting each back afterwards whatever
    # happens; the passability memo is bypassed meanwhile, as with the obstacles set aside.
    def self.with_rocks_through(rocks)
      in_context do |c|
        was = c.gates_open
        saved = []
        begin
          c.gates_open = true
          rocks.each_value do |r|
            saved.push([r[0], (r[0].through rescue false)])
            (r[0].through = true) rescue nil
          end
          yield
        ensure
          c.gates_open = was
          saved.each { |ev, t| (ev.through = t) rescue nil }
        end
      end
    end

    # The part of a route walkable now, up to (not into) its first assisted step, with that step's gate.
    def self.cut_at_gate(path)
      pts = with_gates_open { trace($game_player.x, $game_player.y, bridge_level, path) }
      pts.each_with_index { |p, i| return [path[0, i], p.gate] if p.gate }
      nil
    end

    # Runs a block as an assisted search: assisted steps allowed and each cuttable or smashable obstacle made through,
    # put back afterwards whatever happens; the passability memo is bypassed meanwhile.
    def self.with_gates_open
      in_context do |c|
        was = [c.assisting, c.gates_open]
        saved = []
        begin
          c.assisting = true
          c.gates_open = !gate_index.empty?
          gate_index.each_value do |g|
            saved.push([g[2], (g[2].through rescue false)])
            (g[2].through = true) rescue nil
          end
          yield
        ensure
          c.assisting, c.gates_open = was
          saved.each { |ev, t| (ev.through = t) rescue nil }
        end
      end
    end

    # The gate of the obstacle standing on (x,y), or nil.
    def self.gate_at(x, y)
      g = gate_index[pkey(x, y)]
      g ? { :kind => :field, :label => g[0], :move => g[1], :x => x, :y => y } : nil
    end

    # What the player can do from (cx,cy) toward dir where walking stops, as a step with its gate, or nil.
    def self.assisted_step(cx, cy, dir, lvl)
      s = act_step(cx, cy, dir, lvl) || waterfall_step(cx, cy, dir, lvl)
      return s if s
      (@assist_sources || []).each do |src|
        s = (src.call(cx, cy, dir, lvl) rescue nil)
        return s if s
      end
      dismount_step(cx, cy, dir, lvl)
    end

    # The action button pressed facing dir: at the event in front, or at the one the player stands on when
    # it fires from its own tile.
    def self.act_step(cx, cy, dir, lvl)
      d = dir[2]
      e = act_at(cx + dir[0], cy + dir[1], d, false) || act_at(cx, cy, d, true)
      return nil if e.nil?
      l = e[0] == :warp ? landing(e[1], e[2]) : landing(cx + e[1], cy + e[2])
      l ? Step.new(l[0], l[1], lvl, 1, { :kind => :act, :face => d, :x => cx, :y => cy }) : nil
    end

    # True if the event can be moved one tile in direction d from (x,y) -- where it stands, or where a push
    # search has left it -- by the check the game's own push makes, asked of the event itself with its through
    # flag off, as the engine passes anything through.
    def self.pushable?(ev, d, x = nil, y = nil)
      was = (ev.through rescue false)
      (ev.through = false) rescue nil
      x ||= ev.x; y ||= ev.y
      if ev.respond_to?(:can_move_in_direction?)
        ev.passable?(x, y, d, true) ? true : false
      elsif ev.respond_to?(:passableStrict?)
        ev.passableStrict?(x, y, d) ? true : false
      else
        ev.passable?(x, y, d) ? true : false
      end
    rescue StandardError
      false
    ensure
      (ev.through = was) rescue nil
    end

    # Climbing a waterfall with Waterfall: surfing, facing up into the fall.
    def self.waterfall_step(cx, cy, dir, lvl)
      return nil unless dir[2] == 8 && ($PokemonGlobal.surfing rescue false)
      l = waterfall_ascent(cx, cy - 1)
      return nil if l.nil?
      Step.new(l[0], l[1], lvl, 1, { :kind => :field, :label => :surf_waterfall, :move => :WATERFALL, :x => cx, :y => cy - 1 })
    end

    # Getting off the bike where it cannot go on (tall grass, ice), on a map that lets the player off it.
    def self.dismount_step(cx, cy, dir, lvl)
      return nil unless ($PokemonGlobal.bicycle rescue false)
      return nil if PokeAccess::MapMeta.always_bicycle?(($game_map.map_id rescue 0))
      return nil unless on_foot { player_passable?(cx, cy, dir[2]) }
      Step.new(cx + dir[0], cy + dir[1], lvl, 1, { :kind => :dismount, :face => dir[2], :x => cx, :y => cy })
    end

    # Runs a block with the player on foot for the engine, putting the bike back afterwards.
    def self.on_foot
      was = $PokemonGlobal.bicycle
      $PokemonGlobal.bicycle = false
      yield
    ensure
      $PokemonGlobal.bicycle = was
    end
  end
end
