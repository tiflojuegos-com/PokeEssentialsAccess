module PokeAccess
  module World
    module Mechanics
      # A floor grid (:grid): cells the game lights, a letter to form while it is active, the cell under the player.
      # Declared with :cols, :rows, :cells ([[x, y], ...] in reading order), :lit (->(i)), :active (->), :target
      # (-> {:name, :pattern} or nil) and :solved (->). Queues [:target, target, advanced] as a new letter comes
      # (advanced when it follows another, not on arrival), [:tone, i] as the player steps onto a cell, [:cell, i, lit]
      # once the game's toggle settles (none for the cells a new letter resets), and [:solved, :puzzle_solved] once; a
      # won grid says no cell, as the game resets them after the win.
      module Grid
        # Frames to wait, with the player standing on a cell and no event running, before reading it: a cell's touch
        # event runs only once the step onto it has ended.
        SETTLE = 2

        # Frames a cell just left is watched for the toggle its touch event makes as the player walks on.
        CROSSED = 20

        # Takes the state on arrival: a grid already solved stays quiet.
        def self.enter(inst)
          inst.data = { :cell => nil, :settle => 0, :states => nil, :letter => nil, :arrived => true,
                        :solved => Mechanics.truth(inst.spec[:solved]), :left => nil, :left_ttl => 0 }
        end

        # One frame: the letter or the win, then, while active and not won, the cell under the player.
        def self.update(inst, out)
          spec = inst.spec
          st = inst.data
          before = out.length
          won = progress(spec, st, out)
          st[:arrived] = false
          return if won || !Mechanics.truth(spec[:active])
          cur = states(spec)
          cell(spec, st, cur, out, out.length > before)
          st[:states] = cur
        end

        # The win once, else a letter that changed; true while the grid stands won.
        def self.progress(spec, st, out)
          if Mechanics.truth(spec[:solved])
            out.push([:solved, :puzzle_solved]) unless st[:solved]
            st[:solved] = true
            st[:letter] = nil
            return true
          end
          tgt = target(spec)
          letter = tgt && tgt[:name]
          out.push([:target, tgt, !(st[:letter].nil? || st[:arrived])]) if letter && letter != st[:letter]
          st[:letter] = letter
          false
        end

        # The cell under the player: its tone on arrival, its state once settled or as it changes underfoot; and the
        # cell just left, if its toggle comes after the player walked on. reset: the game reset the cells this frame.
        def self.cell(spec, st, cur, out, reset)
          i = spec[:cells].index([$game_player.x, $game_player.y])
          if i != st[:cell]
            watch_left(st, st[:cell])
            st[:cell] = i
            st[:settle] = i ? SETTLE : 0
            out.push([:tone, i]) if i
          elsif i && st[:settle] > 0
            st[:settle] -= 1 unless busy?
            out.push([:cell, i, cur[i]]) if st[:settle] == 0
          elsif i && !reset && st[:states] && st[:states][i] != cur[i]
            out.push([:cell, i, cur[i]])
          end
          crossed(st, cur, out, reset)
        end

        # Starts watching the cell the player leaves, unless its state was already said.
        def self.watch_left(st, j)
          st[:left] = j && st[:settle] > 0 ? j : nil
          st[:left_ttl] = st[:left] ? CROSSED : 0
        end

        # The cell just left, said once if the game toggles it within CROSSED frames.
        def self.crossed(st, cur, out, reset)
          j = st[:left]
          return unless j
          st[:left_ttl] -= 1
          if !reset && st[:states] && st[:states][j] != cur[j]
            out.push([:cell, j, cur[j]])
            st[:left] = nil
          elsif st[:left_ttl] <= 0 || reset
            st[:left] = nil
          end
        end

        # True while the step is still under way or an event runs: the cell's toggle has not been made yet.
        def self.busy?
          ($game_player.moving? rescue false) || ($game_system.map_interpreter.running? rescue false)
        end

        # Every cell's lit state, in reading order.
        def self.states(spec)
          (0...spec[:cells].length).map { |i| Mechanics.truth(spec[:lit], i) }
        end

        # The letter to form now, or nil.
        def self.target(spec)
          spec[:target] ? (spec[:target].call rescue nil) : nil
        end
      end
    end
  end
end

PokeAccess::World::Mechanics.register_type(:grid, PokeAccess::World::Mechanics::Grid)
