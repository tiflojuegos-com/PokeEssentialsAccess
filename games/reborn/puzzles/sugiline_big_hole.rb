# The Sugiline Cave's Big Hole (maps 651 to 659): holes of the upper floors drop to the B1F maps, whose sand pits drop
# back to the cave's mouth and whose stairs climb to another upper floor. Each button of 654 lies in a pocket reached by
# one chain of holes and stairs (switch 887 in four steps, 886 in seven). A map's parts are told by the landing.
module PokeAccess
  module RebornSugilineHole
    REGIONS = {
      653 => [[:mid, [[35, 27]], [[28, 37, 20, 31]]], [:south, [[44, 38]], [[41, 54, 32, 40]]],
              [:east, [[49, 23], [35, 14]], [[35, 50, 13, 31]]], [:west, [[12, 31]], [[12, 33, 9, 33]]]],
      654 => [[:left, [[9, 24]], [[9, 18, 23, 30]]], [:right, [[33, 23]], [[31, 37, 23, 30]]]],
      656 => [[:east, [[37, 34], [44, 25], [45, 27]], [[32, 45, 22, 49]]]],
      657 => [[:south, [[55, 58], [49, 54], [49, 60]], [[47, 65, 49, 65]]],
              [:west, [[18, 39], [11, 12]], [[11, 12, 11, 33], [17, 19, 36, 41]]]],
      659 => [[:pocket, [[39, 28]], [[36, 40, 28, 36]]]]
    }
    PLAN = {
      651 => { :right => [[nil, [17], :rbre_sh_r1]], :left => [[nil, [13], :rbre_sh_l1]],
               :stairs => [[nil, [5], :rbre_sh_s1]] },
      652 => { :left => [[nil, [6], :rbre_sh_l3]] },
      653 => { :left => [[:west, [41], :rbre_sh_l5], [:east, [47], :rbre_sh_l7]] },
      654 => { :right => [[:right, [57], :rbre_sh_r5]], :left => [[:left, [56], :rbre_sh_l8]],
               :stairs => [[:main, [4], :rbre_sh_s3]] },
      655 => { :right => [[nil, [18], :rbre_sh_r3]] },
      656 => { :right => [[:east, [1], :rbre_sh_r2]], :stairs => [[:main, [4], :rbre_sh_s2]] },
      657 => { :left => [[:south, [4], :rbre_sh_l2], [:west, [1], :rbre_sh_l4]] },
      658 => { :left => [[nil, [1], :rbre_sh_l6]] },
      659 => { :right => [[:main, [1], :rbre_sh_r4]] }
    }
    PIT = [nil, [], :rbre_sh_back_pit]
    BACK = {
      652 => [[nil, [1], :rbre_sh_back]],
      653 => [[:west, [5], :rbre_sh_back], [:mid, [3], :rbre_sh_back], [:south, [1], :rbre_sh_back],
              [:east, [2], :rbre_sh_back]],
      654 => [[:left, [58], :rbre_sh_back], [:right, [1], :rbre_sh_back], [:main, [2], :rbre_sh_back]],
      655 => [[nil, [1], :rbre_sh_back]],
      656 => [PIT],
      657 => [[:west, [1], :rbre_sh_back], PIT],
      658 => [PIT],
      659 => [PIT]
    }

    # Forgets where the visit began.
    def self.forget
      @entry = nil
    end

    # The button the plan goes for next, or the stairs once both are pressed.
    def self.goal
      return :right unless $game_switches[887]
      return :left unless $game_switches[886]
      :stairs
    end

    # The part of the map the player walks in: by the tile the visit began on, a landing or within a box; else :main.
    def self.region(map)
      @entry = [map, $game_player.x, $game_player.y] unless @entry && @entry[0] == map
      at = @entry[1, 2]
      regs = REGIONS[map] || []
      hit = regs.find { |_r, lands, _b| lands.include?(at) } ||
            regs.find { |_r, _l, boxes| boxes.any? { |x0, x1, y0, y1| at[0].between?(x0, x1) && at[1].between?(y0, y1) } }
      hit ? hit[0] : :main
    end

    # The step that goes on from here, [part, events, hint]: the plan's for the goal, else the way back.
    def self.step(map)
      reg = region(map)
      ((PLAN[map] || {})[goal] || []).find { |s| s[0].nil? || s[0] == reg } ||
        (BACK[map] || []).find { |s| s[0].nil? || s[0] == reg }
    end

    # Every step a map can give, each once.
    def self.steps(map)
      out = []
      (PLAN[map] || {}).each_value { |s| out.concat(s) }
      out.concat(BACK[map] || [])
      out.uniq
    end
  end
end

PokeAccess::Game.define("reborn") do
  hole = PokeAccess::RebornSugilineHole
  (651..659).each do |map|
    mechanic(:state, map, :part => :big_hole) do
      auto
      hole.steps(map).each do |entry|
        opts = { :quiet => true, :hint => entry[2] }
        opts[:hidden] = right_way(*entry[1]) unless entry[1].empty?
        phase(lambda { PokeAccess::Puzzles.assist? && hole.step(map).equal?(entry) }, opts)
      end
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornSugilineHole.forget }
