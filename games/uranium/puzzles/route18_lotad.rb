# Route 18's Lotad pond (map 227). The Ludicolo (events 19, 28, 30, 32, 33 and 76) rouse the Lotad (the "lotadwalker"
# events) or settle them, switch 228, which an autorun turns on at each arrival. Awake, a Lotad moves one tile the way
# the player faces when pressed, from open water to open water, or right over anything; settled, it is a pad. The
# obstacles ("lotadblock") stop the player, never a Lotad pushed onto one, which then moves only right; settled there,
# it lets the player across. The way north to Sawed-Off Cove passes the obstacles at (13 to 15, 32); the pond starts over
# each time the map loads, so it stands solved while the player is north of them. The assist follows a plan searched
# against the map's tiles and events: a Lotad onto each obstacle that opens the middle, the east and the north-west
# water, then the Lotad of 16,41 onto the channel.
module PokeAccess
  module UraniumLotad
    def self.walkers; [3, 5, 9, 20, 21, 22, 65, 68, 69, 70, 71, 74, 77]; end
    def self.masters; [19, 28, 30, 32, 33, 76]; end
    def self.obstacles; [8, 58, 59, 60, 61, 62, 63, 66, 67, 72]; end
    def self.bridge_tiles; [[13, 32], [14, 32], [15, 32]]; end
    def self.deltas; { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }; end
    def self.push_keys; { 2 => :ura_r2_push_down, 4 => :ura_r2_push_left, 6 => :ura_r2_push_right, 8 => :ura_r2_push_up }; end

    def self.settled?; $game_switches[228] ? true : false; end

    # True while the player stands north of the channel's obstacles, which only a Lotad on one of them lets them reach.
    def self.north?; $game_player.x >= 12 && $game_player.y <= 31; end

    def self.walker_name(_ev)
      settled? ? :ura_r2_lotad_pad : :ura_r2_lotad_awake
    end

    # The Lotad standing on the obstacles of the north-west channel, or nil.
    def self.bridge
      walkers.map { |id| $game_map.events[id] }.compact.find { |ev| bridge_tiles.include?([ev.x, ev.y]) }
    end

    # The plan's groups in turn: the Lotad moved, the Ludicolo that rouses them, the tile it is spoken to from, and the
    # pushes as [x, y, direction]. Any of the first four may be done first; the last four move the Lotad of 16,41.
    def self.plan
      [[65, [12, 43], [13, 43], [[24, 43, 4], [23, 43, 8], [23, 42, 8], [23, 41, 8]]],
       [70, [15, 38], [16, 38], (18..24).map { |x| [x, 39, 6] }],
       [71, [26, 33], [26, 34], [[25, 34, 4]]],
       [69, [15, 38], [16, 38], [[16, 39, 4]]],
       [74, [12, 43], [13, 43], [[16, 41, 8], [16, 40, 8]]],
       [74, [15, 38], [15, 39], (16..22).map { |x| [x, 39, 6] }],
       [74, [24, 40], [23, 40], [39, 38, 37, 36, 35].map { |y| [23, y, 8] }],
       [74, [24, 33], [24, 34], [23, 22, 21, 20, 19, 18, 17, 16].map { |x| [x, 34, 4] } + [[15, 34, 8], [15, 33, 8]]]]
    end

    # The Lotad the plan leaves where they arrive.
    def self.homes; { 68 => [15, 43], 77 => [28, 45] }; end

    def self.at(id)
      ev = $game_map.events[id]
      ev ? [ev.x, ev.y] : nil
    end

    def self.end_of(group)
      x, y, d = group[3].last
      dx, dy = deltas[d]
      [x + dx, y + dy]
    end

    def self.done?(group); at(group[0]) == end_of(group); end

    # The plan's next push as [group, push] by where the Lotad stand, or nil when they stand off it.
    def self.next_push
      return nil unless homes.all? { |id, xy| at(id) == xy }
      first, last = plan[0, 4], plan[4, 4]
      moving = nil
      first.each do |g|
        next if done?(g)
        push = g[3].find { |x, y, _d| at(g[0]) == [x, y] }
        return nil unless push
        next if push == g[3].first
        return nil if moving
        moving = [g, push]
      end
      pending = first.find { |g| !done?(g) }
      if pending
        return nil unless at(74) == [16, 41]
        return moving || [pending, pending[3].first]
      end
      last.each do |g|
        push = g[3].find { |x, y, _d| at(74) == [x, y] }
        return [g, push] if push
      end
      nil
    end

    # The water the roused player crosses, x 11 to 27 and y 33 to 46: "." open, "o" open and joined to the land around,
    # "+" shore shut to the north, "#" closed; any other tile is land.
    def self.mask
      ["..........##.####", ".............#..#", ".............##.#", "...#+#####.#.##.#", "##+#########.##.#",
       "#####.....##.##.#", "##..#.........#.#", "##.##...#++####++", "##.##.######..###", "o........##.....o",
       "o#...............", "o..............##", "................#", "....###ooooo#oooo"]
    end

    def self.cell(x, y)
      return nil unless x >= 11 && x <= 27 && y >= 33 && y <= 46
      mask[y - 33][x - 11, 1]
    end

    # The rows of the land around the pond that the walk goes on through, from the woods north of it to the south shore.
    def self.land_rows; 26..56; end

    def self.land?(x, y)
      land_rows.include?(y) && ($game_map.valid?(x, y) rescue false)
    end

    # The tiles the roused player reaches, in the order a walk gets to them, nearest first, and as a set: over the open
    # water, never through an awake Lotad, out of the player's own tile even when a Lotad on an obstacle shares it, and
    # through the land around, step by step as the player walks it, which joins the water at its "o" tiles. Kept while
    # the Lotad and the player stay as they are.
    def self.region
      key = [$game_player.x, $game_player.y] + walkers.map { |id| at(id) }
      return @region[1] if @region && @region[0] == key
      @region = [key, region_now]
      @region[1]
    end

    def self.region_now
      solid = {}
      walkers.each { |id| xy = at(id); solid[xy] = true if xy }
      me = [$game_player.x, $game_player.y]
      blocked_here = cell(me[0], me[1]) == "#" && !obstacles.any? { |id| at(id) == me }
      seen = { me => true }
      order = [me]
      queue = blocked_here ? [] : [me]
      PokeAccess::World::Probe.session do
        until queue.empty?
          x, y = queue.shift
          deltas.each do |d, step|
            n = [x + step[0], y + step[1]]
            next if seen[n] || solid[n] || !step?(x, y, d, n)
            seen[n] = true
            order.push(n)
            queue.push(n)
          end
        end
      end
      [order, seen]
    end

    # True when the roused player can step from (x, y) toward d onto n: by the pond's tiles on the water, by the game's
    # own steps on the land, and between the two only at an "o" tile.
    def self.step?(x, y, d, n)
      here = cell(x, y)
      there = cell(n[0], n[1])
      return land_step?(x, y, d, n) if here.nil? && there.nil?
      return there == "o" if here.nil?
      return here == "o" && land_step?(x, y, d, n) if there.nil?
      return false if there == "#"
      !((d == 8 && here == "+") || (d == 2 && there == "+"))
    end

    def self.land_step?(x, y, d, n)
      land?(n[0], n[1]) && PokeAccess::World::Probe.step?(x, y, d)
    end

    def self.reach?(goal); region[1][goal] ? true : false; end

    # The Ludicolo the roused player gets to first and the tile to speak to it from, as [[x, y], [x, y]], or nil.
    def self.nearest_master
      spots = masters.map { |id| at(id) }.compact
      region[0].each do |x, y|
        m = spots.find { |mx, my| (mx - x).abs + (my - y).abs == 1 }
        return [m, [x, y]] if m
      end
      nil
    end

    # Where the player should stand for the plan's next step: the push's side, or the tile to rouse the Lotad from.
    # Kept while the Lotad, the player and the switch stay as they are.
    def self.stand
      key = [settled?, $game_player.x, $game_player.y] + walkers.map { |id| at(id) }
      return @stand[1] if @stand && @stand[0] == key
      @stand = [key, stand_now]
      @stand[1]
    end

    def self.stand_now
      return nil if north? || bridge
      step = next_push
      return nil unless step
      group, push = step
      return group[2] if settled?
      x, y, d = push
      tile = [x - deltas[d][0], y - deltas[d][1]]
      reach?(tile) ? tile : group[2]
    end

    def self.stand_tiles
      plan.inject([]) { |all, g| all + [g[2]] + g[3].map { |x, y, d| [x - deltas[d][0], y - deltas[d][1]] } }.uniq
    end

    # The next step: cross, or settle at the Ludicolo within reach, once a Lotad covers the channel; else the plan's
    # rousing or push, or the reset.
    def self.hint
      return "" if north?
      lotad = bridge
      return bridge_hint(lotad) if lotad
      step = next_push
      unless step
        home = at(1)
        return home ? [:ura_r3_lotad_reset, { :x => home[0], :y => home[1] }] : ""
      end
      group, push = step
      spot = { :mx => group[1][0], :my => group[1][1], :x => group[2][0], :y => group[2][1] }
      return [:ura_r3_lotad_rouse_at, spot] if settled?
      x, y, d = push
      return [push_keys[d], { :x => x, :y => y }] if reach?([x - deltas[d][0], y - deltas[d][1]])
      calm = nearest_master
      return [:ura_r3_lotad_reroute_any, spot] unless calm
      [:ura_r3_lotad_reroute, spot.dup.merge!(:cx => calm[0][0], :cy => calm[0][1], :sx => calm[1][0], :sy => calm[1][1])]
    end

    def self.bridge_hint(lotad)
      at_bridge = { :x => lotad.x, :y => lotad.y }
      return [:ura_r2_lotad_cross, at_bridge] if settled?
      calm = nearest_master
      return [:ura_r2_lotad_settle_now, at_bridge] unless calm
      [:ura_r3_lotad_settle_at, at_bridge.dup.merge!(:mx => calm[0][0], :my => calm[0][1], :sx => calm[1][0], :sy => calm[1][1])]
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 227) do
    auto
    name PokeAccess::UraniumLotad.walkers, lambda { |ev| PokeAccess::UraniumLotad.walker_name(ev) }
    name PokeAccess::UraniumLotad.masters, :ura_r2_ludicolo
    name 1, :ura_r2_ludicolo_reset
    name PokeAccess::UraniumLotad.obstacles, :ura_r3_lotad_obstacle
    watch :switch => 228, :label => :ura_r2_lotad_state, :on => :ura_r2_lotad_settled, :off => :ura_r2_lotad_roused
    arrival_hint :ura_r2_lotad_rule
    hint lambda { PokeAccess::UraniumLotad.hint }
    PokeAccess::UraniumLotad.stand_tiles.each do |tile|
      spot :at => tile, :label => :ura_r3_lotad_next, :assist => true, :onto => true,
           :when => lambda { PokeAccess::UraniumLotad.stand == tile }
    end
    solved(nil, :quiet => true) { PokeAccess::UraniumLotad.north? }
  end
end
