# Solar Light's jump spots and ski lifts, fired facing them, whose page moves the player by move routes under a branch on a
# switch or on the player's facing: "Jump1" to "Jump7" in Highpoint's gym and "Jump3" on Subhail Icecaps, sprite-less on a
# tile no one stands on, jump over it; Subhail gym's "Skilift1" and "Skilift2" carry the player up with Through on. The
# assisted route takes them as an action press; a jump lands as the engine lets, a ride where the player can stand.
module PokeAccess
  module SolarJumps
    NAME = /\A(Jump|Skilift)\d\z/
    # The only maps whose events bear those names: Highpoint's gym, Subhail Icecaps and Subhail's gym.
    MAPS = [134, 226, 260]
    WALKS = (1..13).to_a
    STEPS = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1] }
    THROUGH_ON = 37
    THROUGH_OFF = 38

    # The events of the map that are jump spots, by tile key; kept until the events change.
    def self.spots
      gen = (PokeAccess::World::Events.gen rescue 0)
      mid = ($game_map.map_id rescue 0)
      return @spots if @spots && @mid == mid && @gen == gen
      @mid = mid
      @gen = gen
      @spots = {}
      ($game_map.events rescue {}).each_value do |ev|
        @spots[PokeAccess::Routes.pkey(ev.x, ev.y)] = ev if ev.name.to_s =~ NAME
      end
      @spots
    end

    # True if (x,y) holds a jump spot.
    def self.at?(x, y); spots.key?(PokeAccess::Routes.pkey(x, y)); end

    # The moves a spot's page makes for a player facing face, as [[dx, dy, kind], ...] (kind :jump, or :ride for a step
    # taken with Through on), or nil when it makes none or walks the player where the engine decides.
    def self.jumps(ev, face)
      list = PokeAccess.ivar(ev, :@list)
      return nil unless list.is_a?(Array)
      out = []
      taken = {}
      skip = nil
      list.each do |c|
        ind = c.indent
        next if skip && ind > skip
        skip = nil
        case c.code
        when 111
          ok = branch?(c.parameters, face)
          return nil if ok.nil?
          taken[ind] = ok
          skip = ind unless ok
        when 411
          skip = ind if taken[ind]
        when 209
          next unless c.parameters[0] == -1
          through = false
          c.parameters[1].list.each do |m|
            through = true if m.code == THROUGH_ON
            through = false if m.code == THROUGH_OFF
            if m.code == 14
              out << [m.parameters[0], m.parameters[1], through ? :ride : :jump]
            elsif WALKS.include?(m.code)
              return nil unless through && STEPS[m.code]
              out << STEPS[m.code].dup.push(:ride)
            end
          end
        end
      end
      out.empty? ? nil : out
    end

    # Whether a conditional branch holds: on a switch or the player's facing; nil for any other test.
    def self.branch?(p, face)
      case p[0]
      when 0 then $game_switches[p[1]] == (p[2] == 0)
      when 6 then p[1] == -1 ? p[2] == face : nil
      end
    end

    # The assisted step the action button makes at (x,y) facing dir ([dx, dy, d]) at the spot in front, or nil.
    def self.step(x, y, dir, lvl)
      ev = spots[PokeAccess::Routes.pkey(x + dir[0], y + dir[1])]
      hops = ev && jumps(ev, dir[2])
      return nil if hops.nil?
      probe = PokeAccess::World::Probe
      lx = x
      ly = y
      hops.each do |dx, dy, kind|
        return nil unless kind == :ride || probe.lands?(lx, ly, dir[2], lx + dx, ly + dy)
        lx += dx
        ly += dy
      end
      return nil if hops.any? { |h| h[2] == :ride } && probe.landing(lx, ly).nil?
      PokeAccess::Routes::Moves::Step.new(lx, ly, lvl, 1, { :kind => :act, :face => dir[2], :x => x, :y => y })
    end
  end
end

PokeAccess::Game.define("solarlight") do
  jumps = PokeAccess::SolarJumps
  assisted_step(:maps => jumps::MAPS, :front_tiles => lambda { |x, y| jumps.at?(x, y) }) do |x, y, dir, lvl|
    jumps.step(x, y, dir, lvl)
  end
end
