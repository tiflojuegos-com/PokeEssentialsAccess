module PokeAccess
  module World
    module Mechanics
      # Hidden state (:state): watched flags, counts, phases each live while its :when holds (the first live one is
      # current), an info line, and a :solved test.
      #   :watch  [{:switch | :var => id | :self => [event, letter] | :event => id, :label, :on, :off, :words, :number, :say}]
      #           a variable is on from 1, or says its value with :words, :number or :say; :self is a self switch of an
      #           event of this map, :event whether that event is drawn
      #   :counts [{:var, :from | :flags, :of, :label, :announce, :reset, :hide_zero, :assist}]
      #   :phases [{:when => ->, :title, :quiet, :entry_title, :hint,
      #             :progress => as a count,
      #             :values => [{:var, :label, :event, :words}], :sum, :spots, :hidden => {:events, :label, :assist},
      #             :track => {:event, :label, :goal => [x0, y0, x1, y1], :goal_label}}]
      #   :info ->, :active ->, :solved ->, :solved_msg, :solved_quiet (the game says the win itself), :spots, :hint,
      #   :arrival_hint
      # Queues [:arrival_hint] and [:entered, phase], the phase open then, on the first frame; [:watch, i, value] as a
      # watched flag changes; [:progress, count, n] as a count grows and [:reset, count, n] as it falls; [:phase, phase] as
      # a phase opens (not a :quiet one); within a phase [:value, value, n] as a number changes, its counter as a count,
      # and [:track, track, [x, y]] as the tracked event moves; and [:solved, message] once, unless quiet.
      module State
        # Takes the state on arrival, so walking in says nothing but its arrival hint and, to the assist, the open phase's.
        def self.enter(inst)
          spec = inst.spec
          st = inst.data = { :flags => flags(spec), :counts => counts(spec), :solved => Mechanics.truth(spec[:solved]),
                             :arrived => !spec[:arrival_hint].nil?, :entered => true }
          snapshot(st, phase_index(spec), current_phase(spec))
        end

        # One frame: the arrival hint, the flags that changed, the counts that moved, the phase, then the win.
        def self.update(inst, out)
          spec = inst.spec
          st = inst.data
          out.push([:arrival_hint]) if st[:arrived] && !st[:solved]
          st[:arrived] = false
          cur = flags(spec)
          cur.each_index { |i| out.push([:watch, i, cur[i]]) if cur[i] != st[:flags][i] && !spec[:watch][i][:quiet] }
          st[:flags] = cur
          now = counts(spec)
          now.each_index { |i| moved(spec[:counts][i], st[:counts][i], now[i], out) }
          st[:counts] = now
          phases(spec, st, out) if spec[:phases]
          return if st[:solved] || !Mechanics.truth(spec[:solved])
          st[:solved] = true
          out.push([:solved, spec[:solved_msg]]) if spec[:solved_msg] && !spec[:solved_quiet]
        end

        # What a count going from was to now queues: its line as it grows, if it says so, and its fall.
        def self.moved(c, was, now, out)
          return unless was
          out.push([:progress, c, now]) if now > was && c[:announce]
          out.push([:reset, c, now]) if now < was && c[:reset]
        end

        # The phase open on arrival, then a phase that opened or what changed in the current one.
        def self.phases(spec, st, out)
          i = phase_index(spec)
          s = i && spec[:phases][i]
          out.push([:entered, s]) if s && st[:entered] && i == st[:phase] && !st[:solved]
          st[:entered] = false
          if i != st[:phase]
            snapshot(st, i, s)
            out.push([:phase, s]) if s && !s[:quiet]
          elsif s
            changes(s, st, out)
          end
        end

        # The numbers that changed, the counter that moved and the tracked event that moved.
        def self.changes(s, st, out)
          cur = values(s)
          cur.each_index { |k| out.push([:value, s[:values][k], cur[k]]) if st[:values] && st[:values][k] != cur[k] }
          st[:values] = cur
          pv = progress(s)
          moved(s[:progress], st[:progress], pv, out) if pv
          st[:progress] = pv
          pos = track(s)
          out.push([:track, s[:track], pos]) if pos && st[:track] && pos != st[:track]
          st[:track] = pos
        end

        # Remembers a phase's state, so only what changes after is queued.
        def self.snapshot(st, i, s)
          st[:phase] = i
          st[:values] = s ? values(s) : nil
          st[:progress] = s ? progress(s) : nil
          st[:track] = s ? track(s) : nil
        end

        # What every watched flag holds.
        def self.flags(spec)
          (spec[:watch] || []).map { |w| value(w) }
        end

        # What a watched flag holds: a variable's number where it is said by its value, else on or off.
        def self.value(w)
          return flag(w) unless w[:var] && (w[:words] || w[:number] || w[:say])
          ($game_variables[w[:var]] || 0).to_i
        rescue StandardError => e
          PokeAccess.swallowed(e)
          0
        end

        # One watched flag on or off: a switch, a variable from 1 or :from, a self switch (of this map, or of the one it names), or an
        # event being drawn.
        def self.flag(w)
          if w[:switch]
            $game_switches[w[:switch]] ? true : false
          elsif w[:var]
            ($game_variables[w[:var]] || 0) >= (w[:from] || 1)
          elsif w[:self]
            $game_self_switches[[w[:self][2] || $game_map.map_id, w[:self][0], w[:self][1]]] ? true : false
          elsif w[:event]
            drawn?($game_map.events[w[:event]])
          else
            false
          end
        rescue StandardError => e
          PokeAccess.swallowed(e)
          false
        end

        # True when an event is drawn, with a character or a tile.
        def self.drawn?(ev)
          return false unless ev
          !ev.character_name.to_s.empty? || (ev.tile_id rescue 0).to_i > 0
        end

        # What every count stands at.
        def self.counts(spec)
          (spec[:counts] || []).map { |c| count_of(c) }
        end

        # What a count stands at: what its :value says, a variable less :from, or how many of its flags are on.
        def self.count_of(c)
          return c[:value].call.to_i if c[:value]
          return ($game_variables[c[:var]] || 0).to_i - c[:from].to_i if c[:var]
          (c[:flags] || []).select { |w| flag(w) }.length
        end

        # The index of the current phase (the first live one), or nil.
        def self.phase_index(spec)
          (spec[:phases] || []).index { |s| Mechanics.truth(s[:when]) }
        end

        # The current phase, or nil.
        def self.current_phase(spec)
          i = phase_index(spec)
          i && spec[:phases][i]
        end

        # The numbers a phase's tiles show, in order.
        def self.values(s)
          (s[:values] || []).map { |v| ($game_variables[v[:var]] || 0).to_i }
        end

        # A phase's counter, or nil when it has none.
        def self.progress(s)
          p = s[:progress]
          p ? count_of(p) : nil
        end

        # Where a phase's tracked event stands, as [x, y], or nil.
        def self.track(s)
          t = s[:track]
          ev = t && ($game_map.events[t[:event]] rescue nil)
          ev ? [ev.x, ev.y] : nil
        end
      end
    end
  end
end

PokeAccess::World::Mechanics.register_type(:state, PokeAccess::World::Mechanics::State)
