module PokeAccess
  module Routes
    # Jump point search over the moves (Search.run with :jps, the shortest style, on foot): scans go straight along
    # plain steps (Moves.fast), horizontal first, to jump points: a goal, a special move or move back (a ledge hop), a
    # vertical scan's forced turn or a tile a horizontal one can turn from toward one; fewest presses, maybe not turns.
    module Jumps
      # The scan steps a search may take, as a multiple of its budget (astar_max), and at the least.
      SCANS = 8
      SCANS_MIN = 20000
      # Every way, as indices of DIRS (up, down, left, right).
      ALL = [0, 1, 2, 3]
      # The way back from each of DIRS.
      BACK = [1, 0, 3, 2]

      # The scan steps one search may take, as [taken, budget, limits]: the limits' deadline is read every 64 steps, as
      # a scan over open ground can run long between two jump points.
      def self.budget(limits = nil)
        [0, [(PokeAccess::Config.astar_max rescue 2500).to_i * SCANS, SCANS_MIN].max, limits]
      end

      # The ways (indices of DIRS) a jump point at (x,y) is expanded along, arrived at along from (4: the start or a
      # special move's landing): every one, or straight on and the turns its arrival allows, and back when that move is
      # special.
      def self.ways(x, y, from, mode)
        return ALL if from == 4
        if from >= 2
          out = [from, 0, 1]
        else
          d = DIRS[from]
          px = x - d[0]; py = y - d[1]
          out = [from]
          out.push(2) if turn?(px, py, x, y, 2, from, mode)
          out.push(3) if turn?(px, py, x, y, 3, from, mode)
        end
        out.push(BACK[from]) if back?(x, y, from, mode)
        out
      end

      # True when the move from (x,y) back against DIRS[i] is more than a plain step.
      def self.back?(x, y, i, mode)
        f = Moves.fast(x, y, DIRS[BACK[i]], mode)
        !f.nil? && f != true
      end

      # True when a vertical scan along v from (px,py) to (x,y) has to turn toward h at (x,y): that move is more than a
      # plain step, or a plain one the way round by (px,py), horizontal first, cannot make.
      def self.turn?(px, py, x, y, h, v, mode)
        f = Moves.fast(x, y, DIRS[h], mode)
        return false if f.nil?
        return true unless f == true
        dh = DIRS[h]
        Moves.fast(px, py, dh, mode) != true || Moves.fast(px + dh[0], py + dh[1], DIRS[v], mode) != true
      end

      # The first jump point along DIRS[i] from (x,y), whose first move is a plain step: [x, y, presses], nil when the
      # way ends first, :over once the scans have taken their budget or the time ran out (scan: see budget).
      def self.jump(x, y, i, mode, goal, scan)
        dir = DIRS[i]
        n = 0
        loop do
          return :over if (scan[0] += 1) > scan[1] || ((scan[0] & 63) == 0 && scan[2] && scan[2].time_spent?)
          px = x; py = y
          x += dir[0]; y += dir[1]; n += 1
          return [x, y, n] if goal.hit?(x, y) || back?(x, y, i, mode)
          if i >= 2
            r = turns?(x, y, mode, goal, scan)
            return r if r == :over
            return [x, y, n] if r
          elsif turn?(px, py, x, y, 2, i, mode) || turn?(px, py, x, y, 3, i, mode)
            return [x, y, n]
          end
          f = Moves.fast(x, y, dir, mode)
          return nil if f.nil?
          return [x, y, n] unless f == true
        end
      end

      # True when a horizontal scan stops at (x,y): a move up or down from it is more than a plain step, or a vertical
      # scan from it meets a jump point; :over past the budget.
      def self.turns?(x, y, mode, goal, scan)
        [0, 1].each do |v|
          f = Moves.fast(x, y, DIRS[v], mode)
          next if f.nil?
          return true unless f == true
          r = jump(x, y, v, mode, goal, scan)
          return r if r == :over
          return true if r
        end
        false
      end
    end
  end
end
