module PokeAccess
  # Accessible puzzle helper. Puzzles are registered per map in kinds: :grid (floor-rune grids unsolvable
  # blind), :state (mechanisms whose progress lives in unseen switches/variables, e.g. cranks/valves) and
  # :facing (rotatable statues). Each kind scales with the puzzle_assist setting (off = the minimum
  # invisible state, on = more help): it announces changes as they happen, reads the whole puzzle on the
  # info key, and with assist adds the explicit solution.
  module Puzzles
    @defs = {}
    # Grid runtime state.
    @map = nil; @cell = nil; @settle = 0; @states = nil; @stage = nil; @solved = nil; @entered = false
    # State-puzzle runtime: last seen watched values and last solved flag.
    @sp_last = nil; @sp_solved = nil
    # Obstacle proximity runtime: last player tile checked and whether an obstacle was adjacent there.
    @obs_pos = nil; @obs_adj = nil; @obs_events = nil; @obs_map = nil
    # Control-event cache: the player-toggleable events that flip a watched flag, paired with their watch
    # entry, cached per map since events are static.
    @controls = nil; @controls_map = nil
    # Facing-puzzle runtime: statue events cached per map, and their last-seen facings (to announce a turn).
    @statues = nil; @statues_map = nil; @face_last = nil

    # Default cell-name keys for a 3x3 grid in row-major (reading) order.
    GRID3 = [:cell_tl, :cell_tc, :cell_tr, :cell_ml, :cell_c, :cell_mr, :cell_bl, :cell_bc, :cell_br]
    # Pre-panned cue per column (0 left, 1 centre, 2 right) and a pitch per row (top high, bottom low).
    PAN = ["pa_guide_l", "pa_guide_c", "pa_guide_r"]
    ROWP = [140, 110, 85]
    # Frames to wait after stepping on a tile before reading its state, so the game's toggle has applied.
    SETTLE = 2

    # Registers a puzzle for a map (one per map; a puzzle may span maps by registering the same def under
    # each map id). :kind selects the behaviour (:grid default, or :state). opts --
    #   grid: :cols, :rows, :cells ([[x,y],...] row-major), :lit (->(i){bool}), :active (->{bool}),
    #     :target (->{ {:name=>String, :pattern=>[bool,...]} or nil }), :solved (->{bool}),
    #     :names (cell-name keys, default the 3x3 scheme).
    #   state: :kind=>:state, :watch ([{:switch|:var=>id, :label, :on, :off, :min}]), :solved (->{bool}),
    #     :solved_msg, :hint (assist-only). Labels/states/messages are i18n symbols or literal strings.
    def self.register(map_id, opts); @defs[map_id] = opts; end

    # The puzzle definition for the current map, or nil.
    def self.current
      return nil unless $game_map
      @defs[$game_map.map_id]
    end

    # The kind of a puzzle definition (:grid default, or :state).
    def self.kind(d); d[:kind] || :grid; end

    # True while a puzzle on this map is in its active phase; gates the info-key readout.
    def self.active?
      d = current
      return false unless d
      case kind(d)
      when :state  then state_active?(d)
      when :facing then !facing_statues(d).empty?
      else !!(d[:active].call)
      end
    rescue StandardError
      false
    end

    # True when the current puzzle has something the locator's puzzles category should list (grid cells,
    # obstacle walls, or facing statues), so the category appears only when it is useful.
    # An EMPTY list does not count as something to list. d[:cells] and d[:obstacles] are declared in the
    # profile and can come out empty on one map: with a bare presence check the locator category showed up
    # anyway and the player walked through all of it finding nothing.
    def self.has_locator_targets?
      d = current
      return false unless d
      return true if (d[:cells].respond_to?(:empty?) ? !d[:cells].empty? : d[:cells])
      return true if (d[:obstacles].respond_to?(:empty?) ? !d[:obstacles].empty? : d[:obstacles])
      kind(d) == :facing ? !facing_statues(d).empty? : false
    rescue StandardError
      false
    end

    # Clears all per-map state (called when leaving a puzzle or entering a new map).
    def self.reset_state
      @map = nil; @cell = nil; @settle = 0; @states = nil; @stage = nil; @solved = nil; @entered = false
      @sp_last = nil; @sp_solved = nil
      @obs_pos = nil; @obs_adj = nil; @obs_events = nil; @obs_map = nil
      @controls = nil; @controls_map = nil
      @statues = nil; @statues_map = nil; @face_last = nil
    end

    # The lit state of every cell as a boolean array.
    def self.read_states(d)
      (0...d[:cells].length).map { |i| !!(d[:lit].call(i) rescue false) }
    end

    # The cell index the player stands on, or nil.
    def self.cell_at(d)
      d[:cells].index([$game_player.x, $game_player.y])
    end

    # The spoken name of cell i.
    def self.cell_name(d, i)
      PokeAccess::I18n.t((d[:names] || GRID3)[i])
    end

    # Plays the locating tone for cell i: panned by its column, pitched by its row.
    def self.tone(d, i)
      v = PokeAccess::Config.event_volume
      return if v.nil? || v <= 0
      PokeAccess::Spatial.cue(PAN[i % d[:cols]] || "pa_guide_c", v, ROWP[i / d[:cols]] || 100)
    end

    # Runs every map frame; dispatches to the puzzle kind. A no-op off a puzzle map.
    def self.tick
      d = current
      unless d
        reset_state
        return
      end
      case kind(d)
      when :state  then state_tick(d)
      when :facing then facing_tick(d)
      else grid_tick(d)
      end
      obstacle_tick(d) if d[:obstacles]
    rescue StandardError
      nil
    end

    # Grid frame: announces target/stage changes and the win (which still fire as the puzzle goes
    # inactive), then the cell/state the player steps on. Progress runs always; cell feedback only while active.
    def self.grid_tick(d)
      if $game_map.map_id != @map
        @map = $game_map.map_id; @cell = nil; @settle = 0; @states = nil; @stage = nil
        @solved = (d[:solved] ? (d[:solved].call rescue false) : false)
        @entered = true
      else
        @entered = false
      end
      announce_progress(d)
      return unless (d[:active].call rescue false)
      states = read_states(d)
      announce_cell(d, states)
      @states = states
    end

    # Announces the win once (false->true), otherwise the target letter, saying "next" when a previous
    # letter was just completed. On entering an already-solved map nothing is said.
    def self.announce_progress(d)
      if d[:solved] && (d[:solved].call rescue false)
        PokeAccess.speak(PokeAccess::I18n.t(:puzzle_solved), false) unless @solved
        @solved = true; @stage = nil
        return
      end
      tgt = (d[:target].call rescue nil)
      stage = tgt && tgt[:name]
      announce_stage(d, tgt, !(@stage.nil? || @entered)) if stage && stage != @stage
      @stage = stage
    end

    # Speaks the current target letter, plus the exact cells to light when assist is on. param advanced
    # true when a previous letter was just completed
    def self.announce_stage(d, tgt, advanced)
      msg = PokeAccess::I18n.t(advanced ? :puzzle_next : :puzzle_form, :name => tgt[:name])
      msg += ". " + PokeAccess::I18n.t(:puzzle_light, :cells => cells_phrase(d, lit_cells(tgt[:pattern]))) if assist?
      PokeAccess.speak(msg, false)
    end

    # Announces the cell under the player and its state, debounced so the read happens after the game's
    # step-toggle settles; a state change while standing still (a reset) is read immediately.
    def self.announce_cell(d, states)
      i = cell_at(d)
      if i != @cell
        @cell = i; @settle = i ? SETTLE : 0
        tone(d, i) if i
      elsif i && @settle > 0
        @settle -= 1
        speak_cell(d, i, states) if @settle == 0
      elsif i && @states && @states[i] != states[i]
        speak_cell(d, i, states)
      end
    end

    # Speaks a cell's name and lit state.
    def self.speak_cell(d, i, states)
      PokeAccess.speak("#{cell_name(d, i)}, #{PokeAccess::I18n.t(states[i] ? :puzzle_on : :puzzle_off)}", true)
    end

    # The info-key readout; dispatches to the puzzle kind.
    def self.read
      d = current
      return unless d
      case kind(d)
      when :state  then state_read(d)
      when :facing then facing_read(d)
      else grid_read(d)
      end
    rescue StandardError
      nil
    end

    # The grid readout while active: the target letter, the grid row by row and (assist) the cells still
    # to light or to switch off to match it.
    def self.grid_read(d)
      return unless (d[:active].call rescue false)
      states = read_states(d)
      tgt = (d[:target].call rescue nil)
      parts = []
      parts.push(PokeAccess::I18n.t(:puzzle_form, :name => tgt[:name])) if tgt
      parts.push(grid_phrase(d, states))
      parts.concat(assist_phrases(d, tgt, states)) if assist? && tgt
      PokeAccess.speak(parts.join(". "), true)
    end

    # The assist lines: which cells still need lighting, which to switch off, or that it matches.
    def self.assist_phrases(d, tgt, states)
      need  = (0...states.length).select { |i| tgt[:pattern][i] && !states[i] }
      extra = (0...states.length).select { |i| !tgt[:pattern][i] && states[i] }
      out = []
      out.push(PokeAccess::I18n.t(:puzzle_need, :cells => cells_phrase(d, need))) unless need.empty?
      out.push(PokeAccess::I18n.t(:puzzle_remove, :cells => cells_phrase(d, extra))) unless extra.empty?
      out.push(PokeAccess::I18n.t(:puzzle_match)) if need.empty? && extra.empty?
      out
    end

    # The grid state spoken one row at a time.
    def self.grid_phrase(d, states)
      (0...d[:rows]).map do |r|
        cells = (0...d[:cols]).map { |c| PokeAccess::I18n.t(states[r * d[:cols] + c] ? :puzzle_on : :puzzle_off) }
        PokeAccess::I18n.t(:puzzle_row, :n => r + 1, :cells => cells.join(", "))
      end.join(". ")
    end

    # The indices a pattern wants lit.
    def self.lit_cells(pattern); (0...pattern.length).select { |i| pattern[i] }; end

    # A comma-separated list of cell names, or the empty-set phrase.
    def self.cells_phrase(d, idxs)
      idxs.empty? ? PokeAccess::I18n.t(:puzzle_none) : idxs.map { |i| cell_name(d, i) }.join(", ")
    end

    # ---- state puzzles ----

    # True while a state puzzle with watched flags is unsolved; gates its info-key readout. An
    # obstacles-only puzzle (no :watch) does not hijack the info key, so it would read nothing.
    def self.state_active?(d)
      return false unless d[:watch] && !d[:watch].empty?
      !(d[:solved] && (d[:solved].call rescue false))
    end

    # The boolean value of one watched flag (a switch, or a variable at/above :min, default 1).
    def self.flag_value(w)
      if w[:switch]
        !!$game_switches[w[:switch]]
      elsif w[:var]
        ($game_variables[w[:var]] || 0) >= (w[:min] || 1)
      else
        false
      end
    rescue StandardError
      false
    end

    # The current boolean value of every watched flag.
    def self.state_values(d); (d[:watch] || []).map { |w| flag_value(w) }; end

    # State frame: announces each watched flag as it flips, then the win once. The first frame on the
    # puzzle (or after re-entering) only snapshots, so walking in stays silent.
    def self.state_tick(d)
      cur = state_values(d)
      if @sp_last.nil? || @sp_last.length != cur.length
        @sp_last = cur
        @sp_solved = (d[:solved] ? (d[:solved].call rescue false) : false)
        return
      end
      cur.each_index { |i| announce_flag(d[:watch][i], cur[i]) if cur[i] != @sp_last[i] }
      @sp_last = cur
      if d[:solved] && !@sp_solved && (d[:solved].call rescue false)
        @sp_solved = true
        PokeAccess.speak(label_of(d[:solved_msg]), false) if d[:solved_msg]
      end
    end

    # Speaks one watched flag's label and new state.
    def self.announce_flag(w, on)
      PokeAccess.speak("#{label_of(w[:label])}: #{label_of(on ? w[:on] : w[:off])}", false)
    end

    # The info-key readout for a state puzzle: every watched flag's label and state, plus the def's hint
    # when assist is on.
    def self.state_read(d)
      parts = (d[:watch] || []).map { |w| "#{label_of(w[:label])}: #{label_of(flag_value(w) ? w[:on] : w[:off])}" }
      parts.push(label_of(d[:hint])) if assist? && d[:hint]
      PokeAccess.speak(parts.join(". "), true)
    end

    # ---- facing puzzles (rotatable statues) ----

    # RPG direction code => the spoken compass key for a statue's facing (top-down map: up = north).
    FACE = { 8 => :face_north, 2 => :face_south, 4 => :face_west, 6 => :face_east }

    # The spoken compass name of a facing (an rpg maker direction code 2/4/6/8).
    def self.face_name(dir); PokeAccess::I18n.t(FACE[dir] || :face_south); end

    # True if an event currently shows the statue sprite the def matches (all four facings share the same
    # sprite, so this holds whichever way the bust is turned).
    def self.statue?(ev, d)
      m = d[:match]
      !!(m && ((ev.character_name.to_s rescue "") =~ m))
    rescue StandardError
      false
    end

    # The statue events on the current map, cached (events are static per map).
    def self.facing_statues(d)
      return [] unless $game_map
      mid = $game_map.map_id
      return @statues if @statues && @statues_map == mid
      @statues_map = mid
      @statues = $game_map.events.values.select { |ev| statue?(ev, d) }
    rescue StandardError
      []
    end

    # Facing frame: announces a statue's new facing when the player rotates it (its direction changes).
    # The first frame on a map only snapshots, so walking in stays silent.
    def self.facing_tick(d)
      cur = {}
      facing_statues(d).each { |ev| cur[[ev.x, ev.y]] = (ev.direction rescue 2) }
      if @face_last.nil?
        @face_last = cur
        return
      end
      cur.each { |pos, dir| announce_facing(d, pos, dir) if @face_last[pos] && @face_last[pos] != dir }
      @face_last = cur
    end

    # Speaks a statue's facing after a turn, plus (assist) its goal facing or that it is now correct.
    def self.announce_facing(d, pos, dir)
      msg = "#{label_of(d[:label])}: #{face_name(dir)}"
      tgt = d[:targets] && d[:targets][pos]
      if tgt && assist?
        msg += ". " + (dir == tgt ? PokeAccess::I18n.t(:statue_ok) : PokeAccess::I18n.t(:statue_goal, :dir => face_name(tgt)))
      end
      PokeAccess.speak(msg, true)
    end

    # The info-key readout: the statue the player faces (or every one on the map if none is in front),
    # each with its facing and (assist) its goal -- so a bust's orientation can be checked without rotating it.
    def self.facing_read(d)
      sts = facing_statues(d)
      return if sts.empty?
      fx, fy = PokeAccess::Spatial.front_tile
      front = sts.find { |ev| ev.x == fx && ev.y == fy }
      list = front ? [front] : sts
      parts = list.map do |ev|
        dir = (ev.direction rescue 2)
        s = "#{label_of(d[:label])}: #{face_name(dir)}"
        tgt = d[:targets] && d[:targets][[ev.x, ev.y]]
        s += " (#{dir == tgt ? PokeAccess::I18n.t(:statue_ok) : PokeAccess::I18n.t(:statue_goal, :dir => face_name(tgt))})" if tgt && assist?
        s
      end
      PokeAccess.speak(parts.join(". "), true)
    end

    # ---- obstacles (puzzle-scoped, so no hidden wall elsewhere is ever revealed) ----

    # The obstacle kind of an event per the current puzzle's :obstacles list (each entry
    # { :match => /sprite regex/, :kind => :wall|:mover }), or nil off a puzzle map or for a non-obstacle
    # sprite. Backs the positional-audio obstacle cue; only sprites the puzzle declares ever sound.
    def self.obstacle_kind(ev)
      d = current
      obs = d && d[:obstacles]
      return nil unless obs
      cn = (ev.character_name.to_s rescue "")
      return nil if cn.empty?
      hit = obs.find { |o| cn =~ o[:match] }
      hit && (hit[:kind] || :wall)
    rescue StandardError
      nil
    end

    # The targets the locator's "puzzles" category lists: a grid's cells (synthetic tile targets, so each
    # can be found and routed to) or, for a state puzzle, its controls (cranks/valves, labelled by colour)
    # plus its static obstacle walls. Moving hazards are left out (they go stale; they still sound in 3D).
    def self.category_targets
      d = current
      return [] unless d
      if kind(d) == :grid && d[:cells]
        names = d[:names] || GRID3
        (0...d[:cells].length).map do |i|
          c = d[:cells][i]
          PokeAccess::Locator::SurfaceTarget.new(c[0], c[1], label_of(names[i]), :puzzle_cell)
        end
      elsif kind(d) == :facing
        facing_statues(d).map { |ev| PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, label_of(d[:label]), :statue) }
      else
        ctrls = controls.map { |c| ev = c[0]; PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, label_of(c[1][:label]), :puzzle_control) }
        walls = cluster_walls($game_map.events.values.select { |ev| obstacle_kind(ev) == :wall })
        ctrls + walls
      end
    rescue StandardError
      []
    end

    # Merges contiguous same-sprite wall tiles into one target each (so a long geyser/steam wall is a
    # single entry, not dozens), reusing the positional-audio clusterer; falls back to the raw list if
    # it is unavailable.
    def self.cluster_walls(walls)
      return walls if walls.length <= 1
      list = walls.map { |ev| [ev.x, ev.y, 0, (ev.character_name.to_s rescue "")] }
      reps = (PokeAccess::Audio3D.cluster(list) rescue nil)
      return walls unless reps
      reps.map { |r| walls.find { |ev| ev.x == r[0] && ev.y == r[1] } }.compact
    rescue StandardError
      walls
    end

    # True when the current puzzle declares a moving hazard (:mover); lets the positional audio refresh
    # those emitters live each frame, only where needed.
    def self.has_movers?
      d = current
      obs = d && d[:obstacles]
      !!(obs && obs.any? { |o| o[:kind] == :mover })
    rescue StandardError
      false
    end

    # Drops the cached obstacle list so the next look rescans the map.
    #
    # Called from the same event-end hook that invalidates the pathfinder caches, which is the moment a
    # switch an event just wrote can have raised one barrier and lowered another. Keyed on the map alone,
    # the list froze the room as it stood when the player walked in: a barrier raised afterwards never
    # became an obstacle, and one lowered went on warning forever.
    def self.forget_obstacles
      @obs_events = nil
      @obs_map = nil
    end

    # True if a puzzle obstacle event sits on tile (x,y).
    def self.obstacle_at?(x, y)
      return false unless $game_map
      obstacle_events.any? { |ev| ev.x == x && ev.y == y }
    rescue StandardError
      false
    end

    # The events the puzzle declares as obstacles, cached until an event ends. A map's events are never
    # created or destroyed, but WHICH of them is an obstacle is read off the current page's graphic, and
    # swapping that page is exactly what a puzzle switch does -- so the map, alone, is not enough of a key.
    def self.obstacle_events
      mid = ($game_map.map_id rescue 0)
      if @obs_events.nil? || @obs_map != mid
        @obs_map = mid
        @obs_events = $game_map.events.values.select { |ev| obstacle_kind(ev) }
      end
      @obs_events
    rescue StandardError
      []
    end

    # Speaks a heads-up the moment the player becomes newly adjacent to a puzzle obstacle (debounced by
    # tile, so it fires once per approach). The spoken layer; the positional audio pans the obstacle in
    # 3D when enabled, but the warning works with positional audio off too.
    # The key includes the ADJACENCY, not just the player's tile. A moving obstacle approaches a standing
    # player -- exactly the case to warn about -- and keyed on position alone that case left through the
    # return above without checking anything. The obstacle list is cached per map, so looking at the four
    # neighbouring tiles every frame walks a handful of events, not the whole map's.
    def self.obstacle_tick(d)
      px = $game_player.x; py = $game_player.y
      mid = ($game_map.map_id rescue 0)
      adj = [[px - 1, py], [px + 1, py], [px, py - 1], [px, py + 1]].any? { |x, y| obstacle_at?(x, y) }
      sig = [px, py, mid, adj]
      return if @obs_pos == sig
      was = @obs_adj
      @obs_pos = sig
      @obs_adj = adj
      PokeAccess.speak(label_of(d[:obstacle_warn] || :obstacle_near), false) if adj && !was
    end

    # ---- controls (the invisible cranks/valves that flip a watched flag) ----

    # The player-toggleable events that write a watched switch/variable, each paired with the watch entry
    # it controls. These are the graphic-less cranks/valves, found by what they DO, not by a sprite.
    # Cached per map (events are static).
    def self.controls
      d = current
      return [] unless d && d[:watch] && $game_map
      mid = $game_map.map_id
      return @controls if @controls && @controls_map == mid
      @controls_map = mid
      @controls = build_controls(d)
    end

    # Scans the map's events for player-initiated ones whose commands set a watched flag, pairing each
    # with its watch entry. Autorun/parallel controllers are skipped (no player-pressable trigger).
    def self.build_controls(d)
      out = []
      $game_map.events.each_value do |ev|
        rev = PokeAccess.ivar(ev, :@event)
        pages = (rev && rev.pages) || []
        next unless pages.any? { |pg| ((pg.trigger rescue 5)) <= 2 }
        w = d[:watch].find { |e| pages.any? { |pg| page_writes_flag?(pg, e) } }
        out.push([ev, w]) if w
      end
      out
    rescue StandardError
      []
    end

    # True if a page's command list sets the switch (code 121) or variable (code 122) a watch tracks.
    def self.page_writes_flag?(pg, w)
      list = (pg.list rescue nil) || []
      list.any? do |cmd|
        code = (cmd.code rescue nil); pr = (cmd.parameters rescue nil) || []
        if w[:switch] && code == 121
          pr[0] && pr[1] && w[:switch] >= pr[0] && w[:switch] <= pr[1]
        elsif w[:var] && code == 122
          pr[0] && pr[1] && w[:var] >= pr[0] && w[:var] <= pr[1]
        else
          false
        end
      end
    rescue StandardError
      false
    end

    # True if an event is a tracked control (crank/valve); backs the positional-audio cue.
    def self.control?(ev)
      controls.any? { |c| c[0].equal?(ev) }
    rescue StandardError
      false
    end

    # The spoken label for a control event (e.g. "Manivela roja"), or nil.
    def self.control_label(ev)
      c = controls.find { |e| e[0].equal?(ev) }
      c && label_of(c[1][:label])
    rescue StandardError
      nil
    end

    # Resolves a label/state/message: an i18n symbol is translated, a string is used verbatim.
    def self.label_of(x)
      return "" if x.nil?
      x.is_a?(Symbol) ? PokeAccess::I18n.t(x) : x.to_s
    end

    # True when the optional spoiler assist is enabled.
    def self.assist?; PokeAccess::Config.puzzle_assist rescue false; end
  end
end

# Drop puzzle state on map change (Caches.reset_all). Most puzzle caches self-invalidate by map_id, but
# @sp_last / @face_last only clear in reset_state (called when a map has NO puzzle); jumping straight
# between two puzzle maps would otherwise carry them over and could mis-announce a flip/turn on entry.
PokeAccess::Caches.register(:puzzles) { PokeAccess::Puzzles.reset_state }
