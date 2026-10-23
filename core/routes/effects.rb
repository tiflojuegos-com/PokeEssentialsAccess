module PokeAccess
  module Routes
    # What the map's events do to a move, read through EventPages and indexed per map from each event's facets:
    #   :carry    a Set Move Route on the player and nothing else (a hop over a hedge), landing them elsewhere:
    #             [:carry, dx, dy, jump, steps, held], held when it runs only with the arrow still held down;
    #   :warp     a transfer to another spot of this map;
    #   :exit     a transfer off the map, or to an unnamed spot of it: the end of a route, never a tile to cross;
    #   :barrier  a cutscene that stops the player and shoves them back or aside;
    #   :ramp     a bridge ramp, which moves the player between the two levels of a bridge map;
    #   :run      presses across impassable tiles, armed on arrival (side stairs): [:run, direction, presses, dx, dy];
    #   :hold     ground the page lets the player onto only with the direction key held down (a cracked floor).
    # Action-button events, field-move obstacles and pushables are indexed apart (act_index, gate_index, boulder_index).
    module Effects
      # Event codes that make an event worth walking: a move route, a transfer, a script, a common event.
      TOUCHY = [209, 201, 355, 117]
      # Locator label => the move that removes the obstacle.
      GATES = { :loc_cut_tree => :CUT, :loc_rock_smash => :ROCKSMASH }
      # The field moves an obstacle's script calls, for one its name does not give away ("Breakable Rock", "EV012"):
      # [pattern, locator label, move].
      SCRIPT_GATES = [[/\bpbCut\b/, :loc_cut_tree, :CUT], [/\bpbRockSmash\b/, :loc_rock_smash, :ROCKSMASH]]
      # Scripts that push the event they run in, and the move the push needs: Strength boulders, and the carts
      # and statues some games let the player shove without it.
      PUSH_SCRIPTS = [[/pbPushThisBoulder/, :STRENGTH], [/pbPushThisEvent/, nil], [/pbMoverEstatuas/, nil]]

      @touch_sources = []
      @pull_scripts = []
      @push_rules = []
      @field_gates = []

      # Registers a reader of events a plugin gives a meaning of its own: it gets a live event and answers the
      # effect arriving on it has for every facing (a :run), or nil to leave the event to EventPages.
      def self.touch_source(&reader); @touch_sources.push(reader); end

      # The map's index of what touching its events does: pkey => [fires_on_arrival, { facing => effect }], the first
      # event in the engine's order winning a shared tile; built from each event's :touch facet and kept until an
      # event changes.
      def self.touch_index
        PokeAccess::World::Events.summary(:touch) do
          idx = {}
          PokeAccess::World::Events.records.each do |r|
            t = PokeAccess::World::Events.facet(r, :touch)
            t.each { |k, e| idx[k] ||= e } if t
          end
          idx
        end
      end

      # One event's :touch facet: pkey => [fires_on_arrival, { facing => effect }] for each tile it covers where
      # touching it does something, a page with a script condition walked once per tile; a plugin reader's effect
      # (touch_source) takes precedence. nil for an event touching does nothing to.
      def self.touch_facet(r)
        ev = r.ev
        out = {}
        own = sourced_effect(ev)
        if own
          all = { 2 => own, 4 => own, 6 => own, 8 => own }
          r.tiles.each { |x, y| out[Routes.pkey(x, y)] ||= [true, all] }
          return out
        end
        return nil unless r.trigger == 1 || r.trigger == 2
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array) && list.any? { |c| TOUCHY.include?((c.code rescue 0)) }
        on = fires_on_arrival?(ev)
        mid = ($game_map.map_id rescue 0)
        shared = PokeAccess::EventPages.varies_by_tile?(list) ? nil : touch_effects(ev, on, mid, nil, nil)
        r.tiles.each do |x, y|
          effects = shared || touch_effects(ev, on, mid, x, y)
          out[Routes.pkey(x, y)] ||= [on, effects] unless effects.empty?
        end
        out.empty? ? nil : out
      end

      # The effect a registered plugin reader gives ev, or nil.
      def self.sourced_effect(ev)
        @touch_sources.each do |src|
          e = (src.call(ev) rescue nil)
          return e if e
        end
        nil
      end

      # The four facings' effects of touching ev; with a tile, each is walked from where the player stands as it
      # fires.
      # param act walk the page as one started with the action button, answering yes (see act_index)
      def self.touch_effects(ev, on, mid, x, y, act = false)
        effects = {}
        [2, 4, 6, 8].each do |d|
          dd = PokeAccess::DIR_DELTA[d]
          at = x.nil? ? nil : (on ? [x, y] : [x - dd[0], y - dd[1]])
          o = PokeAccess::EventPages.outcome(ev, d, at, act)
          e = act ? act_effect_of(o, mid) : touch_effect_of(o, d, on, mid)
          effects[d] = e if e
        end
        effects
      end

      # The map's index of action-button events that take the player where they could not walk (a climb), walked
      # answering yes: pkey => [fires_on_arrival, { facing => effect }]; built from each event's :act facet only when
      # an assisted search asks, and kept until an event changes.
      def self.act_index
        PokeAccess::World::Events.summary(:act) do
          idx = {}
          PokeAccess::World::Events.records.each do |r|
            t = PokeAccess::World::Events.facet(r, :act)
            t.each { |k, e| idx[k] ||= e } if t
          end
          idx
        end
      end

      # One event's :act facet: its tiles' effects walked as the action button with yes answered (see act_index), or
      # nil.
      def self.act_facet(r)
        return nil unless r.trigger == 0
        ev = r.ev
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array) && list.any? { |c| TOUCHY.include?((c.code rescue 0)) }
        on = fires_on_arrival?(ev)
        mid = ($game_map.map_id rescue 0)
        out = {}
        r.tiles.each do |x, y|
          effects = touch_effects(ev, on, mid, x, y, true)
          out[Routes.pkey(x, y)] ||= [on, effects] unless effects.empty?
        end
        out.empty? ? nil : out
      end

      # What pressing the action button at an event does for a route: a carry with Through on (a climb) or a warp
      # within the map; nil for a page that fights, sets something that stays, or cannot be read.
      def self.act_effect_of(o, mid)
        return nil if o.nil? || o.unknown || o.changes || o.battle
        if o.transfer
          return (o.transfer[0] == mid && o.transfer[1]) ? [:warp, o.transfer[1], o.transfer[2]] : nil
        end
        (o.move && o.through) ? [:carry, o.move[0], o.move[1], o.jump, nil] : nil
      end

      # The effect of pressing the action button facing d at (x,y): on the event standing there when it fires
      # from its own tile (on), on the one in front otherwise.
      def self.act_at(x, y, d, on)
        t = act_index[Routes.pkey(x, y)]
        return nil if t.nil? || t[0] != on
        t[1][d]
      end

      # The engine's own answer to "does this event fire when the player stands on it": a sprite-less (or
      # through) event on a tile the map lets anyone stand on. Asked of the event where the engine has it. The map's
      # answer, which the tiles and other events change, makes the facet asking it volatile.
      def self.fires_on_arrival?(ev)
        PokeAccess::World::Flags.volatile!
        r = (ev.over_trigger? rescue nil)
        return r ? true : false unless r.nil?
        return false unless ev.character_name.to_s.empty? || (ev.through rescue false)
        ($game_map.passable?(ev.x, ev.y, 0) rescue false) ? true : false
      end

      # One facing's effect from a walk's outcome, or nil when it changes nothing for a route. A carry keeps its steps
      # when the page does not wait for the move, as each tile's own touch event then fires (arrow floors), and is
      # marked when it runs only with the arrow still held (a held or pressed walk).
      def self.touch_effect_of(o, d, on, mid)
        return nil if o.nil?
        return (o.maybe_transfer ? [:exit] : nil) if o.unknown
        if o.transfer
          return [:exit] if o.transfer[0] != mid
          return o.transfer[1] ? [:warp, o.transfer[1], o.transfer[2]] : [:exit]
        end
        if o.move
          held = (o.held || o.pressed) ? true : nil
          return [:carry, o.move[0], o.move[1], o.jump, (o.waits ? nil : o.path), held] unless o.talks || o.changes
          return barrier?(o, d, on) ? [:barrier] : nil
        end
        return [:ramp, o.bridge] if on && !o.bridge.nil?
        (on && o.held) ? [:hold] : nil
      end

      # A story block: the page talks, sets nothing lasting and moves the player back or aside; a wall from that side.
      def self.barrier?(o, d, on)
        return false unless on && o.talks && !o.changes
        dd = PokeAccess::DIR_DELTA[d]
        o.move[0] * dd[0] + o.move[1] * dd[1] <= 0
      end

      # The effect of the event at (x,y) for facing d, when it fires the way asked: arriving (on) or bumping.
      def self.touch_at(x, y, d, on)
        t = touch_index[Routes.pkey(x, y)]
        return nil if t.nil? || t[0] != on
        t[1][d]
      end

      # True when a touch event of this map transfers to another spot of it, so the map holds more than one room.
      def self.warp_map?
        PokeAccess::World::Events.summary(:warps) do
          touch_index.values.any? { |t| t[1].values.any? { |e| e && e[0] == :warp } }
        end ? true : false
      end

      # True when a bridge ramp is on this map: only then does a search carry the bridge level.
      def self.ramp_map?
        PokeAccess::World::Events.summary(:ramps) do
          touch_index.any? { |_k, t| t[1].any? { |_d, e| e[0] == :ramp } }
        end ? true : false
      end

      # How many tiles of this map carry each kind of touch effect, for the diagnostic.
      def self.touch_census
        out = Hash.new(0)
        touch_index.each_value { |t| t[1].values.map { |e| e[0] }.uniq.each { |k| out[k] += 1 } }
        out
      end

      # The facings from which walking into the doorway at (x,y) leaves the map, or nil when it is no doorway
      # or leaves from every side.
      def self.door_facings(x, y)
        t = touch_index[Routes.pkey(x, y)]
        return nil if t.nil?
        fs = t[1].select { |_d, e| e[0] == :exit }.map { |d, _e| d }
        (fs.empty? || fs.length == 4) ? nil : fs.sort
      end

      # True if stepping onto (x,y) facing d leaves the map.
      def self.exit_step?(x, y, d)
        e = touch_at(x, y, d, true)
        !e.nil? && e[0] == :exit
      end

      # The map's index of the obstacles set aside in an assisted search: pkey of the event's own tile => [label,
      # move, event], the last event in the engine's order winning a tile; from each event's :gate facet, kept until
      # an event changes.
      def self.gate_index
        PokeAccess::World::Events.summary(:gate) do
          idx = {}
          PokeAccess::World::Events.records.each do |r|
            g = PokeAccess::World::Events.facet(r, :gate)
            idx[Routes.pkey(r.x, r.y)] = [g[0], g[1], r.ev, g[2]] if g
          end
          idx
        end
      end

      # Registers an obstacle a game clears with an item of its own, by a script its event runs (the profile DSL's
      # field_gate): the locator label it is named by and the item.
      def self.field_gate(pattern, label, item); @field_gates.push([pattern, label, item]); end

      # One event's :gate facet: [locator label, the move that removes it or nil, the item that does or nil], or nil
      # for no obstacle: one a game clears its own way (field_gate), else by the event's name, else by the field move
      # its script calls.
      def self.gate_facet(r)
        src = script_text(r.ev)
        own = @field_gates.find { |re, _l, _i| src =~ re }
        return [own[1], nil, own[2]] if own
        label = (PokeAccess::Locator.fieldmove_label(r.ev) rescue nil)
        return [label, GATES[label], nil] if GATES[label]
        hit = SCRIPT_GATES.find { |re, _l, _m| src =~ re }
        hit ? [hit[1], hit[2], nil] : nil
      end

      # The locator label of an obstacle by what its script clears it with (a game's field_gate, else a stock field
      # move), or nil: how an event with no name of its own is named.
      def self.scripted_gate_label(ev)
        src = script_text(ev)
        hit = @field_gates.find { |re, _l, _i| src =~ re } || SCRIPT_GATES.find { |re, _l, _m| src =~ re }
        hit ? hit[1] : nil
      end

      # The gate of the obstacle standing on (x,y), or nil.
      def self.gate_at(x, y)
        g = gate_index[Routes.pkey(x, y)]
        return nil unless g
        { :kind => :field, :label => g[0], :move => g[1], :item => g[3], :ev => g[2], :x => x, :y => y }
      end

      # Registers a script a game moves its pushables with that also lets the player pull them (the action button
      # facing one: the player steps back and it follows).
      def self.pull_script(pattern); @pull_scripts.push(pattern); end

      # Registers a script a game moves its pushables with, ahead of the stock ones (PUSH_SCRIPTS): the field move it
      # needs (nil for none) and, with a block, the condition the game moves them under, asked as a route is searched
      # (a switch the story sets, which no page change tells).
      def self.push_script(pattern, move = nil, &ready); @push_rules.push([pattern, move, ready]); end

      # The map's index of what the player can push: pkey of the event's own tile => [event, move it needs or nil, how
      # it is pushed, whether it can be pulled, the ways it can be pushed or nil for any, the condition it moves under
      # or nil] (see push_facet), the last event in the engine's order winning a tile; kept until an event changes.
      def self.boulder_index
        PokeAccess::World::Events.summary(:boulder) do
          idx = {}
          PokeAccess::World::Events.records.each do |r|
            m = PokeAccess::World::Events.facet(r, :push)
            idx[Routes.pkey(r.x, r.y)] = [r.ev].concat(m) if m
          end
          idx
        end
      end

      # One event's :push facet: [move needed or nil, :walk or :act (action button), pullable (pull_script), the ways
      # it goes (self_push_dirs) or nil for any, its push_script condition or nil]; nil when the player cannot push it.
      def self.push_facet(r)
        m = push_move(r.ev)
        return nil unless m
        dirs = self_push_dirs(r.ev)
        [m[0], r.trigger == 0 ? :act : :walk, @pull_scripts.any? { |re| script_text(r.ev) =~ re },
         dirs.empty? ? nil : dirs, push_rule(r.ev) && push_rule(r.ev)[2]]
      end

      # The game's rule an event's pushes go by (push_script), as [pattern, move, condition], or nil.
      def self.push_rule(ev)
        src = script_text(ev)
        @push_rules.find { |re, _m, _r| src =~ re }
      end

      # [move] for an event the player can push (nil move: no field move needed), or nil for any other.
      def self.push_move(ev)
        rule = push_rule(ev)
        return [rule[1]] if rule
        src = script_text(ev)
        hit = PUSH_SCRIPTS.find { |re, _m| src =~ re }
        return [hit[1]] if hit
        return [nil] if self_pushed?(ev)
        (PokeAccess::Locator.fieldmove_label(ev) rescue nil) == :loc_strength_boulder ? [:STRENGTH] : nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The move-route code that steps each way (down, left, right, up).
      STEP_MOVES = { 2 => 1, 4 => 2, 6 => 3, 8 => 4 }

      # The directions the player pushes an event that steps itself the way they face when walked into (an Insurgence
      # rolling boulder), [] for any other: its touch page branches on facing (111 [6, -1, d]), each stepping it.
      def self.self_push_dirs(ev)
        return [] unless [1, 2].include?(PokeAccess.ivar(ev, :@trigger))
        list = PokeAccess.ivar(ev, :@list)
        return [] unless list.is_a?(Array)
        dirs = []
        list.each_with_index do |c, i|
          pr = (c.parameters rescue nil) || []
          next unless (c.code rescue 0) == 111 && pr[0] == 6 && pr[1] == -1 && STEP_MOVES[pr[2]]
          dirs.push(pr[2]) if branch_steps?(list, i, STEP_MOVES[pr[2]]) && !dirs.include?(pr[2])
        end
        dirs
      end

      # True for an event the player pushes by walking into it, as self_push_dirs reads it.
      def self.self_pushed?(ev); !self_push_dirs(ev).empty?; end

      # True when the branch opened at list[i] moves its own event by just one step, step, in one of its routes, and the
      # player nowhere.
      def self.branch_steps?(list, i, step)
        depth = list[i].indent
        stepped = false
        j = i + 1
        while j < list.length && list[j].indent > depth
          c = list[j]
          if c.code == 209 && [0, -1].include?(c.parameters[0])
            steps = ((c.parameters[1].list rescue nil) || []).map { |m| (m.code rescue 0) }.select do |k|
              PokeAccess::World::Events::STEP_CODES.include?(k)
            end
            if c.parameters[0] == -1
              return false unless steps.empty?
            elsif steps == [step]
              stepped = true
            end
          end
          j += 1
        end
        stepped
      end

      # The script lines of an event's live page, one a line, with the scripts its conditional branches test (a cut
      # tree's "Conditional Branch: Script: pbCut").
      def self.script_text(ev)
        list = PokeAccess.ivar(ev, :@list)
        return "" unless list.is_a?(Array)
        list.map { |c| script_of(c) }.join("\n")
      end

      # The script an event command runs or tests, or "".
      def self.script_of(c)
        code = (c.code rescue 0)
        return (c.parameters[0] rescue "").to_s if code == 355 || code == 655
        return (c.parameters[1] rescue "").to_s if code == 111 && (c.parameters[0] rescue nil) == 12
        ""
      end
    end
  end
end

PokeAccess::World::Events.facet_provider(:touch) { |r| PokeAccess::Routes::Effects.touch_facet(r) }
PokeAccess::World::Events.facet_provider(:act) { |r| PokeAccess::Routes::Effects.act_facet(r) }
PokeAccess::World::Events.facet_provider(:gate) { |r| PokeAccess::Routes::Effects.gate_facet(r) }
PokeAccess::World::Events.facet_provider(:push) { |r| PokeAccess::Routes::Effects.push_facet(r) }
