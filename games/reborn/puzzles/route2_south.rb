# Route 2, south half (map 360): four Crustles wait in nests. Sleep Powder from a green tree (switch 464) puts the one
# out of its nest to sleep (self switch B) and the action button pushes it, some pushes tumbling it several tiles; into
# a hole it fills it. Switch 410 on is the lower level: a route ends on the level its next push is made from.
module PokeAccess
  module RebornRoute2
    MAP = 360
    SLEEP_TREES = [1, 19, 20, 21, 35, 36, 49, 50, 42, 43, 44, 45, 160, 161, 193, 209, 172, 173, 174, 175]
    RAGE_TREES = [68, 78, 80, 81, 104, 105, 111, 112, 151, 152, 153, 154, 169, 183, 187, 188, 176, 177, 178, 179,
                  216, 217, 218, 219]
    UNSTABLE = [64, 76, 77, 79, 142, 143, 156, 162, 167, 168]
    HOLES = { 98 => 469, 74 => 470, 73 => 471, 82 => 472 }
    CRUSTLES = [2, 123, 137, 198]
    DIRS = { 2 => :dir_s, 4 => :dir_o, 6 => :dir_e, 8 => :dir_n }
    DROPS = { 198 => { [40, 88] => 2, [39, 95] => 2 }, 137 => { [44, 87] => 4 }, 123 => { [27, 84] => 2, [25, 88] => 3 } }
    LOWER = 410
    # [crustle, its hole's switch, tile it comes out to, where to take the powder from, legs [x, y, way, pushes, on the
    # lower level or not, nil for either]]
    PLANS = [
      [137, 471, [45, 77], [43, 82], [[46, 77, 4, 2], [43, 76, 2, 5], [42, 82, 6, 1], [44, 81, 2, 5], [44, 86, 2, 1]]],
      [123, 472, [32, 84], [20, 73], [[33, 84, 4, 5], [27, 83, 2, 1], [28, 86, 4, 4], [23, 85, 2, 2], [22, 88, 6, 2],
                                      [25, 87, 2, 1]]],
      [198, 470, [46, 67], [37, 57], [[47, 67, 4, 2, true], [44, 66, 2, 3, true], [45, 70, 4, 2, true],
                                      [42, 69, 2, 1, true], [43, 71, 4, 2, true], [40, 70, 2, 4, true], [41, 75, 4, 1, true],
                                      [39, 74, 2, 3, true], [39, 77, 2, 2, false], [38, 80, 6, 1, false],
                                      [40, 79, 2, 9, false], [41, 90, 4, 2, false], [38, 89, 2, 2, false],
                                      [37, 92, 6, 1, false], [39, 91, 2, 4, false], [40, 97, 4, 5, false],
                                      [34, 98, 8, 5, false], [33, 92, 6, 1, false], [35, 93, 8, 1, false]]],
      [2, 469, [48, 35], [48, 42], [[49, 35, 4, 2], [46, 34, 2, 1], [45, 36, 6, 2], [48, 35, 2, 5], [47, 41, 6, 3],
                                    [51, 40, 2, 1], [50, 42, 6, 3]]]
    ]

    # Where the Crustle lands after a push from pos the given way.
    def self.after(plan, pos, d)
      drop = d == 2 && (DROPS[plan[0]] || {})[pos]
      return [pos[0], pos[1] + drop] if drop
      dd = PokeAccess::DIR_DELTA[d]
      [pos[0] + dd[0], pos[1] + dd[1]]
    end

    # The plan's pushes by the Crustle's tile: [stand x, stand y, way, pushes left, level], walked once from its legs.
    def self.table(plan)
      @tables ||= {}
      @tables[plan[0]] ||= begin
        t = {}
        pos = plan[2]
        left = plan[4].inject(0) { |sum, leg| sum + leg[3] }
        plan[4].each do |sx, sy, d, n, lower|
          stand = [sx, sy]
          n.times do
            t[pos] = [stand[0], stand[1], d, left, lower]
            left -= 1
            stand = pos
            pos = after(plan, pos, d)
          end
        end
        t
      end
    end

    def self.asleep?(id)
      $game_self_switches[[MAP, id, "B"]] ? true : false
    end

    def self.push_line(key, s)
      [key, { :x => s[0], :y => s[1], :dir => PokeAccess::I18n.t(DIRS[s[2]]), :left => s[3] }]
    end

    # The level the next push of the sleeping Crustle on (x,y) is made from (true for the lower one), or nil: what a
    # route to it ends on.
    def self.push_floor(x, y)
      return nil unless $game_map.map_id == MAP
      plan = current
      ev = plan && $game_map.events[plan[0]]
      return nil unless ev && ev.x == x && ev.y == y && asleep?(plan[0])
      s = table(plan)[[x, y]]
      s && s[4]
    end

    # The first Crustle whose hole is still open, in the plans' order.
    def self.current
      PLANS.find { |p| !$game_switches[p[1]] }
    end

    # The assisted line for a Crustle as things stand: powder, nest, sleep, then the next push. The Crustle waits two
    # tiles behind the tile it comes out to, its nest between them.
    def self.step_for(plan)
      ev = $game_map.events[plan[0]]
      return nil unless ev
      at = [ev.x, ev.y]
      home = [plan[2][0], plan[2][1] - 2]
      unless asleep?(plan[0]) && at != home
        return [:rbb_r2_get_powder, { :x => plan[3][0], :y => plan[3][1] }] unless $game_switches[464]
        return [:rbb_r2_use_nest, { :x => plan[2][0], :y => plan[2][1] - 1 }] if at != plan[2]
        return :rbb_r2_sleep_it
      end
      return :rbb_r2_drop_rage if $game_switches[463]
      s = table(plan)[at]
      s ? push_line(:rbb_r2_push, s) : :rbb_r2_off_plan
    end

    # As a sleeping Crustle is pushed the planned way, the push after this one.
    def self.then_line(ev)
      plan = PLANS.find { |p| p[0] == ev.id }
      return nil unless plan && asleep?(ev.id)
      s = table(plan)[[ev.x, ev.y]]
      return nil unless s && $game_player.x == s[0] && $game_player.y == s[1] && $game_player.direction == s[2]
      n = table(plan)[after(plan, [ev.x, ev.y], s[2])]
      n ? push_line(:rbb_r2_then, n) : nil
    end
  end
