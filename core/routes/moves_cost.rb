module PokeAccess
  module Routes
    # What a move costs beyond its presses: the tiles a game's tile_cost rules price, and with avoid_grass the grass
    # where wild Pokemon appear. Each tile's cost is kept with the classes (forget_classes) while what it reads stands.
    module Moves
      # The presses of more a tile of grass with wild Pokemon costs with avoid_grass on.
      GRASS_COST = 3

      @crows = []
      @cost_key = nil
      @grass_on = false

      # True when a move here may cost more than its presses: a tile_cost rule that counts now owns a tile of this map,
      # or avoid_grass is on and the map's grass has wild Pokemon. A search asks it before tile_extra, which it readies.
      def self.costed?
        g = PokeAccess::World::Events.gen
        forget_classes unless g == @kgen
        @kgen = g
        scan = map_scan
        grass = (scan[0] & PokeAccess::World::Terrain::WILD) != 0 && (PokeAccess::Config.avoid_grass rescue false) &&
                wild_grass_map?
        key = [grass, PokeAccess::Puzzles.assist?]
        unless key == @cost_key
          @crows = []
          @cost_key = key
        end
        @grass_on = grass
        grass || scan[6].any? { |r| live?(r.owner) }
      end

      # True when the map's own encounters put wild Pokemon on its grass: land encounters, as has_land_encounters?
      # tells from Essentials 19 on and isGrass? before.
      def self.wild_grass_map?
        enc = $PokemonEncounters
        return false if enc.nil?
        return enc.has_land_encounters? ? true : false if enc.respond_to?(:has_land_encounters?)
        enc.respond_to?(:isGrass?) && enc.isGrass? ? true : false
      rescue StandardError => e
        PokeAccess.swallowed(e)
        false
      end

      # The presses of more stepping onto (x,y) at bridge level lvl costs, taken on first sight (see costed?): nothing on
      # a bridge tile above, where the ground below is not stepped on; a bridge tile below is asked each time.
      def self.tile_extra(x, y, lvl = 0)
        if (klass(x, y) & C_BRIDGE) != 0
          return PokeAccess::Pathfinder.height(lvl) > 0 ? 0 : tile_cost_now(x, y)
        end
        row = (@crows[y] ||= [])
        v = row[x]
        v.nil? ? (row[x] = tile_cost_now(x, y)) : v
      end

      # The presses of more (x,y) costs as it stands now: its grass with avoid_grass, and what each tile_cost rule that
      # owns it answers.
      def self.tile_cost_now(x, y)
        sum = @grass_on && PokeAccess::World::Terrain.wild?(x, y) ? GRASS_COST : 0
        @cost_rules.each do |rule|
          next unless owns?(rule.owner, x, y)
          v = (rule.body.call(x, y) rescue nil).to_i
          sum += v if v > 0
        end
        sum
      end

      # The presses of more a move from (cx,cy) toward dir ([dx, dy, d]) that ends on (nx,ny) at bridge level lvl costs:
      # the tile it lands on when it lands the player there without a walk (landed, see relocated?) or off its way, else
      # each tile it crosses (a step, a hop, a slide, a run).
      def self.crossed_extra(cx, cy, nx, ny, dir, lvl = 0, landed = false)
        dx = dir[0]; dy = dir[1]
        k = dx != 0 ? (nx - cx) * dx : (ny - cy) * dy
        return tile_extra(nx, ny, lvl) if landed || k < 1 || (dx != 0 ? ny != cy : nx != cx)
        sum = 0
        i = 1
        while i <= k
          sum += tile_extra(cx + dx * i, cy + dy * i, lvl)
          i += 1
        end
        sum
      end

      # True for a Step that puts the player down elsewhere without walking the tiles between, where only the landing
      # is stepped on: a carry, a transfer, the action button's climb or warp.
      def self.relocated?(s)
        s.warp || s.kind == :carry || s.kind == :warp || (s.gate.is_a?(Hash) && s.gate[:kind] == :act) ? true : false
      end
    end
  end
end

# The puzzle assist and avoid_grass change which rules count and what a tile costs: every route memo is taken afresh.
PokeAccess::Events.on(:config_changed) do |key|
  PokeAccess::Pathfinder.invalidate_cache(true) if key == :puzzle_assist || key == :avoid_grass
end
