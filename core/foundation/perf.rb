module PokeAccess
  # A rolling profiler for the per-frame hooks: measure() accumulates sum, max and count per label, and the
  # diagnostic prints avg/max ms and resets the window.
  module Perf
    @stats = {}

    # Times the block under a label, accumulating rolling sum, max and count.
    def self.measure(label)
      t0 = PokeAccess.clock
      yield
    ensure
      s = (@stats[label] ||= [0.0, 0.0, 0])
      dt = (PokeAccess.clock - t0) * 1000.0
      s[0] += dt
      s[1] = dt if dt > s[1]
      s[2] += 1
    end

    # A one-line report of every measured label as "label avg=Xms max=Yms n=N".
    def self.report
      return "(sin datos)" if @stats.empty?
      @stats.map do |k, s|
        n = (s[2] > 0) ? s[2] : 1
        sprintf("%s avg=%.2fms max=%.2fms n=%d", k.to_s, s[0] / n, s[1], s[2])
      end.join(" | ")
    end

    # Clears the accumulated stats so a fresh window can be measured.
    def self.reset
      @stats = {}
    end
  end
end
