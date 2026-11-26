module PokeAccess
  module Routes
    # What the map's events do to a move, read through EventPages and indexed per map from each event's facets:
    #   :carry    a Set Move Route on the player and nothing else (a hop over a hedge), landing them elsewhere:
    #             [:carry, dx, dy, jump, steps that ask for a touch event, held, ride, through, floor];
    #             held: runs only with the arrow still held down; ride: a platform's ride from its stop (Rides);
    #             through: a step of it is taken with Through on; floor: what it leaves the map's floor switch at
    #             (level_switch);
    #   :warp     a transfer to another spot of this map;
    #   :exit     a transfer off the map, or to an unnamed spot of it: the end of a route, never a tile to cross;
    #   :barrier  a cutscene that stops the player and shoves them back or aside;
    #   :ramp     a bridge ramp, which moves the player between the two levels of a bridge map;
    #   :floor    a stair that sets the map's floor switch as the player steps on it: [:floor, on];
    #   :run      presses across impassable tiles, armed on arrival (side stairs): [:run, direction, presses, dx, dy];
    #   :hold     ground the page lets the player onto only with the direction key held down (a cracked floor).
    # A watcher's sight (sight_facet) and a parallel page that watches the player's place (place_facet) have effects
    # on each tile of their lines; a touch page that opens a menu has a Menu of its options' effects (menu_effect).
    # Action-button events, field-move obstacles and pushables are indexed apart (act_index, gate_index, boulder_index).
    module Effects
      # Event codes that make an event worth walking: a move route, a transfer, a script, a common event.
      TOUCHY = [209, 201, 355, 117]
      # The parallel trigger and the Erase Event command.
      PARALLEL = 4
      ERASE = 116
      # Locator label => the move that removes the obstacle.
      GATES = { :loc_cut_tree => :CUT, :loc_rock_smash => :ROCKSMASH }
      # The field moves an obstacle's script calls, for one its name does not give away ("Breakable Rock", "EV012"):
      # [pattern, locator label, move].
      SCRIPT_GATES = [[/\bpbCut\b/, :loc_cut_tree, :CUT], [/\bpbRockSmash\b/, :loc_rock_smash, :ROCKSMASH]]
      # Scripts that push the event they run in, and the move the push needs: Strength boulders, and the carts, objects
      # and statues some games let the player shove without it.
      PUSH_SCRIPTS = [[/pbPushThisBoulder/, :STRENGTH], [/pbPushThis\w+/, nil], [/pbMoverEstatuas/, nil]]

      @touch_sources = []
      @pull_scripts = []
      @push_rules = []
      @field_gates = []
      @side_rules = []
      @floor_sources = []

      # Registers a reader of events a plugin gives a meaning of its own: it gets a live event and answers the
      # effect arriving on it has for every facing (a :run), :unseen for one the walks step on as plain ground (what a
      # sighted player cannot see, without the puzzle assist), or nil to leave the event to EventPages.
      def self.touch_source(&reader); @touch_sources.push(reader); end

      # Reads the indexes every walk and search looks up at each step, from the world as it stands, before events are lent
      # through (Probe.before_lending), on both floors of a map with a floor switch (level_switch); an assisted one has
      # read the action events too (Pathfinder.with_gates_open).
      def self.read_ahead
        read_floor
        sw = level_switch
        return unless sw
        PokeAccess::World::Floors.looking(sw, !PokeAccess::World::Floors.on?(sw)) { read_floor }
      end

      # Reads the indexes of read_ahead on the floor looked at.
      def self.read_floor
        touch_index
        warp_map?
        ramp_map?
        gate_index
      end

      # The map's index of what touching its events does: pkey => [fires_on_arrival, { facing => effect }], plus :sight
      # and the watcher's pkey (sight_facet), :ride, the platform and its stop's tile (Rides), or :place and the map it
      # sends to (place_facet). Sights come first, then the :touch facet (the first event in the engine's order wins a
      # tile), then rides and places; kept until an event changes.
      def self.touch_index
        PokeAccess::World::Events.summary(:touch) do
          idx = {}
          [:sight_touch, :touch, :ride, :place].each do |name|
            PokeAccess::World::Events.records.each do |r|
              t = PokeAccess::World::Events.facet(r, name)
              t.each { |k, e| idx[k] ||= e } if t
            end
          end
          idx
        end
      end

      # One event's :touch facet: pkey => [fires_on_arrival, { facing => effect }] for each tile it covers where
      # touching it does something, a page with a script condition walked once per tile; a plugin reader's effect
      # (touch_source) takes precedence. A watcher started by sight moves the player on a bump only from in front of it
      # (facing_watcher), its exit on every side. nil for an event touching does nothing to, or that the reader calls
      # unseen.
      def self.touch_facet(r)
        ev = r.ev
        out = {}
        own = sourced_effect(ev)
        return nil if own == :unseen
        if own
          all = { 2 => own, 4 => own, 6 => own, 8 => own }
          r.tiles.each { |x, y| out[Routes.pkey(x, y)] ||= [true, all] }
          return out
        end
        return nil unless r.trigger == 1 || r.trigger == 2
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array) && (list.any? { |c| TOUCHY.include?((c.code rescue 0)) } || floor_page?(list))
        on = fires_on_arrival?(ev)
        mid = ($game_map.map_id rescue 0)
        front = !on && PokeAccess::Routes::Sight.trainer?(r) ? facing_watcher(r) : nil
        lv = level_page?(list)
        shared = PokeAccess::EventPages.varies_by_tile?(list) ? nil : touch_effects(ev, on, mid, nil, nil, false, lv)
        r.tiles.each do |x, y|
          effects = shared || touch_effects(ev, on, mid, x, y, false, lv)
          effects = effects.reject { |d, e| d != front && e[0] != :exit } if front
          out[Routes.pkey(x, y)] ||= [on, effects] unless effects.empty?
        end
        out.empty? ? nil : out
      end

      # The facing a bump starts a watcher started by sight from (Sight.trainer?): toward it from the tile in front, as
      # pbEventCanReachPlayer? asks; 0 for a watcher that sees nothing, which no bump starts.
      def self.facing_watcher(r)
        return 0 if sight_range(r) <= 0
        10 - PokeAccess::World::Flags.direction(r.id, r.ev).to_i
      end

      # How far a watcher sees, by the number in its name as the running era reads it (Sight.name_re).
      def self.sight_range(r); r.name.to_s[PokeAccess::Routes::Sight.name_re, 1].to_i; end

      # The touch effects a watcher's sight may have on its line: what moves the player within the map, and an exit.
      SIGHT_KINDS = [:carry, :warp, :exit]

      # One event's :sight_touch facet, for a watcher started by sight (Sight.trainer?) whose page moves the player:
      # pkey of each tile of its line (Sight.line) => [true, { facing => effect }, :sight, pkey of its own tile].
      # nil for any other event, one that fires on arrival, one that moves no one there, and one a plugin reader takes.
      def self.sight_facet(r)
        return nil unless PokeAccess::Routes::Sight.trainer?(r)
        ev = r.ev
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array) && moves_player?(list)
        return nil if sourced_effect(ev)
        n = sight_range(r)
        return nil if n <= 0 || fires_on_arrival?(ev)
        view = {}
        d = PokeAccess::World::Flags.direction(r.id, ev).to_i
        PokeAccess::Routes::Sight.line(ev, r.x, r.y, d, n, r.through, view)
        PokeAccess::World::Flags.volatile! unless r.through
        mid = ($game_map.map_id rescue 0)
        out = {}
        own = Routes.pkey(r.x, r.y)
        view.each_key do |k|
          effects = sight_effects(ev, mid, k / Routes::PKEY_STRIDE, k % Routes::PKEY_STRIDE)
          out[k] = [true, effects, :sight, own] unless effects.empty?
        end
        out.empty? ? nil : out
      end

      # One event's :place facet, for a parallel page that sends the player off where it compares their place with a
      # number (EventPages.place_lines, a road sending off whoever strays): pkey of each tile of those lines where its
      # walk transfers => [true, { facing => transfer_effect }, :place, the map it sends to]. nil for a page that
      # transfers wherever they stand, one that erases itself, or an autorun one.
      def self.place_facet(r)
        return nil unless r.trigger == PARALLEL
        ev = r.ev
        list = PokeAccess.ivar(ev, :@list)
        return nil unless list.is_a?(Array) && PokeAccess::EventPages.transfer_after?(list, 0)
        return nil if list.any? { |c| (c.code rescue 0) == ERASE && (c.indent rescue 0) == 0 }
        lines = PokeAccess::EventPages.place_lines(list)
        return nil if lines.empty?
        anywhere = PokeAccess::EventPages.outcome(ev, 2)
        return nil if anywhere.nil? || anywhere.transfer
        size = [($game_map.width rescue 0).to_i, ($game_map.height rescue 0).to_i]
        mid = ($game_map.map_id rescue 0)
        facings = PokeAccess::EventPages.reads_facing?(list) ? [2, 4, 6, 8] : [2]
        out = {}
        lines.each do |axis, v|
          next if v < 0 || v >= size[axis]
          (0...size[1 - axis]).each do |k|
            x, y = axis == 0 ? [v, k] : [k, v]
            key = Routes.pkey(x, y)
            out[key] = place_effects(ev, x, y, facings, mid) unless out.key?(key)
          end
        end
        out.delete_if { |_k, e| e == false }
        out.empty? ? nil : out
      end

      # The place facet's entry for (x,y): each of facings walked from there (one alone stands for all four); false
      # where no walk transfers.
      def self.place_effects(ev, x, y, facings, mid)
        effects = {}
        dest = nil
        facings.each do |d|
          o = PokeAccess::EventPages.outcome(ev, d, [x, y])
          next unless o && o.transfer && !o.battle
          effects[d] = transfer_effect(o.transfer, mid)
          dest ||= o.transfer[0]
        end
        return false if effects.empty?
        effects = { 2 => effects[2], 4 => effects[2], 6 => effects[2], 8 => effects[2] } if facings.length == 1
        [true, effects, :place, dest]
      end

      # The tiles where a parallel page sends the player off this map as they arrive (place_facet), by the
      # map they go to, each list in order: { map => [[x, y], ...] }.
      def self.place_exits
        mid = ($game_map.map_id rescue 0)
        out = {}
        touch_index.each do |k, t|
          next unless t[2] == :place && t[3] && t[3] != mid
          (out[t[3]] ||= []).push([k / Routes::PKEY_STRIDE, k % Routes::PKEY_STRIDE])
        end
        out.each_value { |tiles| tiles.sort! }
        out
      end

      # The four facings' effects of a watcher's page started with the player on (x,y), from a page that says nothing,
      # fights no one and is read to its end: a carry, which sets nothing that stays, a warp within the map, or an exit.
      def self.sight_effects(ev, mid, x, y)
        effects = {}
        [2, 4, 6, 8].each do |d|
          o = PokeAccess::EventPages.outcome(ev, d, [x, y])
          next if o.nil? || o.talks || o.unknown
          e = touch_effect_of(o, d, true, mid)
          effects[d] = e if e && SIGHT_KINDS.include?(e[0])
        end
        effects
      end

      # The pkey of the watcher whose sight takes the player on from (x,y) (sight_facet), or nil: what a step there
      # enters (Moves::Step#entry), so that a way to that watcher ends with it.
      def self.sight_watcher(x, y)
        t = touch_index[Routes.pkey(x, y)]
        t && t[2] == :sight ? t[3] : nil
      end

      # The tiles of the line of a watcher on (tx,ty) whose sight takes the player on (sight_facet), as [x, y]: a way to
      # it ends with the press into one of them. nil for any other target.
      def self.sight_line(tx, ty)
        PokeAccess::World::Events.at(tx, ty).each do |r|
          f = PokeAccess::World::Events.facet(r, :sight_touch)
          return f.keys.sort.map { |k| [k / Routes::PKEY_STRIDE, k % Routes::PKEY_STRIDE] } if f
        end
        nil
      end

      # True when a page's list may move the player: a Set Move Route on them, a transfer or a script that is one.
      def self.moves_player?(list)
        return true if list.any? { |c| (c.code rescue 0) == 209 && (c.parameters[0] rescue nil).to_i == -1 }
        PokeAccess::EventPages.transfer_after?(list, 0)
      end

      # True when pkey key is the tile of a watcher whose sight takes the player on (sight_line).
      def self.watcher?(key)
        !sight_line(key / Routes::PKEY_STRIDE, key % Routes::PKEY_STRIDE).nil?
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
      # fires; a page that opens a menu, by its options (menu_effect).
      # param act walk the page as one started with the action button, answering yes (see act_index)
      # param level the page sets nothing that stays but the map's level switches (level_page?)
      def self.touch_effects(ev, on, mid, x, y, act = false, level = false)
        effects = {}
        [2, 4, 6, 8].each do |d|
          dd = PokeAccess::DIR_DELTA[d]
          at = x.nil? ? nil : (on ? [x, y] : [x - dd[0], y - dd[1]])
          o = PokeAccess::EventPages.outcome(ev, d, at, act)
          e = if act then act_effect_of(o, mid)
              elsif o && o.menu then menu_effect(ev, d, at, on, mid, o)
              else touch_effect_of(o, d, on, mid, level)
              end
          effects[d] = e if e
        end
        effects
      end

      # The effect of a touch page's menu: its first option's that takes the player somewhere, read as any other effect,
      # with every option a route can take (options: [[index, text as painted, effect, or nil for one that leaves the
      # player where the menu opened], ...]).
      class Menu < Array
        attr_reader :options

        def initialize(effect, options)
          super(effect)
          @options = options
        end
      end

      # The effect for facing d of a touch page whose walk o stopped at a menu, each option walked from at: a Menu when
      # one of them takes the player somewhere (option_effect), else the stop's own (touch_effect_of).
      def self.menu_effect(ev, d, at, on, mid, o)
        options = []
        o.menu.each do |k, text|
          e = option_effect(PokeAccess::EventPages.outcome(ev, d, at, false, k), on, mid)
          options.push([k, text, e]) unless e == :none
        end
        first = options.find { |_k, _t, e| e }
        first ? Menu.new(first[2], options) : touch_effect_of(o, d, on, mid)
      end

      # What taking one option of a menu does for a route, from its walk o: a transfer's (transfer_effect), a carry, a
      # ramp; nil where the player is left on the tile the menu opened on (a cutscene, or a walk that cannot tell);
      # :none for a bump that moves no one.
      def self.option_effect(o, on, mid)
        return :none if o.nil?
        return [:exit] if o.unknown && o.maybe_transfer
        return transfer_effect(o.transfer, mid) if o.transfer && !o.unknown
        return carry_effect(o) if o.move && !o.unknown && !o.battle && !o.changes
        return [:ramp, o.bridge] if on && !o.bridge.nil? && !o.unknown
        on ? nil : :none
      end

      # The effect of a transfer to [map, x, y]: a :warp to another spot of map mid, else an :exit.
      def self.transfer_effect(t, mid)
        t[0] == mid && t[1] ? [:warp, t[1], t[2]] : [:exit]
      end

      # The carry of a walk o that moves the player (see touch_effect_of), leaving the map's floor switch at floor
      # unless that is nil.
      def self.carry_effect(o, floor = nil)
        e = [:carry, o.move[0], o.move[1], o.jump, (o.waits ? nil : o.stops), (o.held || o.pressed) ? true : nil]
        e.push(nil, o.through ? true : nil) if o.through || !floor.nil?
        e.push(floor) unless floor.nil?
        e
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
      # answer, which the tiles and other events change, makes the facet asking it volatile; it is asked with the engine
      # shown the floor looked at (World::Floors.engine). A Lens of Truth event is asked as a route meets it
      # (World::Lens.met).
      def self.fires_on_arrival?(ev)
        PokeAccess::World::Flags.volatile!
        PokeAccess::World::Lens.met(ev) { PokeAccess::World::Floors.engine { stood_over?(ev) } }
      end

      # The engine's over_trigger? of ev, or where it has none, its sprite-less or through event on passable ground.
      def self.stood_over?(ev)
        r = (ev.over_trigger? rescue nil)
        return(r ? true : false) unless r.nil?
        return false unless ev.character_name.to_s.empty? || (ev.through rescue false)
        ($game_map.passable?(ev.x, ev.y, 0) rescue false) ? true : false
      end

      # One facing's effect from a walk's outcome, or nil when it changes nothing for a route. A carry keeps the steps
      # that ask for a touch event (EventPages' stops) when the page does not wait for the move, as those tiles' own events
      # then fire (arrow floors), and is marked when it runs only with the arrow still held (a held or pressed walk); with
      # level, a page that sets only the map's level switches carries as one that sets nothing (stairs between floors).
      def self.touch_effect_of(o, d, on, mid, level = false)
        return nil if o.nil?
        return (o.maybe_transfer ? [:exit] : nil) if o.unknown
        return transfer_effect(o.transfer, mid) if o.transfer
        if o.move
          return carry_effect(o, level ? floor_set(o) : nil) unless o.talks || (o.changes && !level)
          return barrier?(o, d, on) ? [:barrier] : nil
        end
        return [:ramp, o.bridge] if on && !o.bridge.nil?
        fl = on && level && !o.talks ? floor_set(o) : nil
        return [:floor, fl] unless fl.nil?
        (on && o.held) ? [:hold] : nil
      end

      # True when a page's list sets the map's floor switch (level_switch): a stair that only does that is walked too.
      def self.floor_page?(list)
        sw = level_switch
        !sw.nil? && list.any? { |c| (c.code rescue 0) == 121 && (c.parameters[0] rescue nil) == sw }
      end

      # What a walk o left the map's floor switch at (level_switch), nil where it did not set it.
      def self.floor_set(o)
        sw = level_switch
        sw ? o.switched[sw] : nil
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
      # needs (nil for none) and, with a block, the condition the game moves them under, asked as a route is searched with
      # the tile the move would leave the pushable on (a switch the story sets, which no page change tells; the only floor
      # it moves onto).
      def self.push_script(pattern, move = nil, &ready); @push_rules.push([pattern, move, ready]); end

      # The map's index of what the player can push: pkey of the event's own tile => [event, move it needs or nil, how
      # it is pushed, whether it can be pulled, the ways it can be pushed or nil for any, the condition it moves under
      # or nil, its long pushes or nil, the events its pushes move along or nil, its pushes from given tiles or nil] (see
      # push_facet), the last event in the engine's order winning a tile; kept until an event changes.
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
      # it goes (self_push_dirs) or nil for any, its push_script condition or nil, its long_pushes or nil, its
      # push_twins or nil, its tile_pushes or nil]; nil when the player cannot push it.
      def self.push_facet(r)
        m = push_move(r.ev)
        return nil unless m
        dirs = self_push_dirs(r.ev)
        long = long_pushes(r.ev)
        twins = push_twins(r.ev)
        drops = tile_pushes(r.ev)
        [m[0], r.trigger == 0 ? :act : :walk, @pull_scripts.any? { |re| script_text(r.ev) =~ re },
         dirs.empty? ? nil : dirs, push_rule(r.ev) && push_rule(r.ev)[2], long.empty? ? nil : long,
         twins.empty? ? nil : twins, drops.empty? ? nil : drops]
      end

      # The events a push of ev moves along a tile the same way, by facing => [events]: in each branch on the player's
      # facing that pushes it, the other events a Set Move Route there steps that one tile (twin blocks);
      # {} for none.
      def self.push_twins(ev)
        list = PokeAccess.ivar(ev, :@list)
        out = {}
        return out unless list.is_a?(Array)
        list.each_with_index do |c, i|
          pr = (c.parameters rescue nil) || []
          step = (c.code rescue 0) == 111 && pr[0] == 6 && pr[1] == -1 ? STEP_MOVES[pr[2]] : nil
          next unless step
          evs = branch_twins(list, i, step, ev)
          out[pr[2]] = evs unless evs.empty?
        end
        out
      end

      # The other events the branch opened at list[i] steps one tile along step, when it pushes ev that way.
      def self.branch_twins(list, i, step, ev)
        depth = list[i].indent
        pushes = false
        ids = []
        j = i + 1
        while j < list.length && list[j].indent > depth
          c = list[j]
          pr = (c.parameters rescue nil) || []
          if c.code == 355 || c.code == 655
            pushes ||= PUSH_SCRIPTS.any? { |re, _m| pr[0].to_s =~ re } || @push_rules.any? { |re, _m, _r| pr[0].to_s =~ re }
          elsif c.code == 209
            steps = ((pr[1].list rescue nil) || []).map { |m| (m.code rescue 0) }.select do |k|
              PokeAccess::World::Events::STEP_CODES.include?(k)
            end
            who = pr[0].to_i
            pushes ||= (who == 0 || who == ev.id) && steps == [step]
            ids.push(who) if who > 0 && who != ev.id && steps == [step]
          end
          j += 1
        end
        return [] unless pushes
        ids.uniq.map { |id| ($game_map.events[id] rescue nil) }.compact
      end

      # What a search that moves boulders tracks: the pushables (boulder_index) and the events their pushes move along
      # (push_twins) that the player cannot push, those as [event, nil, :along, false, []]; kept until an event changes.
      def self.push_pieces
        PokeAccess::World::Events.summary(:pieces) do
          idx = boulder_index.dup
          boulder_index.each_value do |b|
            (b[7] || {}).each_value { |evs| evs.each { |tw| idx[Routes.pkey(tw.x, tw.y)] ||= [tw, nil, :along, false, []] } }
          end
          idx
        end
      end

      # The game's rule an event's pushes go by (push_script), as [pattern, move, condition], or nil.
      def self.push_rule(ev)
        src = script_text(ev)
        @push_rules.find { |re, _m, _r| src =~ re }
      end

      # True when an event is pushed with no field move: by the game's own function for it, or moving itself.
      def self.free_push?(ev)
        rule = push_rule(ev)
        return rule[1].nil? if rule
        src = script_text(ev)
        hit = PUSH_SCRIPTS.find { |re, _m| src =~ re }
        hit ? hit[1].nil? : self_pushed?(ev)
      end

      # The words said after the name of a target the player can push, where its name does not tell it; nil otherwise.
      def self.push_mark(t)
        return nil if t.is_a?(PokeAccess::Locator::SurfaceTarget) || PokeAccess::Locator.fieldmove_label(t)
        push_move(t) ? PokeAccess::I18n.t(:loc_push_mark) : nil
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

      # The directions the player pushes an event that moves itself when walked into or used, [] for any other: one that
      # steps away from them (flee_dirs), one that steps the way they face (an Insurgence rolling boulder), its page
      # branching on facing (111 [6, -1, d]), each stepping it, or one that sends itself off (long_pushes). What the action
      # button moves, or what flees, is no person and says nothing.
      def self.self_push_dirs(ev)
        trig = PokeAccess.ivar(ev, :@trigger)
        return [] unless [0, 1, 2].include?(trig)
        list = PokeAccess.ivar(ev, :@list)
        return [] unless list.is_a?(Array)
        object = !PokeAccess::Puzzles::Auto.loud?(list) && !PokeAccess::Puzzles::Auto.person_sheet?(ev.character_name.to_s)
        return [] if trig == 0 && !object
        away = object ? flee_dirs(ev, list) : []
        return away unless away.empty?
        dirs = long_pushes(ev).keys
        list.each_with_index do |c, i|
          pr = (c.parameters rescue nil) || []
          next unless (c.code rescue 0) == 111 && pr[0] == 6 && pr[1] == -1 && STEP_MOVES[pr[2]]
          dirs.push(pr[2]) if branch_steps?(list, i, STEP_MOVES[pr[2]]) && !dirs.include?(pr[2])
        end
        dirs
      end

      # What a walk against an event sends it through whatever lies between, over several tiles, as Z's electric crystals
      # and Realidea's red ones go: facing => [dx, dy, gone, again], gone when the page the push opens stops nobody, again
      # when the push sets nothing that stays, so the same page sends it on from where it lands.
      # Read as the interpreter runs the page (EventPages), so a push its own self switch has spent is none; {} for an
      # event a script pushes, one with no graphic, one that goes whichever way the player faces (someone walking off in
      # a scene), or one whose walk moves the player, fights or cannot be told.
      def self.long_pushes(ev)
        out = {}
        return out unless [1, 2].include?(PokeAccess.ivar(ev, :@trigger)) && sends_itself?(ev)
        return out if ev.character_name.to_s.empty? && (ev.tile_id rescue 0).to_i == 0
        src = script_text(ev)
        return out if push_rule(ev) || PUSH_SCRIPTS.any? { |re, _m| src =~ re }
        [2, 4, 6, 8].each do |d|
          o = PokeAccess::EventPages.outcome(ev, d)
          next unless o && o.sent && o.path.empty? && !o.unknown && !o.transfer && !o.battle
          out[d] = [o.sent[0], o.sent[1], gone_after?(ev, o.sets), !o.changes]
        end
        out
      end

      # True when the event's live page branches on the player's facing and has a Set Move Route with Through on, all that
      # long_pushes takes the time to walk.
      def self.sends_itself?(ev)
        list = PokeAccess.ivar(ev, :@list)
        return false unless list.is_a?(Array)
        list.any? { |c| (c.code rescue 0) == 111 && (c.parameters[0, 2] rescue nil) == [6, -1] } && list.any? do |c|
          (c.code rescue 0) == 209 && ((c.parameters[1].list rescue nil) || []).any? { |m| (m.code rescue 0) == 37 }
        end
      end

      # True when what a push turned on (EventPages' sets) leaves the event on a page that stops nobody.
      def self.gone_after?(ev, sets)
        over = {}
        sets.each { |s| over[s.is_a?(String) ? [:self, ev.id, s] : [:switch, s]] = true }
        links = PokeAccess::World::Mechanics::Links
        !links.blocks?(links.live_page(ev, over))
      end

      # True for an event the player pushes by walking into it, as self_push_dirs reads it.
      def self.self_pushed?(ev); !self_push_dirs(ev).empty?; end

      # The facings from which a page, run as the interpreter would now (a block may answer only while a switch is on), sends
      # its own event one step away from the player and moves them nowhere.
      def self.flee_dirs(ev, list)
        return [] unless list.any? { |c| (c.code rescue 0) == 209 && away_route?(c.parameters[1]) }
        [2, 4, 6, 8].select do |d|
          o = PokeAccess::EventPages.outcome(ev, d)
          o && !o.unknown && !o.transfer && o.path.empty? && o.own.any? { |mr| away_route?(mr) }
        end
      end

      # True for a route that takes one step away from the player: moving away from them, or turning to them and stepping back.
      def self.away_route?(mr)
        codes = ((mr.list rescue nil) || []).map { |m| (m.code rescue 0) }
        steps = codes.select { |k| PokeAccess::World::Events::STEP_CODES.include?(k) }
        steps == [11] || (steps == [13] && codes.include?(25))
      end

      # One event's :sides facet: the facings its action-button page answers to, when all it does hangs from branches on
      # the player's facing (111 [6, -1, d]) with no else that does something; nil for any other, or one that answers to all
      # four.
      def self.sides_facet(r)
        return nil unless r.trigger == 0
        list = PokeAccess.ivar(r.ev, :@list)
        return nil unless list.is_a?(Array)
        body = list.reject { |c| [108, 408].include?((c.code rescue 0)) }
        first = body.first
        return nil unless first && facing_branch?(first)
        left = refused_side(body, first)
        return left if left
        dirs = []
        body.each_with_index do |c, i|
          next if c.indent != first.indent || c.code == 0 || c.code == 412
          if c.code == 411
            return nil unless (body[i + 1].code rescue 0) == 0
          else
            return nil unless facing_branch?(c)
            dirs.push(c.parameters[2])
          end
        end
        dirs = dirs.uniq
        dirs.length < 4 ? dirs : nil
      end

      # The other three facings when the page is one branch on the player's facing that only ends the event (or does
      # nothing) and an else that does something, as Desolation's Keneph lever; nil for any other page.
      def self.refused_side(body, first)
        k = first.indent
        i = 1
        i += 1 while body[i] && body[i].indent > k && [115, 0].include?(body[i].code)
        return nil unless body[i] && body[i].indent == k && body[i].code == 411
        j = i + 1
        acts = false
        while body[j] && body[j].indent > k
          acts = true unless body[j].code == 0
          j += 1
        end
        return nil unless acts && body[j] && body[j].code == 412
        return nil unless (body[(j + 1)..-1] || []).all? { |c| c.code == 0 }
        [2, 4, 6, 8] - [first.parameters[2]]
      end

      # True for a branch on the player's facing.
      def self.facing_branch?(c); c.code == 111 && c.parameters[0] == 6 && c.parameters[1] == -1; end

      # Registers a profile's rule for the facings the action button works an event from where its page cannot tell:
      # given a live event, the block answers a list of facings, or nil to leave it to its page (sides_facet).
      def self.side_rule(&blk); @side_rules.push(blk); end

      # The facings the profiles' rules give an event, or nil.
      def self.ruled_sides(ev)
        @side_rules.each do |blk|
          fs = blk.call(ev)
          return fs if fs
        end
        nil
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # The tiles an event on (tx,ty) answers the action button from, when a profile's rule or its page tells it answers
      # from some sides alone and one of them is there; nil for any other target.
      def self.act_sides(tx, ty)
        fs = nil
        PokeAccess::World::Events.at(tx, ty).each do |e|
          fs = ruled_sides(e.ev) || PokeAccess::World::Events.facet(e, :sides)
          break if fs
        end
        return nil unless fs
        area = PokeAccess::Pathfinder.area_at(tx, ty)
        tiles = (PokeAccess::Pathfinder.reach_tiles(tx, ty) - area).select do |x, y|
          area.any? { |ax, ay| fs.include?(facing_to(x, y, ax, ay)) }
        end
        tiles.empty? ? nil : tiles
      end

      # The facing that looks from (x,y) at (tx,ty) along a row or a column, or nil.
      def self.facing_to(x, y, tx, ty)
        return (ty < y ? 8 : (ty > y ? 2 : nil)) if x == tx
        y == ty ? (tx < x ? 4 : 6) : nil
      end

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

      # The tiles a list tests a character on (who: -1 the player, 0 the event itself), as [x, y, index of the inner
      # branch]: a branch "variable == number" on a variable holding one axis of its place, with the other axis's inside.
      def self.place_tests(list, who)
        axes = {}
        out = []
        list.each_with_index do |c, i|
          pr = (c.parameters rescue nil) || []
          code = (c.code rescue 0)
          if code == 122 && pr[0] == pr[1] && pr[2].to_i == 0 && pr[3].to_i == 6 && pr[4].to_i == who && pr[5].to_i < 2
            axes[pr[0]] = pr[5].to_i
          elsif (a = equal_axis(pr, code, axes))
            nxt = list[i + 1]
            np = nxt ? ((nxt.parameters rescue nil) || []) : []
            b = nxt && equal_axis(np, (nxt.code rescue 0), axes)
            next unless b && b != a
            out.push(a == 0 ? [pr[3].to_i, np[3].to_i, i + 1] : [np[3].to_i, pr[3].to_i, i + 1])
          end
        end
        out
      end

      # The axis (0 x, 1 y) of a branch "variable == number" on a variable axes holds, or nil.
      def self.equal_axis(pr, code, axes)
        return nil unless code == 111 && pr[0] == 1 && pr[2].to_i == 0 && pr[4].to_i == 0
        axes[pr[1]]
      end

      # Where a push sends an event further than a tile, as its page tells by where it stands: in a test of its own
      # place (place_tests), a branch on the player's facing with a route of its own with Through on
      # (a push that tumbles several tiles): [x, y, facing] => [dx, dy]; {} for none.
      def self.tile_pushes(ev)
        list = PokeAccess.ivar(ev, :@list)
        out = {}
        return out unless list.is_a?(Array)
        place_tests(list, 0).each do |x, y, i|
          depth = list[i].indent
          j = i + 1
          while j < list.length && list[j].indent > depth
            pr = (list[j].parameters rescue nil) || []
            if list[j].code == 111 && pr[0] == 6 && pr[1] == -1
              net = own_route_net(list, j, ev)
              out[[x, y, pr[2]]] = net if net
            end
            j += 1
          end
        end
        out
      end

      # The net [dx, dy] of the first route with Through on the branch opened at list[i] runs on ev itself, or nil.
      def self.own_route_net(list, i, ev)
        depth = list[i].indent
        j = i + 1
        while j < list.length && list[j].indent > depth
          pr = (list[j].parameters rescue nil) || []
          if list[j].code == 209 && [0, ev.id].include?(pr[0].to_i)
            net = PokeAccess::EventPages.through_net(pr[1])
            return net if net
          end
          j += 1
        end
        nil
      end

      # Forgets the level switches read for the map (level_switches).
      def self.forget_levels; @levels = nil; end

      # The switches that are the map's levels: turned on by a quiet touch page (quiet_page?) and off by another, the
      # stairs between two floors drawn on one map, not a toggle that only turns its own page
      # over; read once a map, as id => true.
      def self.level_switches
        levels_read[1]
      end

      # The map's floor switch: of its level switches, the one the most events that do not set it show a page by or
      # branch on, the floor a search keeps apart (Pathfinder::FLOOR); nil when no such event reads any.
      def self.level_switch
        levels_read[2]
      end

      # [key, level switches, floor switch] of this map, read once a map (see level_switches and level_switch).
      def self.levels_read
        key = [($game_map.map_id rescue nil), ($game_map.events rescue nil).object_id]
        return @levels if @levels && @levels[0] == key
        set = [{}, {}]
        setters = {}
        readers = {}
        (($game_map.events rescue nil) || {}).each_value do |ev|
          pages = (PokeAccess.ivar(ev, :@event).pages rescue nil) || []
          pages.each do |pg|
            switches_read(pg).each { |s| (readers[s] ||= {})[ev.id] = true }
            list = (pg.list rescue nil)
            next unless [1, 2].include?((pg.trigger rescue 0).to_i) && list.is_a?(Array) && quiet_page?(list)
            list.each do |c|
              pr = (c.parameters rescue nil) || []
              next unless (c.code rescue 0) == 121 && pr[0] == pr[1]
              set[pr[2].to_i == 0 ? 0 : 1][pr[0]] = true
              (setters[pr[0]] ||= {})[ev.id] = true
            end
          end
        end
        levels = {}
        counts = {}
        set[0].each_key do |s|
          next unless set[1][s]
          others = (readers[s] || {}).keys.reject { |id| setters[s][id] }
          next if readers[s] && others.empty?
          levels[s] = true
          counts[s] = others.length unless others.empty?
        end
        floor = counts.keys.sort.max_by { |s| counts[s] }
        @levels = [key, levels, floor]
      end

      # The switches page pg shows by or branches on.
      def self.switches_read(pg)
        out = []
        c = (pg.condition rescue nil)
        out.push(c.switch1_id) if c && (c.switch1_valid rescue false)
        out.push(c.switch2_id) if c && (c.switch2_valid rescue false)
        ((pg.list rescue nil) || []).each do |k|
          pr = (k.parameters rescue nil) || []
          out.push(pr[1]) if (k.code rescue 0) == PokeAccess::EventPages::BRANCH && pr[0] == 0
        end
        out
      end

      # True for a page that talks to no one and fights no one, and sets nothing that stays but single switches: a
      # stair's, not a cutscene's.
      def self.quiet_page?(list)
        list.all? do |c|
          code = (c.code rescue 0)
          pr = (c.parameters rescue nil) || []
          next false if PokeAccess::EventPages::TALK.include?(code) || code == PokeAccess::EventPages::CHOICES
          next pr[0] == pr[1] if code == 121
          next false if PokeAccess::EventPages::CHANGE.include?(code)
          !((code == 355 || code == 655) && pr[0].to_s =~ PokeAccess::EventPages::TALK_SCRIPT)
        end
      end

      # Registers a reader of the floor a target is acted on from: given the target's tile, it answers true or false for
      # the map's floor switch on or off, or nil to leave it to the pages (target_floor).
      def self.floor_source(&reader); @floor_sources.push(reader); end

      # The floor (the map's floor switch on or off) the target on (tx,ty) is acted on from: a registered reader's
      # (floor_source), else the one floor where an action-button page of an event there runs something; nil where both
      # or neither do, or the map has no floor switch.
      def self.target_floor(tx, ty)
        sw = level_switch
        return nil unless sw
        @floor_sources.each do |src|
          v = (src.call(tx, ty) rescue nil)
          return v unless v.nil?
        end
        live = PokeAccess::World::Floors.live?(sw)
        here = PokeAccess::World::Floors.looking(sw, live) { acted_at?(tx, ty) }
        there = PokeAccess::World::Floors.looking(sw, !live) { acted_at?(tx, ty) }
        return nil if here == there
        here ? live : !live
      end

      # True when an action-button page of an event on (tx,ty) runs something on the floor looked at: not one whose
      # commands all wait on the floor switch being the other way (a heap moved from the lower floor alone).
      def self.acted_at?(tx, ty)
        sw = level_switch
        PokeAccess::World::Events.at(tx, ty).any? do |r|
          next false unless PokeAccess.ivar(r.ev, :@trigger) == 0 && PokeAccess::Locator.has_commands?(r.ev)
          gate = floor_gate(PokeAccess.ivar(r.ev, :@list) || [], sw)
          gate.nil? || gate == PokeAccess::World::Floors.on?(sw)
        end
      end

      # The value of switch sw a page's list runs anything with: when its one command at the top is a branch on sw with
      # no else, the value it asks for; nil otherwise.
      def self.floor_gate(list, sw)
        top = list.reject { |c| (c.indent rescue 0) > 0 || PokeAccess::EventPages::NO_OPS.include?((c.code rescue 0)) }
        return nil unless top.length == 1 || (top.length == 2 && (top[1].code rescue 0) == 412)
        pr = (top[0].parameters rescue nil) || []
        return nil unless (top[0].code rescue 0) == PokeAccess::EventPages::BRANCH && pr[0] == 0 && pr[1] == sw
        pr[2].to_i == 0
      end

      # True when the only things a page's list sets that stay are the map's level switches (level_switches), one at
      # least.
      def self.level_page?(list)
        levels = level_switches
        return false if levels.empty?
        sets = false
        list.each do |c|
          code = (c.code rescue 0)
          pr = (c.parameters rescue nil) || []
          if code == 121
            return false unless pr[0] == pr[1] && levels[pr[0]]
            sets = true
          elsif PokeAccess::EventPages::CHANGE.include?(code)
            return false
          elsif (code == 355 || code == 655) && pr[0].to_s =~ PokeAccess::EventPages::CHANGE_SCRIPT
            return false
          end
        end
        sets
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

PokeAccess::World::Probe.before_lending { PokeAccess::Routes::Effects.read_ahead }
PokeAccess::World::Events.facet_provider(:touch) { |r| PokeAccess::Routes::Effects.touch_facet(r) }
PokeAccess::World::Events.facet_provider(:sight_touch) { |r| PokeAccess::Routes::Effects.sight_facet(r) }
PokeAccess::World::Events.facet_provider(:place) { |r| PokeAccess::Routes::Effects.place_facet(r) }
PokeAccess::World::Events.facet_provider(:act) { |r| PokeAccess::Routes::Effects.act_facet(r) }
PokeAccess::World::Events.facet_provider(:gate) { |r| PokeAccess::Routes::Effects.gate_facet(r) }
PokeAccess::World::Events.facet_provider(:push) { |r| PokeAccess::Routes::Effects.push_facet(r) }
PokeAccess::World::Events.facet_provider(:sides) { |r| PokeAccess::Routes::Effects.sides_facet(r) }
PokeAccess::Caches.register(:levels) { PokeAccess::Routes::Effects.forget_levels }
