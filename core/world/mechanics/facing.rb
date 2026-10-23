module PokeAccess
  module World
    module Mechanics
      # Turning statues (:facing): events whose graphic matches :match, each turned by the player; :targets maps a
      # statue's tile to the facing the game checks, :label names them. Queues [:facing, [x, y], dir] as one turns and
      # [:solved, message] once the declared win holds (its message, else the generic one; none with :quiet).
      module Facing
        # Takes every statue's facing on arrival, and whether the win already holds.
        def self.enter(inst)
          inst.data = { :last => facings(inst), :solved => Mechanics.truth(inst.spec[:solved]) }
        end

        # One frame: each statue that turned since the last, then the win.
        def self.update(inst, out)
          cur = facings(inst)
          last = inst.data[:last]
          cur.each { |pos, dir| out.push([:facing, pos, dir]) if last[pos] && last[pos] != dir }
          inst.data[:last] = cur
          spec = inst.spec
          return if inst.data[:solved] || !Mechanics.truth(spec[:solved])
          inst.data[:solved] = true
          out.push([:solved, spec[:solved_msg] || :puzzle_solved]) unless spec[:solved_quiet]
        end

        # Each statue's tile and facing.
        def self.facings(inst)
          out = {}
          inst.pieces.each { |p| out[[p.ev.x, p.ev.y]] = (p.ev.direction rescue 2) if p.role == :statue }
          out
        end
      end
    end
  end
end

PokeAccess::World::Mechanics.register_type(:facing, PokeAccess::World::Mechanics::Facing)
