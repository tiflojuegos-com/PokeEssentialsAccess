# The shrine rooms whose parallel event checks each pushed statue (pbMoverEstatuas: pushed holding the way toward it,
# pulled with C) on a tile of its own: Water (218, 219), Fire's north-east room (342), Earth (371, 375, 377) and Wind
# (271, 287, 288). The floor marks drawn under the goals are listed for everyone; with the puzzle assist a phase per
# statue still off its tile takes it there, in an order where no statue waits on a tile another has to reach first.
module PokeAccess
  module AwakeningMarks
    # map => [win, the marked floor tiles a sighted player sees, [[event, goal tile, label], ...]]; the win is the check
    # event whose self switch A the game sets, [:switch, id], or a test.
    ROOMS = {
      218 => [12, [[28, 4], [24, 7], [32, 7], [28, 10]],
              [[11, [28, 4], [:awk_statue_n, { :n => 1 }]], [8, [24, 7], [:awk_statue_n, { :n => 2 }]],
               [9, [28, 10], [:awk_statue_n, { :n => 3 }]], [10, [32, 7], [:awk_statue_n, { :n => 4 }]]]],
      219 => [11, [[29, 28], [33, 28], [29, 34], [33, 34]],
              [[7, [29, 34], [:awk_statue_n, { :n => 1 }]], [8, [33, 34], [:awk_statue_n, { :n => 2 }]],
               [9, [33, 28], [:awk_statue_n, { :n => 3 }]], [10, [29, 28], [:awk_statue_n, { :n => 4 }]]]],
      342 => [[:switch, 213], [[7, 13], [11, 13], [9, 15], [7, 17], [11, 17]],
              [[1, [7, 17], :awk_statue_blue], [2, [11, 17], :awk_statue_green], [3, [9, 15], :awk_statue_red],
               [4, [7, 13], :awk_statue_violet], [5, [11, 13], :awk_statue_yellow]]],
      371 => [5, [[9, 8], [4, 11], [14, 11], [9, 14]],
              [[1, [9, 8], :awk_statue_light], [2, [9, 14], :awk_statue_dark]]],
      375 => [7, [[21, 9], [29, 9], [21, 14], [29, 14]],
              [[2, [29, 9], :awk_idol_earth], [3, [29, 14], :awk_idol_fire], [4, [21, 9], :awk_idol_wind],
               [5, [21, 14], :awk_idol_water]]],
      377 => [6, [],
              [[4, [12, 13], [:awk_slab_n, { :n => 3 }]], [3, [15, 18], [:awk_slab_n, { :n => 1 }]],
               [5, [6, 10], [:awk_slab_n, { :n => 4 }]]]],
      271 => [7, [[45, 4], [45, 19]],
              [[5, [45, 19], [:awk_slab_n, { :n => 1 }]], [6, [45, 4], [:awk_slab_n, { :n => 2 }]]]],
      287 => [lambda { PokeAccess::AwakeningMarks.slabs_open? },
              [[46, 6], [53, 6], [61, 6], [46, 9], [61, 9], [41, 12], [50, 12], [56, 12], [46, 16], [61, 17], [51, 20]],
              [[1, [51, 20], [:awk_slab_n, { :n => 1 }]], [2, [56, 12], [:awk_slab_n, { :n => 2 }]],
               [5, [61, 9], [:awk_slab_n, { :n => 5 }]], [3, [61, 6], [:awk_slab_n, { :n => 3 }]],
               [4, [53, 6], [:awk_slab_n, { :n => 4 }]]]],
      288 => [20, [[12, 24]], [[19, [12, 24], [:awk_slab_n, { :n => 1 }]]]]
    }
    # The two slabs of map 287 whose tiles the check takes either way round.
    SWAPPED = { 1 => [56, 12], 2 => [51, 20] }

    # True once map 287's door is open: its parallel check sets its self switch A, or B with the first two slabs swapped,
    # and both it and the asking one open the door (its A).
    def self.slabs_open?
      [[287, 17, "A"], [287, 17, "B"], [287, 6, "A"]].any? { |key| $game_self_switches[key] }
    end

    # True once the game has taken the room's statues as placed.
    def self.won?(map)
      win = ROOMS[map][0]
      return $game_switches[win[1]] ? true : false if win.is_a?(Array)
      return win.call ? true : false if win.respond_to?(:call)
      $game_self_switches[[map, win, "A"]] ? true : false
    end

    # True on map 287 once either of its first two slabs stands on the other's tile: the check takes them swapped.
    def self.swapped?
      one = $game_map.events[1]
      two = $game_map.events[2]
      (one && [one.x, one.y] == SWAPPED[1]) || (two && [two.x, two.y] == SWAPPED[2]) ? true : false
    end

    # The goals an event may take, each with the test for while it is the one: the swap of map 287's first two slabs
    # follows the way the player is placing them.
    def self.goals(map, ev_id, goal)
      return [[goal, lambda { true }]] unless map == 287 && SWAPPED[ev_id]
      [[goal, lambda { !swapped? }], [SWAPPED[ev_id], lambda { swapped? }]]
    end

    # True while the event stands on the tile.
    def self.on?(ev_id, tile)
      ev = $game_map.events[ev_id]
      ev ? [ev.x, ev.y] == tile : false
    end
  end
end

PokeAccess::Game.define("awakening") do
  marks = PokeAccess::AwakeningMarks
  marks::ROOMS.each do |map, (_win, floor, pieces)|
    mechanic(:state, map, :part => :marks) do
      auto
      pieces.each { |ev, _goal, label| name ev, label }
      if map == 288
        name 18, [:awk_slab_n, { :n => 1 }]
        phase lambda { PokeAccess::Puzzles.assist? && !marks.won?(map) && !$game_self_switches[[288, 19, "A"]] },
              :quiet => true, :hint => :awk_slab_drop_hint
      end
      floor.each { |x, y| spot :at => [x, y], :label => :awk_floor_mark, :onto => true, :when => lambda { !marks.won?(map) } }
      pieces.each do |ev, goal, label|
        marks.goals(map, ev, goal).each do |tile, live|
          phase lambda { PokeAccess::Puzzles.assist? && !marks.won?(map) && live.call && !marks.on?(ev, tile) },
                :quiet => true,
                :hint => lambda { [:awk_mark_hint, { :name => PokeAccess::Puzzles.label_of(label), :x => tile[0], :y => tile[1] }] },
                :track => { :event => ev, :label => label, :goal => [tile[0], tile[1], tile[0], tile[1]],
                            :goal_label => :awk_floor_mark }
        end
      end
      solved { marks.won?(map) }
    end
  end
end
