module PokeAccess
  module World
    module Mechanics
      # Hidden state (:state): watched switches and variables, phases each live while its :when holds (the first live
      # one is current), an info line, and a :solved test.
      #   :watch  [{:switch | :var => id, :label, :on, :off}]   a variable is on from 1
      #   :phases [{:when => ->, :title, :quiet, :hint,
      #             :progress => {:var, :of, :label, :assist, :announce, :hide_zero},
      #             :values => [{:var, :label, :event}], :sum, :spots, :hidden => {:events, :label, :assist},
      #             :track => {:event, :label, :goal => [x0, y0, x1, y1], :goal_label}}]
      #   :info ->, :active ->, :solved ->, :solved_msg, :solved_quiet (the game says the win itself), :spots, :hint,
      #   :arrival_hint
      # Queues [:arrival_hint] on the first frame; [:watch, i, on] as a watched flag flips; [:phase, phase] as a phase
      # opens (not a :quiet one); within a phase [:value, value, n] as a number changes, [:progress, progress, n] as an
      # announced counter grows and [:track, track, [x, y]] as the tracked event moves; and [:solved, message] once,
      # unless quiet.
      module State
        # Takes the state on arrival, so walking in says nothing but its arrival hint.
        def self.enter(inst)
          spec = inst.spec
          st = inst.data = { :flags => flags(spec), :solved => Mechanics.truth(spec[:solved]),
                             :arrived => !spec[:arrival_hint].nil? }
          snapshot(st, phase_index(spec), current_phase(spec))
        end

        # One frame: the arrival hint, the flags that flipped, the phase, then the win.
        def self.update(inst, out)
          spec = inst.spec
          st = inst.data
          out.push([:arrival_hint]) if st[:arrived]
          st[:arrived] = false
          cur = flags(spec)
          cur.each_index { |i| out.push([:watch, i, cur[i]]) if cur[i] != st[:flags][i] }
          st[:flags] = cur
          phases(spec, st, out) if spec[:phases]
          return if st[:solved] || !Mechanics.truth(spec[:solved])
          st[:solved] = true
          out.push([:solved, spec[:solved_msg]]) if spec[:solved_msg] && !spec[:solved_quiet]
        end

        # A phase that opened, or what changed in the current one.
        def self.phases(spec, st, out)
          i = phase_index(spec)
          s = i && spec[:phases][i]
          if i != st[:phase]
            snapshot(st, i, s)
            out.push([:phase, s]) if s && !s[:quiet]
          elsif s
            changes(s, st, out)
          end
        end

        # The numbers that changed, the counter that grew and the tracked event that moved.
        def self.changes(s, st, out)
          cur = values(s)
          cur.each_index { |k| out.push([:value, s[:values][k], cur[k]]) if st[:values] && st[:values][k] != cur[k] }
          st[:values] = cur
          pv = progress(s)
          grew = pv && st[:progress] && pv > st[:progress]
          out.push([:progress, s[:progress], pv]) if grew && s[:progress][:announce]
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

        # The value of every watched flag: a switch, or a variable from 1.
        def self.flags(spec)
          (spec[:watch] || []).map { |w| flag(w) }
        end

        # One watched flag's value.
        def self.flag(w)
          if w[:switch]
            $game_switches[w[:switch]] ? true : false
          elsif w[:var]
            ($game_variables[w[:var]] || 0) >= 1
          else
            false
          end
        rescue StandardError => e
          PokeAccess.swallowed(e)
          false
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
          p ? ($game_variables[p[:var]] || 0).to_i : nil
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
