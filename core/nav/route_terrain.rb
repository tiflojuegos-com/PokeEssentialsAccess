module PokeAccess
  # Pathfinder, what one step over the terrain does (step_target): a ledge hop, an ice run, the map's border, falling
  # water, and the terrain a game or plugin registers (arrival_rule) because its tag numbers differ between games.
  module Pathfinder
    # How far a forced movement is followed before it is taken for a loop the game would never leave.
    ARRIVAL_CAP = 200

    # Registers a terrain rule: the block gets (x, y, d) for a step arriving on (x,y) in direction d and answers the
    # [x, y] it ends on, false when the step cannot be taken, or nil when the tile is none of its terrain.
    def self.arrival_rule(&rule)
      @arrival_rules ||= []
      @arrival_rules.push(rule)
    end

    # Registers the tiles where the player has to keep the direction key held down, or the terrain throws
    # them back: the block gets (x, y) and answers true on such a tile.
    def self.held_key_rule(&rule)
      @held_rules ||= []
      @held_rules.push(rule)
    end

    # Registers terrain the player leaves by a move of its own (a rail hopped off): the block gets (x, y, dir) and
    # answers the [x, y] the press lands on, false when it fails, or nil when (x,y) is none of its terrain.
    def self.leave_rule(&rule)
      @leave_rules ||= []
      @leave_rules.push(rule)
    end

    # True when a game or plugin registered terrain that moves the player on arriving or leaving.
    def self.ruled_terrain?
      !(@arrival_rules || []).empty? || !(@leave_rules || []).empty?
    end

    # The move a registered rule makes leaving (x,y) toward dir: [x, y], false when it fails, nil when no
    # rule owns the tile.
    def self.departure(x, y, dir)
      (@leave_rules || []).each do |rule|
        r = (rule.call(x, y, dir) rescue nil)
        return r unless r.nil?
      end
      nil
    end

    # Where a step that arrives on (x,y) moving in direction d ends, as [x, y], or nil when it goes nowhere:
    # the first rule that owns the tile decides, else the tile itself.
    def self.arrive(x, y, d)
      r = waterfall_descent(x, y, d)
      return (r ? r : nil) unless r.nil?
      (@arrival_rules || []).each do |rule|
        r = (rule.call(x, y, d) rescue nil)
        next if r.nil?
        return r ? r : nil
      end
      [x, y]
    end

    # True if the player must hold the direction key down on (x,y): ground a game registers, or a touch event
    # there that lets the player on only so (see route_events).
    def self.held_key_at?(x, y)
      return true if (@held_rules || []).any? { |rule| (rule.call(x, y) rescue false) }
      t = touch_index[pkey(x, y)]
      !t.nil? && t[1].values.any? { |e| e[0] == :hold }
    end

    # Falling water: a surfer who moves down onto the crest of a waterfall is carried down it to the first
    # tile below that is neither the crest nor the fall (pbDescendWaterfall in both eras). nil anywhere else.
    def self.waterfall_descent(x, y, d)
      return nil unless d == 2 && ($PokemonGlobal.surfing rescue false)
      return nil unless PokeAccess::Terrain.kind(x, y) == :waterfall_crest
      fall_end(x, y, 1) || false
    end

    # Climbing a waterfall with Waterfall, from the water below it facing up: to the first tile above that is
    # neither the fall nor its crest. [x, y], or nil when (x,y) is no waterfall.
    def self.waterfall_ascent(x, y)
      falling_water?(x, y) ? fall_end(x, y, -1) : nil
    end

    # The first tile from (x,y), going dy rows at a time (down 1, up -1), that is neither a waterfall nor its
    # crest, or nil past the map's edge or a fall too long to be one.
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
      k = PokeAccess::Terrain.kind(x, y)
      k == :waterfall || k == :waterfall_crest
    end

    # Where a step from (cx,cy) in a direction ends, or nil when blocked: a registered departure, else a ledge hop
    # with allow_ledge (tested before passability: engines leave a ledge passable from the high side), else a passable
    # step (riding ice), else with edge_relax a passable border tile.
    def self.step_target(cx, cy, dir, allow_ledge, edge_relax)
      dx, dy, d = dir
      nx = cx + dx; ny = cy + dy
      left = departure(cx, cy, dir)
      return (left ? left : nil) unless left.nil?
      t = (PokeAccess::Terrain.raw(nx, ny) rescue nil)
      if PokeAccess::Terrain.ledge?(t)
        return allow_ledge ? ledge_jump(cx, cy, dx, dy, d) : nil
      end
      if passable_at?(cx, cy, d)
        return ice_slide(nx, ny, dx, dy, d) if PokeAccess::Terrain.ice?(t)
        return arrive(nx, ny, d)
      end
      return [nx, ny] if edge_relax && border_tile?(nx, ny) && ($game_map.passable?(nx, ny, 0) rescue false)
      allow_ledge ? ledge_jump(cx, cy, dx, dy, d) : nil
    end

    # Where a ledge hop from (cx,cy) in direction d lands, two tiles on, or nil: no ledge that way, a barred direction
    # (ledge_dir_ok?) or a landing that cannot be stood on.
    def self.ledge_jump(cx, cy, dx, dy, d)
      nx = cx + dx; ny = cy + dy
      return nil unless PokeAccess::Terrain.ledge_at?(nx, ny)
      return nil unless ledge_dir_ok?(nx, ny, d)
      landing(cx + 2 * dx, cy + 2 * dy)
    rescue StandardError
      nil
    end

    # Jump direction => the tileset-passage bit of the side opposite the jump.
    LEDGE_OPP_BIT = { 2 => 0x08, 8 => 0x01, 4 => 0x04, 6 => 0x02 }

    # True if the ledge at (x,y) may be hopped in direction d, its side opposite the jump being open; also true when
    # the passage cannot be read or ledge_directions is off.
    def self.ledge_dir_ok?(x, y, d)
      return true unless (PokeAccess::Config.ledge_directions rescue true)
      ob = LEDGE_OPP_BIT[d]
      return true unless ob
      p = ledge_passage(x, y)
      return true if p.nil?
      (p & ob) == 0
    rescue StandardError
      true
    end

    # The tileset passage byte of the ledge tile at (x,y) (the top layer whose terrain is a ledge), or
    # nil when the passage/terrain tables are unavailable (a non-RMXP engine).
    def self.ledge_passage(x, y)
      passages = $game_map.instance_variable_get(:@passages)
      tags = $game_map.instance_variable_get(:@terrain_tags)
      return nil unless passages && tags
      [2, 1, 0].each do |i|
        tid = ($game_map.data[x, y, i] rescue 0)
        next if tid.nil? || tid == 0
        return passages[tid] if tags[tid] == 1
      end
      nil
    rescue StandardError
      nil
    end

    # Where an ice slide from (x,y) stops: on until the tile is not ice or the next step is blocked (ARRIVAL_CAP). A
    # touch event slid over fires: a warp or carry sets where it ends, a doorway or story block voids it.
    def self.ice_slide(x, y, dx, dy, d)
      guard = 0
      while PokeAccess::Terrain.ice_at?(x, y) && guard < ARRIVAL_CAP
        guard += 1
        break unless passable_at?(x, y, d)
        e = touch_at(x, y, d, true)
        return slid_over(x, y, e) if e && e[0] != :ramp && !IN_PLACE.include?(e[0])
        x += dx; y += dy
      end
      [x, y]
    end

    # Where a slide that passes over a touch event at (x,y) ends up, or nil when it cannot be taken.
    def self.slid_over(x, y, e)
      case e[0]
      when :warp then landing(e[1], e[2])
      when :carry then carry_landing(x, y, e)
      end
    end

    # True if a tile is on the outer border of the map (where connection/exit tiles live).
    def self.border_tile?(x, y)
      return false unless $game_map
      x <= 0 || y <= 0 || x >= $game_map.width - 1 || y >= $game_map.height - 1
    rescue StandardError
      false
    end
  end
end
