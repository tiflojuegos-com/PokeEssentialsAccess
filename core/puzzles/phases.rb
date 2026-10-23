module PokeAccess
  # The phases of a puzzle (its :phases, World::Mechanics::State) as the player hears them: a phase's title as it
  # opens, its numbers, counter and tracked event as they change, its readout and its targets. A label is an i18n
  # symbol, a literal string, [symbol, {interpolations}], or a lambda answering one of those.
  module Puzzles
    # Says a change within the phases.
    def self.say_phase(c)
      case c[0]
      when :phase    then announce_phase(c[1])
      when :value    then PokeAccess.speak(value_phrase(c[1], c[2]), false)
      when :progress then PokeAccess.speak(progress_phrase(c[1], c[2]), false) if progress_audible?(c[1], c[2])
      when :track    then say_track(track_phrase(c[1], c[2]))
      end
    end

    # Says the tracked event's line after a move: cutting its last one while nothing else was said since, and not at
    # all when the line said last already tells it (the guide's own end at the goal, Guide.arrive).
    def self.say_track(text)
      fresh = @track_seq != PokeAccess.spoken_seq
      return if fresh && PokeAccess.last_spoken == text
      PokeAccess.speak(text, !fresh)
      @track_seq = PokeAccess.spoken_seq
    end

    # True when text is the tracked event's line said last, nothing said since (say_track).
    def self.track_told?(text)
      !@track_seq.nil? && @track_seq == PokeAccess.spoken_seq && PokeAccess.last_spoken == text
    end

    # True while a phase is live and the puzzle is unsolved, and once solved when the win is the info key's to say
    # (:solved_quiet).
    def self.phases_active?(spec)
      if PokeAccess::World::Mechanics.truth(spec[:solved])
        return (spec[:solved_msg] && spec[:solved_quiet]) ? true : false
      end
      !PokeAccess::World::Mechanics::State.current_phase(spec).nil?
    end

    # A phase's title as it opens, and its hint with assist.
    def self.announce_phase(s)
      parts = [label_of(s[:title])]
      parts.push(label_of(s[:hint])) if assist? && s[:hint]
      t = parts.reject { |x| x.to_s.empty? }.join(". ")
      PokeAccess.speak(t, false) unless t.empty?
    end

    # Whether a counter is said now: an :assist one needs assist, a :hide_zero one a value above zero.
    def self.progress_audible?(p, value)
      return false if p[:assist] && !assist?
      return false if p[:hide_zero] && value.to_i <= 0
      true
    end

    # "label: n of total".
    def self.progress_phrase(p, value)
      PokeAccess::I18n.t(:puzzle_progress, :label => label_of(p[:label]), :n => value, :of => p[:of])
    end

    # "label: value".
    def self.value_phrase(v, value)
      PokeAccess::I18n.t(:puzzle_value, :label => label_of(v[:label]), :v => value)
    end

    # The tracked event after a move: with assist how far it still is from its goal, else its offset from the player.
    def self.track_phrase(t, pos)
      name = label_of(t[:label])
      if assist? && t[:goal]
        off = goal_offset(t[:goal], pos)
        return PokeAccess::I18n.t(:puzzle_track_in, :label => name, :goal => label_of(t[:goal_label])) if off.empty?
        return PokeAccess::I18n.t(:puzzle_track_goal, :label => name, :dist => off, :goal => label_of(t[:goal_label]))
      end
      rel = offset_phrase(pos[0] - $game_player.x, pos[1] - $game_player.y)
      rel.empty? ? name : PokeAccess::I18n.t(:puzzle_track_rel, :label => name, :dist => rel)
    end

    # How far a position still is from a goal box, as "N right, M down", or "" inside it.
    def self.goal_offset(goal, pos)
      x0, y0, x1, y1 = goal
      dx = pos[0] < x0 ? x0 - pos[0] : (pos[0] > x1 ? x1 - pos[0] : 0)
      dy = pos[1] < y0 ? y0 - pos[1] : (pos[1] > y1 ? y1 - pos[1] : 0)
      offset_phrase(dx, dy)
    end

    # An offset spoken the way the step guide speaks a leg: "3 right, 1 down".
    def self.offset_phrase(dx, dy)
      parts = []
      parts.push("#{dx.abs} #{PokeAccess::I18n.t(dx > 0 ? :dir_right : :dir_left)}") if dx != 0
      parts.push("#{dy.abs} #{PokeAccess::I18n.t(dy > 0 ? :dir_down : :dir_up)}") if dy != 0
      parts.join(", ")
    end

    # The readout: the phase's title, its counter, its numbers and their sum, the tracked event and, with assist, the
    # hint; the win once solved.
    def self.phases_line(spec)
      state = PokeAccess::World::Mechanics::State
      if PokeAccess::World::Mechanics.truth(spec[:solved])
        return spec[:solved_msg] ? label_of(spec[:solved_msg]) : nil
      end
      s = state.current_phase(spec)
      return nil unless s
      parts = [label_of(s[:title])]
      pv = state.progress(s)
      parts.push(progress_phrase(s[:progress], pv)) if pv && progress_audible?(s[:progress], pv)
      vals = state.values(s)
      unless vals.empty?
        parts.push((0...vals.length).map { |k| value_phrase(s[:values][k], vals[k]) }.join(", "))
        parts.push(PokeAccess::I18n.t(:puzzle_sum, :n => vals.inject(0) { |a, b| a + b })) if s[:sum]
      end
      pos = state.track(s)
      parts.push(track_phrase(s[:track], pos)) if pos
      parts.push(label_of(s[:hint])) if assist? && s[:hint]
      parts.reject { |x| x.to_s.empty? }.join(". ")
    end

    # The locator targets for the current phase: its spots, each number's tile, the hidden spots still to find, the
    # tracked event and, with assist, its goal.
    def self.phase_targets(spec)
      state = PokeAccess::World::Mechanics::State
      s = state.current_phase(spec)
      return [] unless s
      out = spot_targets(s[:spots])
      vals = state.values(s)
      (s[:values] || []).each_with_index do |v, k|
        ev = ($game_map.events[v[:event]] rescue nil)
        next unless ev
        out.push(PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, value_phrase(v, vals[k]), :puzzle_value, ev.id))
      end
      h = s[:hidden]
      out.concat(hidden_targets(h)) if h && (!h[:assist] || assist?)
      t = s[:track]
      tev = t && ($game_map.events[t[:event]] rescue nil)
      out.push(tev) if tev
      if assist? && t && t[:goal]
        g = t[:goal]
        mid = (g[1] + g[3]) / 2
        out.push(PokeAccess::Locator::SurfaceTarget.new(g[0], mid, label_of(t[:goal_label]), :puzzle_goal, t[:event]))
      end
      out
    end

    # With the assist, the way to push the current phase's tracked piece into its goal, for that goal's target
    # (Routes::Planner.carry), the list saying how far the piece still is from it (its gate's :listing) in place of
    # what stands in the way; nil for any other target.
    def self.carry_plan(t)
      tr, ev = carried_piece(t)
      return nil unless ev
      plan = PokeAccess::Routes::Planner.carry(ev, tr[:goal])
      return plan unless plan.kind == :assisted
      plan.gate = plan.gate.dup
      plan.gate[:listing] = track_phrase(tr, [ev.x, ev.y])
      plan
    end

    # With the assist, what to say for the route to the current phase's goal (target t) once its piece is inside the
    # box, the phase still open: the piece's own line (puzzle_track_in), not the empty way there; nil otherwise.
    def self.carried_line(t)
      tr, ev = carried_piece(t)
      return nil unless ev && goal_offset(tr[:goal], [ev.x, ev.y]).empty?
      track_phrase(tr, [ev.x, ev.y])
    end

    # The current phase's tracked piece for its goal target t, as [track, event], with the assist on; nil otherwise.
    def self.carried_piece(t)
      return nil unless assist? && t.is_a?(PokeAccess::Locator::SurfaceTarget) && t.key == :puzzle_goal
      inst = PokeAccess::World::Mechanics.instance
      s = inst && PokeAccess::World::Mechanics::State.current_phase(inst.spec)
      tr = s && s[:track]
      ev = tr && tr[:goal] && ($game_map.events[tr[:event]] rescue nil)
      ev ? [tr, ev] : nil
    end

    # Named points as targets: a fixed tile, or where an event stands.
    def self.spot_targets(spots)
      (spots || []).map do |sp|
        xy = sp[:at]
        unless xy
          ev = ($game_map.events[sp[:event]] rescue nil)
          xy = ev && [ev.x, ev.y]
        end
        xy ? PokeAccess::Locator::SurfaceTarget.new(xy[0], xy[1], label_of(sp[:label]), :puzzle_spot) : nil
      end.compact
    end

    # The hidden spots still to find: those whose event's live page still runs something.
    def self.hidden_targets(h)
      h[:events].map do |id|
        ev = ($game_map.events[id] rescue nil)
        next nil unless ev
        list = PokeAccess.ivar(ev, :@list)
        live = list.is_a?(Array) && list.any? { |c| (c.code rescue 0) != 0 }
        live ? PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, label_of(h[:label]), :puzzle_hidden, ev.id) : nil
      end.compact
    end
  end
end