end

PokeAccess::Routes::Effects.floor_source { |x, y| PokeAccess::RebornRoute2.push_floor(x, y) }

PokeAccess::Game.define("reborn") do
  r2 = PokeAccess::RebornRoute2
  mechanic(:state, r2::MAP, :part => :crustles) do
    auto
    name r2::SLEEP_TREES, :rbb_r2_sleep_tree, :grouped => true
    name r2::RAGE_TREES, :rbb_r2_rage_tree, :grouped => true
    name [3, 122, 136, 199], :rbb_r2_nest
    name r2::CRUSTLES, lambda { |ev| r2.asleep?(ev.id) ? :rbb_r2_crustle_asleep : :rbb_r2_crustle_awake }
    name r2::HOLES.keys, :rbb_r2_hole_filled
    r2::HOLES.each { |id, sw| spot :event => id, :label => :rbb_r2_hole, :when => lambda { !$game_switches[sw] } }
    name r2::UNSTABLE, :rbb_r2_unstable_rock, :assist => true
    avoid r2::UNSTABLE, :assist => true
    count :rbb_r2_holes, :switches => [469, 470, 471, 472]
    arrival_hint :rbb_r2_rule
    r2::PLANS.each do |plan|
      phase lambda { r2.current.equal?(plan) }, :hint => lambda { r2.step_for(plan) }
    end
    on_use r2::CRUSTLES, lambda { |ev| r2.then_line(ev) }, :assist => true
    solved(nil, :quiet => true) { [469, 470, 471, 472].all? { |s| $game_switches[s] } }
  end
end
