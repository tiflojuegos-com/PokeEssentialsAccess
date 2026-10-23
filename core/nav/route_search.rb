module PokeAccess
  # Pathfinder, what the searches share: the algorithm setting and its weights, the arrival test and the binary heap.
  module Pathfinder
    # The search algorithms the route key can choose: the regions router (Routes::Regions#route, A* while it cannot
    # tell), the engine's frontiers (Routes::Search.run), JPS within it and HPA* (route_grid).
    ALGORITHMS = [:regions, :astar, :weighted, :greedy, :dijkstra, :bfs, :dfs, :jps, :hpa]

    # The search algorithm from config (default :regions; an unknown value falls back to it).
    def self.path_algorithm
      a = (PokeAccess::Config.path_algorithm rescue nil)
      a = a.to_sym if a.respond_to?(:to_sym) && !a.to_s.empty?
      ALGORITHMS.include?(a) ? a : :regions
    end

    # The weighted A* heuristic's weight (Config.astar_weight) in quarters: 1.25, 1.5, 2 and 3 times the distance.
    WEIGHTS = { :w125 => 5, :w150 => 6, :w200 => 8, :w300 => 12 }

    # The weights the menu steps through, lightest first.
    WEIGHT_CHOICES = [:w125, :w150, :w200, :w300]

    # The [g-weight, h-weight] of a heap algorithm's priority f = gw*g + hw*h (unused for bfs and dfs), integers so the
    # ordering stays exact: weighted's heuristic is its chosen quarters over 4 (1.5x unless set otherwise).
    def self.algo_weights(algo)
      case algo
      when :weighted then [4, WEIGHTS[(PokeAccess::Config.astar_weight rescue nil)] || 6]
      when :greedy   then [0, 2]
      when :dijkstra then [2, 0]
      else [2, 2]
      end
    end

    # Orders two frontier nodes [f, turns, ...] by priority f, then by fewer turns.
    def self.heap_less(a, b); a[0] < b[0] || (a[0] == b[0] && a[1] < b[1]); end

    # Pushes a node onto the binary min-heap and sifts it up.
    def self.heap_push(heap, item)
      heap.push(item); i = heap.size - 1
      while i > 0
        p = (i - 1) / 2
        break if heap_less(heap[p], heap[i])
        heap[p], heap[i] = heap[i], heap[p]; i = p
      end
    end

    # Pops the smallest node off the binary min-heap and sifts the hole down.
    def self.heap_pop(heap)
      top = heap[0]; last = heap.pop
      unless heap.empty?
        heap[0] = last; i = 0; n = heap.size
        loop do
          l = 2 * i + 1; r = 2 * i + 2; s = i
          s = l if l < n && heap_less(heap[l], heap[s])
          s = r if r < n && heap_less(heap[r], heap[s])
          break if s == i
          heap[i], heap[s] = heap[s], heap[i]; i = s
        end
      end
      top
    end
  end
end
