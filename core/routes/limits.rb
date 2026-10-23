module PokeAccess
  module Routes
    # One route operation's budget, from the route limit setting: nodes per search (:effort, astar_max), one deadline
    # for the whole operation (:time, route_budget_ms) or none (:none); it counts the searches it stopped short.
    class Limits
      # How often, in states, a search under a deadline reads the clock (a power of two: it is used as a mask): sixteen
      # states of the slowest engine take about 5 ms.
      CHECK = 16

      attr_reader :mode, :cuts

      # A budget of mode with nodes per search and ms for the operation, its deadline running from now.
      def initialize(mode, nodes, ms)
        @mode = [:effort, :time, :none].include?(mode) ? mode : :effort
        @nodes = nodes
        @ms = ms
        @deadline = @mode == :time ? (PokeAccess.clock rescue 0.0) + ms / 1000.0 : nil
        @cuts = 0
      end

      # The budget the settings ask for, its deadline running from now.
      def self.from_config
        c = PokeAccess::Config
        new((c.route_limit rescue :effort), (c.astar_max rescue 2500).to_i, (c.route_budget_ms rescue 12).to_i)
      end

      # True once a search that has taken iter states has to stop, the stop counted.
      def spent?(iter)
        stop = case @mode
               when :time then (iter & (CHECK - 1)) == 0 && (PokeAccess.clock rescue 0.0) > @deadline
               when :none then false
               else iter > @nodes
               end
        @cuts += 1 if stop
        stop
      end

      # Runs the block with the states a search may take by effort lowered by n the question spent before it (HPA*'s
      # graph and searches), half of them left at the least; the other modes as they are.
      def less(n)
        was = @nodes
        @nodes = [was - n.to_i, was - was / 2].max if @mode == :effort
        yield
      ensure
        @nodes = was
      end

      # Counts a search stopped short by a cap of its own or a target beyond reach; nil, for the search to answer with.
      def cut!
        @cuts += 1
        nil
      end

      # True with no limit at all.
      def none?; @mode == :none; end

      # True once the deadline has passed; never without one.
      def time_spent?; @deadline ? (PokeAccess.clock rescue 0.0) > @deadline : false; end

      # What a search's answer under this budget depends on: the mode and its size. A stopped one also depends on the
      # clock under a deadline, and by effort on how far the regions and the flood had gone, so the Planner keeps
      # neither.
      def key; [@mode, @mode == :time ? @ms : (@mode == :effort ? @nodes : nil)]; end
    end
  end
end
