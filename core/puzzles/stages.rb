module PokeAccess
  # Multi-stage puzzles (kind :stages): challenges on one map, each live while its :when holds (tile numbers, a
  # counter, spots found by pressing action, an object pushed toward a goal).
  #
  # A stage (every key optional but :when):
  #   :when     ->{bool}                                live while true; the first live stage is current
  #   :title    label                                   read first by the info key
  #   :progress {:var, :of, :label, :assist, :announce, :hide_zero}
  #             a counter read as "label: n of total"; :assist keeps it for assist mode, :announce says it
  #             as it grows, :hide_zero keeps it quiet until it reaches 1
  #   :values   [{:var, :label, :event}]                numbers a tile shows, each change announced
  #   :sum      true                                    the values' total, read with them
  #   :spots    [{:at => [x, y] | :event => id, :label}]  named points the locator lists
  #   :hidden   {:events => [ids], :label, :assist}     spots found by pressing action, listed while the event
  #                                                     still has something to do (:assist lists them only
  #                                                     in assist mode)
  #   :track    {:event, :label, :goal => [x0, y0, x1, y1], :goal_label}
  #             an object pushed toward a zone: its moves are announced, and with assist how far it still is
  #   :hint     label                                   assist-only
  #   :quiet    true                                    for a stage the game itself announces: its title is
  #                                                     not said on entry, only by the info key
  # The definition itself may carry :spots (listed in every stage), :solved (->{bool}) and :solved_msg, and
  # :solved_quiet where the game says the win itself (the message is then the info key's alone).
  # A label is an i18n symbol, a literal string, [symbol, {interpolations}], or a lambda answering one of those.
  module Puzzles
    # The index of the current stage (the first live one), or nil when none is.
    def self.stage_index(d)
      (d[:stages] || []).index { |s| (s[:when].call rescue false) }
    end

    # The current stage, or nil.
    def self.stage_of(d)
      i = stage_index(d)
      i && d[:stages][i]
    end

    # Whether the puzzle is solved, by its own test.
    def self.stages_solved?(d)
      d[:solved] ? ((d[:solved].call rescue false) ? true : false) : false
    end

    # True while a stage is live and the puzzle is not solved, and once solved when the win is the info key's to say
    # (:solved_quiet); gates the info-key readout.
    def self.stages_active?(d)
      return (d[:solved_msg] && d[:solved_quiet]) ? true : false if stages_solved?(d)
      !stage_of(d).nil?
    end

    # The numbers a stage's tiles show, in order.
    def self.stage_values(s)
      (s[:values] || []).map { |v| ($game_variables[v[:var]] || 0).to_i }
    end

    # A stage's counter, or nil when it has none.
    def self.progress_value(s)
      p = s[:progress]
      p ? ($game_variables[p[:var]] || 0).to_i : nil
    end

    # Where a stage's tracked event stands, as [x, y], or nil.
    def self.track_pos(s)
      t = s[:track]
      ev = t && ($game_map.events[t[:event]] rescue nil)
      ev ? [ev.x, ev.y] : nil
    end

    # Frame: snapshots on arrival, then announces a new stage's title (and hint with assist), what changed in the
    # current one, and the win once.
    def self.stages_tick(d)
      mid = $game_map.map_id
      i = stage_index(d)
      s = i && d[:stages][i]
      if @st_map != mid
        @st_map = mid
        @st_solved = stages_solved?(d)
        stage_snapshot(i, s)
        return
      end
      if i != @st_stage
        stage_snapshot(i, s)
        announce_stage_entry(s) if s && !s[:quiet]
      elsif s
        announce_stage_changes(s)
      end
      if !@st_solved && stages_solved?(d)
        @st_solved = true
        PokeAccess.speak(label_of(d[:solved_msg]), false) if d[:solved_msg] && !d[:solved_quiet]
      end
    end

    # Remembers a stage's state, so only what changes after this is announced.
    def self.stage_snapshot(i, s)
      @st_stage = i
      @st_values = s ? stage_values(s) : nil
      @st_progress = s ? progress_value(s) : nil
      @st_track = s ? track_pos(s) : nil
    end

    # Says a stage's title as it opens, and its hint with assist.
    def self.announce_stage_entry(s)
      parts = [label_of(s[:title])]
      parts.push(label_of(s[:hint])) if assist? && s[:hint]
      t = parts.reject { |x| x.to_s.empty? }.join(". ")
      PokeAccess.speak(t, false) unless t.empty?
    end

    # Announces a value that changed, a counter that grew, or the tracked object after it moved.
    def self.announce_stage_changes(s)
      cur = stage_values(s)
      cur.each_index do |k|
        next if @st_values.nil? || @st_values[k] == cur[k]
        PokeAccess.speak(value_phrase(s[:values][k], cur[k]), false)
      end
      @st_values = cur
      pv = progress_value(s)
      if pv && @st_progress && pv > @st_progress && progress_audible?(s[:progress], pv) && s[:progress][:announce]
        PokeAccess.speak(progress_phrase(s[:progress], pv), false)
      end
      @st_progress = pv
      pos = track_pos(s)
      if pos && @st_track && pos != @st_track
        PokeAccess.speak(track_phrase(s[:track], pos), false)
      end
      @st_track = pos
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

    # The tracked object after a move: its distance to the goal with assist, else its offset from the player.
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

    # The info-key readout: the stage's title, its counter, its values and their sum, the tracked object,
    # and with assist the hint; the win when solved.
    def self.stages_read(d)
      if stages_solved?(d)
        PokeAccess.speak(label_of(d[:solved_msg]), true) if d[:solved_msg]
        return
      end
      s = stage_of(d)
      return unless s
      parts = [label_of(s[:title])]
      pv = progress_value(s)
      parts.push(progress_phrase(s[:progress], pv)) if pv && progress_audible?(s[:progress], pv)
      vals = stage_values(s)
      unless vals.empty?
        parts.push((0...vals.length).map { |k| value_phrase(s[:values][k], vals[k]) }.join(", "))
        parts.push(PokeAccess::I18n.t(:puzzle_sum, :n => vals.inject(0) { |a, b| a + b })) if s[:sum]
      end
      pos = track_pos(s)
      parts.push(track_phrase(s[:track], pos)) if pos
      parts.push(label_of(s[:hint])) if assist? && s[:hint]
      PokeAccess.speak(parts.reject { |x| x.to_s.empty? }.join(". "), true)
    end

    # The locator targets for the current stage: the puzzle's and the stage's spots, each value tile with its number,
    # the hidden spots still to find, the tracked object, and with assist its goal.
    def self.stages_targets(d)
      s = stage_of(d)
      out = spot_targets(d[:spots])
      return out unless s
      out.concat(spot_targets(s[:spots]))
      vals = stage_values(s)
      (s[:values] || []).each_with_index do |v, k|
        ev = ($game_map.events[v[:event]] rescue nil)
        next unless ev
        out.push(PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, value_phrase(v, vals[k]), :puzzle_value))
      end
      h = s[:hidden]
      out.concat(hidden_targets(h)) if h && (!h[:assist] || assist?)
      t = s[:track]
      tev = t && ($game_map.events[t[:event]] rescue nil)
      out.push(tev) if tev
      if assist? && t && t[:goal]
        g = t[:goal]
        out.push(PokeAccess::Locator::SurfaceTarget.new(g[0], (g[1] + g[3]) / 2, label_of(t[:goal_label]), :puzzle_goal))
      end
      out
    rescue StandardError
      []
    end

    # Named points as locator targets: a fixed tile, or where an event stands.
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
      return [] unless h
      h[:events].map do |id|
        ev = ($game_map.events[id] rescue nil)
        next nil unless ev
        list = PokeAccess.ivar(ev, :@list)
        live = list.is_a?(Array) && list.any? { |c| (c.code rescue 0) != 0 }
        live ? PokeAccess::Locator::SurfaceTarget.new(ev.x, ev.y, label_of(h[:label]), :puzzle_hidden) : nil
      end.compact
    end

    # Clears the stage runtime (with the rest of the per-map state).
    def self.reset_stages
      @st_map = nil; @st_stage = nil; @st_values = nil; @st_progress = nil; @st_track = nil; @st_solved = nil
    end
  end
end
