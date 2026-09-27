module PokeAccess
  # Marin's side stairs (v21 port and v17 "Enhanced Staircases"): a "Slope" event with a "Slope: AxB" comment
  # walks the player A tiles sideways and B rows up or down to its partner; for a route, one run of |A| presses.
  module MarinSideStairs
    # The comment giving where the partner event is, as the plugin reads it.
    SLOPE = /Slope: (-?\d+)x(-?\d+)/

    # The run a Slope event starts, [:run, direction, presses, dx, dy], or nil for any other event.
    def self.run_of(ev)
      return nil unless (ev.name rescue nil) == "Slope"
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      c = list.find { |cmd| (cmd.code rescue 0) == 108 && (cmd.parameters[0] rescue "").to_s =~ SLOPE }
      return nil if c.nil?
      m = c.parameters[0].to_s.match(SLOPE)
      a = m[1].to_i; b = m[2].to_i
      return nil if a == 0
      [:run, a > 0 ? 6 : 4, a.abs, a, b]
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Pathfinder.touch_source { |ev| PokeAccess::MarinSideStairs.run_of(ev) }
