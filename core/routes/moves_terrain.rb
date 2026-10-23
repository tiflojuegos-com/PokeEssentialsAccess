module PokeAccess
  module Routes
    # Moves over the terrain: a registered departure or arrival (games and plugins register theirs, since tag numbers
    # differ between games), a ledge hop, an ice run, falling water, the map's border, and the moves of a planned surf.
    module Moves
      # How far a forced movement is followed before it is taken for a loop the game would never leave.
      ARRIVAL_CAP = 200

      # The move a registered rule makes leaving (x,y) toward dir: [x, y], false when it fails, nil when no rule owns
      # the tile.
      def self.departure(x, y, dir)
        @leave_rules.each do |rule|
          next unless owns?(rule.owner, x, y)
          r = (rule.body.call(x, y, dir) rescue nil)
          return r unless r.nil?
        end
        nil
      end

      # Where a step that arrives on (x,y) moving in direction d ends, as [x, y] ([x, y, presses] across ground ridden
      # straight on), or nil when it goes nowhere: the first rule that owns the tile decides, else the tile itself.
      def self.arrive(x, y, d)
        r = waterfall_descent(x, y, d)
        return (r ? r : nil) unless r.nil?
        @arrival_rules.each do |rule|
          next unless owns?(rule.owner, x, y)
          r = (rule.body.call(x, y, d) rescue nil)
          next if r.nil?
          return r ? r : nil
        end
        [x, y]
      end

      # Falling water: a surfer who moves down onto the crest of a waterfall is carried down it to the first tile below
      # that is neither the crest nor the fall (pbDescendWaterfall in both eras). nil anywhere else.
      def self.waterfall_descent(x, y, d)
        return nil unless d == 2 && ($PokemonGlobal.surfing rescue false)
        return nil unless PokeAccess::World::Terrain.kind(x, y) == :waterfall_crest
        fall_end(x, y, 1) || false
      end

      # Climbing a waterfall with Waterfall, from the water below it facing up: to the first tile above that is
      # neither the fall nor its crest. [x, y], or nil when (x,y) is no waterfall.
      def self.waterfall_ascent(x, y)
        falling_water?(x, y) ? fall_end(x, y, -1) : nil
      end

      # The first tile from (x,y), going dy rows at a time (down 1, up -1), that is neither a waterfall nor its crest,
      # or nil past the map's edge or a fall too long to be one.
      def self.fall_end(x, y, dy)
        guard = 0
        while falling_water?(x, y)
          guard += 1
          return nil if guard > ARRIVAL_CAP
          y += dy
        end
        ($game_map.valid?(x, y) rescue false) ? [x, y] : nil
      end

      # True if (x,y) is a waterfall or its crest.
      def self.falling_water?(x, y)
        PokeAccess::World::Terrain.falling?(x, y)
      end

      # A ledge hop from (cx,cy) toward d as the engine plays it: [x, y] two tiles on, false when the jump cannot land
      # there (an obstacle included); nil when it is no hop (no ledge that way, a closed step), which makes it a bump.
      def self.ledge_jump(cx, cy, dx, dy, d)
        nx = cx + dx; ny = cy + dy
        probe = PokeAccess::World::Probe
        return nil unless PokeAccess::World::Terrain.ledge?(nx, ny) && probe.step?(cx, cy, d)
        lx = cx + 2 * dx; ly = cy + 2 * dy
        return false if obstacle_at?(lx, ly)
        probe.lands?(cx, cy, d, lx, ly) ? [lx, ly] : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        nil
      end

      # Where an ice slide from (x,y) stops: off the ice, before a blocked step or after ARRIVAL_CAP moves; a touch
      # event slid over decides it (slid_over), and a ledge ahead is hopped, or stops it when the hop cannot land.
      def self.ice_slide(x, y, dx, dy, d)
        guard = 0
        while PokeAccess::World::Terrain.ice?(x, y) && guard < ARRIVAL_CAP
          guard += 1
          break unless PokeAccess::World::Probe.step?(x, y, d) && !obstacle_at?(x + dx, y + dy)
          e = Effects.touch_at(x, y, d, true)
          return slid_over(x, y, e) if e && e[0] != :ramp && !IN_PLACE.include?(e[0])
          hop = ledge_jump(x, y, dx, dy, d)
          return [x, y] if hop == false
          if hop
            x, y = hop
          else
            x += dx; y += dy
          end
        end
        [x, y]
      end

      # Where a slide that passes over a touch event at (x,y) ends up, or nil or false when it cannot be taken.
      def self.slid_over(x, y, e)
        case e[0]
        when :warp then PokeAccess::World::Probe.landing(e[1], e[2])
        when :carry then carry_landing(x, y, e)
        end
      end

      # True if a tile is on the outer border of the map (where connection/exit tiles live).
      def self.border_tile?(x, y)
        return false unless $game_map
        x <= 0 || y <= 0 || x >= $game_map.width - 1 || y >= $game_map.height - 1
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # Surfable water a planned surf may cross: the engine's surfable tags, less falling water, which only Waterfall
      # climbs and no route can ask for.
      def self.surf_water?(x, y)
        c = PokeAccess::World::Terrain.cell(x, y)
        (c & PokeAccess::World::Terrain::SURF) != 0 && (c & PokeAccess::World::Terrain::FALLING) == 0
      end

      # A surfing move walking cannot make, as a Step or nil: pushing off a shore onto water or water to water (then its
      # current and touch event; falls too), or coming ashore onto an open tile with nothing solid on it.
      def self.water_step(cx, cy, dir, lvl, wet)
        nx = cx + dir[0]; ny = cy + dir[1]; d = dir[2]
        return nil unless ($game_map.valid?(nx, ny) rescue false)
        return falls_step(nx, ny, d, lvl) if wet && falling_water?(nx, ny)
        if surf_water?(nx, ny)
          probe = PokeAccess::World::Probe
          open = if wet then probe.afloat { probe.step?(cx, cy, d) }
                 else ($game_map.passable?(cx, cy, d) rescue false) && probe.afloat { probe.lands?(cx, cy, d, nx, ny) }
                 end
          return nil unless open
          return probe.afloat { (a = arrive(nx, ny, d)) && landed(a, lvl, d, :walk, 0) }
        end
        return nil unless wet
        return nil unless ($game_map.passable?(nx, ny, 10 - d) rescue false)
        return nil if solid_event_at?(nx, ny) || Effects.exit_step?(nx, ny, d)
        Step.new(nx, ny, lvl)
      end

      # Falling water met afloat: carried down from its crest (from any of its tiles in a game whose falls have none,
      # crestless_falls!), and climbed with Waterfall when the party may be able to, each to the water past it.
      def self.falls_step(x, y, d, lvl)
        l = if d == 2
              k = PokeAccess::World::Terrain.kind(x, y)
              k == :waterfall_crest || (@crestless && k == :waterfall) ? fall_end(x, y, 1) : nil
            elsif d == 8 && PokeAccess::FieldMoves.can?(:WATERFALL) != false
              waterfall_ascent(x, y)
            end
        (l && surf_water?(l[0], l[1])) ? Step.new(l[0], l[1], lvl) : nil
      end

      # Declares the game's waterfalls have no crest tile (no map carries one): a surfer moving down into a fall is
      # carried past it from any of its tiles (Insurgence, onStepTakenFieldMovement).
      def self.crestless_falls!; @crestless = true; end

      # True if an event the player cannot walk through stands on (x,y).
      def self.solid_event_at?(x, y)
        PokeAccess::World::Events.anchored(x, y).any? { |r| !r.through && !r.char.to_s.empty? }
      end

      # True if a field-move obstacle stands on (x,y) as it is, even while the assisted search sets it aside, or a
      # boulder where a push search has it (with_rocks): no jump lands on it and no slide crosses it (the engine stops
      # them), only a step up to it can carry its gate.
      def self.obstacle_at?(x, y)
        return true if @rocks && @rocks.call(x, y)
        !Effects.gate_at(x, y).nil? && solid_event_at?(x, y)
      end

      # Runs the block with rocks, a call of (x, y) true where a push search's state has a boulder, standing for
      # obstacle_at? while the boulders are lent through to the engine.
      def self.with_rocks(rocks)
        was = @rocks
        @rocks = rocks
        yield
      ensure
        @rocks = was
      end
    end
  end
end
