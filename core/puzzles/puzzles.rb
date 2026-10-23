module PokeAccess
  # Map puzzles as the player hears them, over the model World::Mechanics keeps: each frame's changes said with the
  # interrupt rule each has, the info key's readout, the locator's puzzles category, and the one spoiler policy
  # (assist?). Labels, states and messages go through label_of.
  module Puzzles
    # Cell-name keys of a 3x3 grid in reading order.
    GRID3 = [:cell_tl, :cell_tc, :cell_tr, :cell_ml, :cell_c, :cell_mr, :cell_bl, :cell_bc, :cell_br]
    # RPG direction code => the spoken compass key for a statue's facing (top-down map: up = north).
    FACE = { 8 => :face_north, 2 => :face_south, 4 => :face_west, 6 => :face_east }
    # The tiles beside the player as [dx, dy, the side's key], in the order an obstacle's sides are said.
    SIDES = [[-1, 0, :side_left], [1, 0, :side_right], [0, -1, :side_up], [0, 1, :side_down]]

    # One map frame: the mechanic's changes, said; the queue is emptied even when the frame fails.
    def self.tick
      mech = PokeAccess::World::Mechanics
      changes = []
      begin
        mech.update
      ensure
        changes = mech.drain
      end
      inst = mech.instance
      changes.each { |c| say(inst.spec, c) } if inst
    end

    # Says one change.
    def self.say(spec, c)
      case c[0]
      when :solved   then PokeAccess.speak(label_of(c[1]), false)
      when :target   then announce_target(spec, c[1], c[2])
      when :tone     then tone(spec, c[1])
      when :cell     then PokeAccess.speak(cell_phrase(c[1], c[2]), true)
      when :watch    then PokeAccess.speak(watch_phrase(spec[:watch][c[1]], c[2]), false)
      when :facing   then PokeAccess.speak(facing_phrase(spec, c[1], c[2]), true)
      when :near     then PokeAccess.speak(near_phrase(spec, c[1]), false)
      when :arrival_hint
        PokeAccess.speak(label_of(spec[:arrival_hint]), false) if PokeAccess::Verbosity.descriptions?
      else say_phase(c)
      end
    end

    # True while the current puzzle answers the info key.
    def self.active?
      inst = PokeAccess::World::Mechanics.instance
      return false unless inst
      spec = inst.spec
      case inst.kind
      when :grid then PokeAccess::World::Mechanics.truth(spec[:active])
      when :facing then !PokeAccess::World::Mechanics.pieces(:statue).empty?
      else state_active?(spec)
      end
    end

    # True while a :state puzzle answers the info key: its own test; else, with phases, while one is live; else, with
    # watched flags or an info line, until solved.
    def self.state_active?(spec)
      return PokeAccess::World::Mechanics.truth(spec[:active]) if spec[:active]
      return phases_active?(spec) if spec[:phases]
      return false if (spec[:watch] || []).empty? && !spec[:info]
      !PokeAccess::World::Mechanics.truth(spec[:solved])
    end

    # The info key's line on the map while the current puzzle answers it, else nil: only with the map in control and
    # the locator keys free, since a puzzle with no solved state stays active all session.
    def self.info_line
      return nil unless PokeAccess::Control.keys? && PokeAccess::Control.scene_map? && active?
      inst = PokeAccess::World::Mechanics.instance
      spec = inst.spec
      case inst.kind
      when :grid then grid_line(spec)
      when :facing then facing_line(spec)
      else state_line(spec)
      end
    end

    # A :state puzzle's line, its phase's or its flags', closed by the room's rule (arrival_hint), which is said on
    # arrival only in full.
    def self.state_line(spec)
      line = spec[:phases] ? phases_line(spec) : flags_line(spec)
      rule = spec[:arrival_hint]
      line && rule ? PokeAccess.sentences([line, label_of(rule)]) : line
    end

    # A :state puzzle without phases: its info line, or every watched flag's label and state, and with assist the hint
    # and what each control would do to the walls after it.
    def self.flags_line(spec)
      parts = spec[:info] ? [label_of(spec[:info])] : flag_phrases(spec)
      if assist?
        parts.push(label_of(spec[:hint])) if spec[:hint]
        parts.concat(control_hints(spec))
      end
      PokeAccess.sentences(parts)
    end

    # True for a puzzle target the player steps onto rather than faces: a grid's cell, or a control fired by touch
    # that can be walked onto (a floor plate).
    def self.onto?(t)
      return false unless t.is_a?(PokeAccess::Locator::SurfaceTarget)
      return true if t.key == :puzzle_cell
      return false unless t.key == :puzzle_control
      ev = ($game_map.events[t.ref] rescue nil)
      ev ? PokeAccess::Routes::Controls.plate?(ev) : false
    end

    # True when the puzzles category has something to list.
    def self.has_locator_targets?
      !category_targets.empty?
    end

    # The locator's puzzles category: a grid's cells, the statues, or a :state's spots, its phase's targets, its
    # controls and its walls clustered (movers are left out; they still sound).
    def self.category_targets
      inst = PokeAccess::World::Mechanics.instance
      return [] unless inst
      spec = inst.spec
      case inst.kind
      when :grid then cell_targets(spec)
      when :facing then statue_targets(spec)
      else spot_targets(spec[:spots]) + (spec[:phases] ? phase_targets(spec) : []) + control_targets
      end
    end

    # ---- grids ----

    # A new letter to form, as the next one once one was formed, with assist the cells it lights.
    def self.announce_target(spec, tgt, advanced)
      msg = PokeAccess::I18n.t(advanced ? :puzzle_next : :puzzle_form, :name => tgt[:name])
      msg += ". " + PokeAccess::I18n.t(:puzzle_light, :cells => cells_phrase(lit_cells(tgt[:pattern]))) if assist?
      PokeAccess.speak(msg, false)
    end

    # Plays a cell's locating tone: panned by its column, pitched by its row.
    def self.tone(spec, i)
      PokeAccess::Sound.cell(i % spec[:cols], i / spec[:cols])
    end

    # A cell's name and lit state.
    def self.cell_phrase(i, on)
      "#{PokeAccess::I18n.t(GRID3[i])}, #{PokeAccess::I18n.t(on ? :puzzle_on : :puzzle_off)}"
    end

    # The readout while active: the letter, the grid row by row and, with assist, the cells still to light or to put
    # out to match it; nil while inactive.
    def self.grid_line(spec)
      return nil unless PokeAccess::World::Mechanics.truth(spec[:active])
      states = PokeAccess::World::Mechanics::Grid.states(spec)
      tgt = PokeAccess::World::Mechanics::Grid.target(spec)
      parts = []
      parts.push(PokeAccess::I18n.t(:puzzle_form, :name => tgt[:name])) if tgt
      parts.push(grid_phrase(spec, states))
      parts.concat(assist_phrases(tgt, states)) if assist? && tgt
      parts.join(". ")
    end

    # The cells still to light, those to put out, or that it matches.
    def self.assist_phrases(tgt, states)
      need = (0...states.length).select { |i| tgt[:pattern][i] && !states[i] }
      extra = (0...states.length).select { |i| !tgt[:pattern][i] && states[i] }
      out = []
      out.push(PokeAccess::I18n.t(:puzzle_need, :cells => cells_phrase(need))) unless need.empty?
      out.push(PokeAccess::I18n.t(:puzzle_remove, :cells => cells_phrase(extra))) unless extra.empty?
      out.push(PokeAccess::I18n.t(:puzzle_match)) if need.empty? && extra.empty?
      out
    end

    # The grid spoken a row at a time.
    def self.grid_phrase(spec, states)
      cols = spec[:cols]
      (0...spec[:rows]).map do |r|
        cells = (0...cols).map { |c| PokeAccess::I18n.t(states[r * cols + c] ? :puzzle_on : :puzzle_off) }
        PokeAccess::I18n.t(:puzzle_row, :n => r + 1, :cells => cells.join(", "))
      end.join(". ")
    end

    # The indices a pattern lights.
    def self.lit_cells(pattern); (0...pattern.length).select { |i| pattern[i] }; end

    # Cell names joined, or the empty-set phrase.
    def self.cells_phrase(idxs)
      idxs.empty? ? PokeAccess::I18n.t(:puzzle_none) : idxs.map { |i| PokeAccess::I18n.t(GRID3[i]) }.join(", ")
    end

    # The cells as targets, by name.
    def self.cell_targets(spec)
      (spec[:cells] || []).each_with_index.map do |c, i|
        PokeAccess::Locator::SurfaceTarget.new(c[0], c[1], PokeAccess::I18n.t(GRID3[i]), :puzzle_cell)
      end
    end

    # ---- watched flags ----

    # One watched flag's label and state.
    def self.flag_phrase(w, on)
      "#{label_of(w[:label])}: #{label_of(on ? w[:on] : w[:off])}"
    end

    # Every watched flag's label and state.
    def self.flag_phrases(spec)
      (spec[:watch] || []).map { |w| flag_phrase(w, PokeAccess::World::Mechanics::State.flag(w)) }
    end

    # A watched flag that flipped, then what the flip did to the walls, as the screen shows it.
    def self.watch_phrase(w, on)
      inst = PokeAccess::World::Mechanics.instance
      PokeAccess.sentences([flag_phrase(w, on)].concat(inst ? wall_phrases(inst, w, true) : []))
    end

    # What each control of the map would do to the walls if flipped now, in watch order, one line a control that
    # changes any.
    def self.control_hints(spec)
      inst = PokeAccess::World::Mechanics.instance
      return [] unless inst && spec[:obstacles]
      ctrls = inst.controls.values
      (spec[:watch] || []).map do |w|
        next nil unless ctrls.any? { |c| c.equal?(w) }
        lines = wall_phrases(inst, w)
        next nil if lines.empty?
        PokeAccess::I18n.t(:ctrl_hint, :what => label_of(w[:label]), :changes => lines.join(". "))
      end.compact
    end

    # What flipping watch entry w's flag does to the walls (World::Mechanics::Links), a phrase per wall label with how
    # many go and how many come, those that go first, each in the order the declaration names them; done, the flip
    # just made, else the one to come.
    def self.wall_phrases(inst, w, done = false)
      counts = {}
      PokeAccess::World::Mechanics::Links.effects(inst, w).each do |_ev, what, label|
        key = label || :obstacle_group
        counts[key] ||= { :open => 0, :close => 0 }
        counts[key][done ? (what == :open ? :close : :open) : what] += 1
      end
      return [] if counts.empty?
      rank = {}
      inst.spec[:obstacles].each_with_index { |o, i| rank[o[:label]] ||= i if o[:label] }
      order = counts.keys.sort_by { |k| rank[k] || inst.spec[:obstacles].length }
      going, coming = order.partition { |k| counts[k][:open] > 0 }
      going.concat(coming).map do |k|
        parts = []
        parts.push(PokeAccess::I18n.t(:ctrl_quit, :n => counts[k][:open])) if counts[k][:open] > 0
        parts.push(PokeAccess::I18n.t(:ctrl_rise, :n => counts[k][:close])) if counts[k][:close] > 0
        PokeAccess::I18n.t(:ctrl_group, :what => label_of(k), :changes => parts.join(", "))
      end
    end

    # The obstacles that came beside the player (pieces), a group at a time in the order the declaration names them:
    # its name (group_name) and the sides it is on.
    def self.near_phrase(spec, pieces)
      px = $game_player.x
      py = $game_player.y
      groups = spec[:obstacles].map { |o| [o[:label], o[:kind] == :mover] }.uniq
      lines = groups.map do |label, moving|
        mine = pieces.select { |p| p.label == label && p.moving == moving }
        sides = SIDES.select { |dx, dy, _key| mine.any? { |p| p.ev.x == px + dx && p.ev.y == py + dy } }
        next nil if sides.empty?
        words = sides.map { |s| PokeAccess::I18n.t(s[2]) }
        "#{group_name(label, moving)}, #{PokeAccess::Routes::Text.and_list(words)}"
      end
      PokeAccess.sentences(lines.compact)
    end

    # A group of obstacles by name: what moves, a moving trap; a wall, its label, else the obstacle word.
    def self.group_name(label, moving)
      return PokeAccess::I18n.t(:obstacle_trap) if moving
      label ? label_of(label) : PokeAccess::I18n.t(:obstacle_near)
    end

    # The name a mechanic's declaration gives a wall event, or nil.
    def self.wall_name(ev)
      piece = PokeAccess::World::Mechanics.piece_of(ev)
      piece && piece.role == :obstacle && piece.label ? label_of(piece.label) : nil
    end

    # The controls as targets, by their watch label, then the walls clustered.
    def self.control_targets
      mech = PokeAccess::World::Mechanics
      ctrls = mech.pieces(:control).map do |p|
        PokeAccess::Locator::SurfaceTarget.new(p.ev.x, p.ev.y, label_of(p.label), :puzzle_control, p.ev.id)
      end
      ctrls + cluster_walls(mech.pieces(:obstacle).reject { |p| p.moving }.map { |p| p.ev })
    end

    # Merges touching same-graphic walls into one target each (Sound::Scene.cluster), else the list as it is.
    def self.cluster_walls(walls)
      return walls if walls.length <= 1
      list = walls.map { |ev| [ev.x, ev.y, 0, (ev.character_name.to_s rescue "")] }
      reps = (PokeAccess::Sound::Scene.cluster(list) rescue nil)
      return walls unless reps
      reps.map { |r| walls.find { |ev| ev.x == r[0] && ev.y == r[1] } }.compact
    end

    # ---- statues ----

    # The spoken compass name of a facing.
    def self.face_name(dir); PokeAccess::I18n.t(FACE[dir] || :face_south); end

    # A statue's facing after a turn, with assist its goal or that it is right.
    def self.facing_phrase(spec, pos, dir)
      msg = "#{label_of(spec[:label])}: #{face_name(dir)}"
      tgt = spec[:targets] && spec[:targets][pos]
      return msg unless tgt && assist?
      msg + ". " + statue_verdict(dir, tgt)
    end

    # That a statue faces its goal, or the facing it should take.
    def self.statue_verdict(dir, tgt)
      dir == tgt ? PokeAccess::I18n.t(:statue_ok) : PokeAccess::I18n.t(:statue_goal, :dir => face_name(tgt))
    end

    # The statue in front, else every one, nearest first with where it stands from the player: its facing and, with
    # assist, its goal; nil with none.
    def self.facing_line(spec)
      sts = PokeAccess::World::Mechanics.pieces(:statue).map { |p| p.ev }
      return nil if sts.empty?
      fx, fy = PokeAccess::Control.front_tile
      front = sts.find { |ev| ev.x == fx && ev.y == fy }
      return statue_phrase(spec, front, "") if front
      px = $game_player.x
      py = $game_player.y
      sts.sort_by { |ev| (ev.x - px).abs + (ev.y - py).abs }.map do |ev|
        statue_phrase(spec, ev, offset_phrase(ev.x - px, ev.y - py))
      end.join(". ")
    end

    # One statue's facing, after where it stands (dist, an offset_phrase; empty for none) and, with assist, its goal.
    def self.statue_phrase(spec, ev, dist)
      dir = (ev.direction rescue 2)
      name = label_of(spec[:label])
      s = if dist.empty? then "#{name}: #{face_name(dir)}"
          else PokeAccess::I18n.t(:statue_where, :label => name, :dist => dist, :dir => face_name(dir))
          end
      tgt = spec[:targets] && spec[:targets][[ev.x, ev.y]]
      s += " (#{statue_verdict(dir, tgt)})" if tgt && assist?
      s
    end

    # The statues as targets.
    def self.statue_targets(spec)
      PokeAccess::World::Mechanics.pieces(:statue).map do |p|
        PokeAccess::Locator::SurfaceTarget.new(p.ev.x, p.ev.y, label_of(spec[:label]), :statue, p.ev.id)
      end
    end

    # Resolves a label, state or message: a symbol through i18n, a string as is, a [symbol, {interpolations}] pair
    # through i18n with them, and a lambda by asking it each time.
    def self.label_of(x)
      return "" if x.nil?
      return label_of(x.call) if x.respond_to?(:call)
      return PokeAccess::I18n.t(x[0], x[1] || {}) if x.is_a?(Array)
      x.is_a?(Symbol) ? PokeAccess::I18n.t(x) : x.to_s
    end

    # True when the optional spoiler assist is on; the only reader of Config.puzzle_assist.
    def self.assist?; PokeAccess::Config.puzzle_assist rescue false; end
  end
end

# The puzzles answer the info key on the map first, save while the player stands where a forced move left them: that
# move's line (ForcedMove.line, then the ways on terrain that moves the player: Info.map_text) wins then.
PokeAccess::Info.map_owner(:puzzles) { PokeAccess::ForcedMove.line ? nil : PokeAccess::Puzzles.info_line }
