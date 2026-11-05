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

    # One map frame: the mechanics' changes, said, the queue emptied even when the frame fails; then what the map says
    # by itself.
    def self.tick
      mech = PokeAccess::World::Mechanics
      changes = []
      begin
        mech.update
      ensure
        changes = mech.drain
      end
      changes.each { |spec, c| say(spec, c) }
      Auto.tick
    end

    # Says one change.
    def self.say(spec, c)
      case c[0]
      when :solved   then PokeAccess.speak(label_of(c[1]), false)
      when :target   then announce_target(spec, c[1], c[2])
      when :tone     then tone(spec, c[1])
      when :cell     then PokeAccess.speak(cell_phrase(spec, c[1], c[2]), true)
      when :watch    then say_watch(spec, c[1], c[2])
      when :use      then say_use(c[1])
      when :facing   then PokeAccess.speak(facing_phrase(spec, c[1], c[2]), true)
      when :near     then PokeAccess.speak(near_phrase(spec, c[1]), false)
      when :arrival_hint then say_arrival(spec)
      else say_phase(c)
      end
    end

    # What on_use says of an event just used, read as it was used: its page changes what it reads. Nothing for an empty line.
    def self.say_use(use)
      line = label_of(use[:label])
      PokeAccess.speak(line, false) if !line.empty? && (!use[:assist] || assist?)
    end

    # A room's rule on arriving, when descriptions are on; with :once just the first time this session, as a room may reload
    # with each try.
    def self.say_arrival(spec)
      return unless PokeAccess::Verbosity.descriptions?
      key = [$game_map.map_id, spec[:arrival_hint]]
      @told ||= {}
      return if spec[:arrival_once] && @told[key]
      @told[key] = true
      PokeAccess.speak(label_of(spec[:arrival_hint]), false)
    end

    # True while a puzzle of the current map answers the info key.
    def self.active?
      PokeAccess::World::Mechanics.instances.any? { |inst| answers?(inst) }
    end

    # True while a mechanic answers the info key.
    def self.answers?(inst)
      spec = inst.spec
      case inst.kind
      when :grid then PokeAccess::World::Mechanics::Grid.live?(spec)
      when :facing then !PokeAccess::World::Mechanics.pieces_in(inst, :statue).empty?
      else state_active?(spec)
      end
    end

    # True while a :state puzzle answers the info key: its own test; else, with phases, while one is live; else, with
    # watched flags or an info line, until solved.
    def self.state_active?(spec)
      return PokeAccess::World::Mechanics.truth(spec[:active]) if spec[:active]
      return phases_active?(spec) if spec[:phases]
      return false if (spec[:watch] || []).reject { |w| w[:quiet] }.empty? && !spec[:info] && !spec[:counts]
      !PokeAccess::World::Mechanics.truth(spec[:solved])
    end

    # The info key's line on the map while a puzzle answers it, else nil: only with the map in control and the locator
    # keys free, since a puzzle with no solved state stays active all session.
    def self.info_line
      return nil unless PokeAccess::Control.keys? && PokeAccess::Control.scene_map?
      lines = PokeAccess::World::Mechanics.instances.select { |inst| answers?(inst) }.map { |inst| line_of(inst) }.compact
      lines.length > 1 ? PokeAccess.sentences(lines) : lines[0]
    end

    # A mechanic's line for the info key.
    def self.line_of(inst)
      case inst.kind
      when :grid then grid_line(inst.spec)
      when :facing then facing_line(inst)
      else state_line(inst.spec)
      end
    end

    # A :state puzzle's line, its phase's or its flags', closed by the room's rule (arrival_hint), which is said on
    # arrival only in full.
    def self.state_line(spec)
      line = spec[:phases] ? phases_line(spec) : flags_line(spec)
      rule = spec[:arrival_hint]
      line && rule ? PokeAccess.sentences([line, label_of(rule)]) : line
    end

    # A :state puzzle without phases: its info line, or every watched flag's label and state, its counts, and with assist
    # the hint and what each control would do to the walls after it.
    def self.flags_line(spec)
      parts = (spec[:info] ? [label_of(spec[:info])] : flag_phrases(spec)).concat(count_phrases(spec))
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

    # The locator's puzzles category: what each mechanic of the map lists, then what the map holds by itself (Auto.targets)
    # that they do not list already.
    def self.category_targets
      own = PokeAccess::World::Mechanics.instances.map { |inst| targets_of(inst) }.flatten
      refs = own.map { |t| t.is_a?(PokeAccess::Locator::SurfaceTarget) ? t.ref : t.id }
      own + Auto.targets.reject { |t| refs.include?(t.ref) }
    end

    # What a mechanic lists: a grid's cells, the statues, or a :state's spots, its phase's targets, its controls and its
    # walls clustered (movers are left out; they still sound); then what it names.
    def self.targets_of(inst)
      spec = inst.spec
      own = case inst.kind
            when :grid then cell_targets(spec)
            when :facing then statue_targets(inst)
            else spot_targets(spec[:spots]) + (spec[:phases] ? phase_targets(spec) : []) + control_targets(inst)
            end
      own + named_targets(inst)
    end

    # The events a mechanic's names list and no other role does, by that name.
    def self.named_targets(inst)
      mech = PokeAccess::World::Mechanics
      mech.pieces_in(inst, :named).reject { |p| (p.assist && !assist?) || (!p.listed.nil? && !mech.truth(p.listed, p.ev)) }.map do |p|
        PokeAccess::Locator::SurfaceTarget.new(p.ev.x, p.ev.y, label_of(p.label), :puzzle_control, p.ev.id)
      end
    end

    # True when a mechanic of the map leaves an event out of the lists (hide).
    def self.hidden_event?(ev)
      PokeAccess::World::Mechanics.instances.any? do |inst|
        (inst.spec[:hides] || []).any? do |h|
          (!h[:assist] || assist?) && PokeAccess::World::Mechanics.picks?(h[:events], ev)
        end
      end
    end

    # What a mechanic of the map says of a move of the game's (sent_back), or nil: of a kind, :teleport within the map, :map
    # onto it from another or :forced, the end of a move route; what lands in :to and leaves from :from while the event last
    # used is among :events.
    def self.sent_back_line(from, to, kind = :teleport)
      PokeAccess::World::Mechanics.instances.each do |inst|
        (inst.spec[:sent_back] || []).each do |b|
          next unless sent_kind(b) == kind && (kind != :map || b[:maps][from[2]])
          next unless within?(b[:to], to) && within?(b[:from], from) && Auto.last_used_among?(b[:events])
          line = label_of(b[:label])
          return line unless line.empty?
        end
      end
      nil
    end

    # The kind of move a sent_back speaks of.
    def self.sent_kind(b); b[:maps] ? :map : (b[:forced] ? :forced : :teleport); end

    # True when a place [x, y, ...] lies in what a sent_back asks: nothing, a tile [x, y] or a box [x0, x1, y0, y1].
    def self.within?(want, at)
      return true unless want
      return want[0] == at[0] && want[1] == at[1] if want.length == 2
      at[0] >= want[0] && at[0] <= want[1] && at[1] >= want[2] && at[1] <= want[3]
    end

    # ---- grids ----

    # A new letter to form, as the next one once one was formed, with assist the cells it lights.
    def self.announce_target(spec, tgt, advanced)
      msg = PokeAccess::I18n.t(advanced ? :puzzle_next : :puzzle_form, :name => tgt[:name])
      msg += ". " + PokeAccess::I18n.t(:puzzle_light, :cells => cells_phrase(lit_cells(tgt[:pattern]))) if assist?
      PokeAccess.speak(msg, false)
    end

    # Plays a cell's locating tone: panned by its column, pitched by its row, a grid of any size among the three of each.
    def self.tone(spec, i)
      col, row = PokeAccess::World::Mechanics::Grid.place(spec, i)
      PokeAccess::Sound.cell(col * 3 / [spec[:cols], 3].max, row * 3 / [spec[:rows], 3].max)
    end

    # A cell's name and state: a grid of events by its row and column and its state's word, else by its rune's name.
    def self.cell_phrase(spec, i, state)
      return "#{tile_place(spec, i)}: #{tile_word(spec, state)}" if spec[:tiles]
      "#{PokeAccess::I18n.t(GRID3[i])}, #{PokeAccess::I18n.t(state ? :puzzle_on : :puzzle_off)}"
    end

    # Where a cell of a grid of events lies, as its row and column from 1.
    def self.tile_place(spec, i)
      col, row = PokeAccess::World::Mechanics::Grid.place(spec, i)
      PokeAccess::I18n.t(:puzzle_tile_at, :r => row + 1, :c => col + 1)
    end

    # The word for a state of a grid of events: its own in :words, else on or off.
    def self.tile_word(spec, state)
      word = spec[:tile_words] && spec[:tile_words][state]
      word ? label_of(word) : PokeAccess::I18n.t(state ? :puzzle_on : :puzzle_off)
    end

    # The readout of a grid of events: how many are done, what lies to each side of the player and, with assist, the hint.
    def self.tiles_line(spec)
      states = PokeAccess::World::Mechanics::Grid.states(spec)
      parts = []
      if spec[:tile_count]
        done = states.select { |s| s == spec[:tile_done] }.length
        parts.push(PokeAccess::I18n.t(:puzzle_progress, :label => label_of(spec[:tile_count]), :n => done, :of => states.length))
      end
      SIDES.each do |dx, dy, key|
        i = spec[:cells].index([$game_player.x + dx, $game_player.y + dy])
        parts.push("#{PokeAccess::I18n.t(key)}: #{tile_word(spec, states[i])}") if i
      end
      parts.push(label_of(spec[:hint])) if assist? && spec[:hint]
      PokeAccess.sentences(parts)
    end

    # The readout while active: the letter, the grid row by row and, with assist, the cells still to light or to put
    # out to match it, or a grid of events' own; nil while inactive.
    def self.grid_line(spec)
      return nil unless PokeAccess::World::Mechanics::Grid.live?(spec)
      return tiles_line(spec) if spec[:tiles]
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

    # The cells as targets, by name; of a grid of events, those not done.
    def self.cell_targets(spec)
      return tile_targets(spec) if spec[:tiles]
      (spec[:cells] || []).each_with_index.map do |c, i|
        PokeAccess::Locator::SurfaceTarget.new(c[0], c[1], PokeAccess::I18n.t(GRID3[i]), :puzzle_cell)
      end
    end

    # A grid of events' cells not done yet, by their name and place: stood on when stepping on them works them.
    def self.tile_targets(spec)
      states = PokeAccess::World::Mechanics::Grid.states(spec)
      out = []
      spec[:cells].each_with_index do |c, i|
        next if states[i] == spec[:tile_done]
        ev = ($game_map.events[spec[:cell_events][i]] rescue nil)
        key = ev && PokeAccess::Routes::Controls.plate?(ev) ? :puzzle_cell : :puzzle_spot
        name = PokeAccess.sentences([label_of(spec[:tile_label]), tile_place(spec, i)])
        out.push(PokeAccess::Locator::SurfaceTarget.new(c[0], c[1], name, key, spec[:cell_events][i]))
      end
      out
    end

    # ---- watched flags ----

    # One watched flag's label and what it holds: a :say's line alone, a word or a number, or its on or off word.
    def self.flag_phrase(w, value)
      return (value && value != 0 ? label_of(w[:say]) : "") if w[:say]
      "#{label_of(w[:label])}: #{flag_word(w, value)}"
    end

    # What a watched flag's value is said as.
    def self.flag_word(w, value)
      return label_of(w[:words][value] || value.to_s) if w[:words]
      return value if w[:number]
      label_of(value ? w[:on] : w[:off])
    end

    # Every watched flag's label and state, but those that only say a line as they change.
    def self.flag_phrases(spec)
      (spec[:watch] || []).reject { |w| w[:say] || w[:quiet] }.map do |w|
        flag_phrase(w, PokeAccess::World::Mechanics::State.value(w))
      end
    end

    # Says a watched flag that changed, if it has something to say now.
    def self.say_watch(spec, i, value)
      line = watch_phrase(spec, spec[:watch][i], value)
      PokeAccess.speak(line, false) unless line.empty?
    end

    # A watched flag that changed, then what the change did to the walls, as the screen shows it.
    def self.watch_phrase(spec, w, value)
      inst = PokeAccess::World::Mechanics.instance_of(spec)
      PokeAccess.sentences([flag_phrase(w, value)].concat(inst ? wall_phrases(inst, w, true) : []))
    end

    # What each control of the map would do to the walls if flipped now, in watch order, one line a control that
    # changes any.
    def self.control_hints(spec)
      inst = PokeAccess::World::Mechanics.instance_of(spec)
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
      mech = PokeAccess::World::Mechanics
      groups = (spec[:obstacles].map { |o| [o[:label], o[:kind] == :mover] } + pieces.map { |p| mech.group_of(p) }).uniq
      lines = groups.map do |label, moving|
        mine = pieces.select { |p| mech.group_of(p) == [label, moving] }
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

    # The name a mechanic's declaration gives an event, a wall or one it names, or nil.
    def self.piece_name(ev)
      piece = PokeAccess::World::Mechanics.piece_of(ev)
      return nil unless piece && piece.label && (piece.role == :obstacle || piece.named)
      piece.assist && !assist? ? nil : label_of(piece.label)
    end

    # A mechanic's controls as targets, by their watch label or name, then its walls clustered.
    def self.control_targets(inst)
      mech = PokeAccess::World::Mechanics
      ctrls = mech.pieces_in(inst, :control).select { |p| p.listed.nil? || mech.truth(p.listed, p.ev) }.map do |p|
        PokeAccess::Locator::SurfaceTarget.new(p.ev.x, p.ev.y, label_of(p.label), :puzzle_control, p.ev.id)
      end
      ctrls + cluster_walls(mech.pieces_in(inst, :obstacle).reject { |p| p.moving }.map { |p| p.ev })
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
    def self.facing_line(inst)
      spec = inst.spec
      sts = PokeAccess::World::Mechanics.pieces_in(inst, :statue).map { |p| p.ev }
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

    # A mechanic's statues as targets.
    def self.statue_targets(inst)
      PokeAccess::World::Mechanics.pieces_in(inst, :statue).map do |p|
        PokeAccess::Locator::SurfaceTarget.new(p.ev.x, p.ev.y, label_of(inst.spec[:label]), :statue, p.ev.id)
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
