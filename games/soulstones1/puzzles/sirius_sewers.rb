# Sirius Sewers (maps 193, 195, 196 and 197): sprite-less control panels flip a pair of sectors each (switches 67, 68,
# 69, 70 and 72: the odd sector's gates lowered while on, the even one's raised), the "Switch Gate" events read them,
# and coming in from Sirius City (map 181) raises every pair again. Nine gang members raise variable 105 from 1 to 10 (their
# self switch A once beaten), and then the showdown in the south of map 197 (event 27) shows up; with variable 100 at 9
# every gate stands open. The assist's step comes from the regions the gates split each map into, read off the maps.
module PokeAccess
  module SoulstonesSewers
    MAPS = [193, 195, 196, 197]
    PAIRS = [[67, 1], [68, 3], [69, 5], [70, 7], [72, 9]]
    PANELS = { 193 => { 11 => 67, 18 => 68, 33 => 68 }, 196 => { 15 => 70, 16 => 72, 21 => 72 },
               197 => { 5 => 67, 11 => 69, 17 => 70 } }
    # Map => [the switches its gates read, for each state of them (bit i: the i-th switch on) the regions they join,
    # doors [region, event, [map, region] or :city], panels [region, event, switch], gang members [region, event],
    # regions {id => {row => x ranges}}]: the floor split by every gate shut.
    ROOMS = {
      193 => [[67, 68],
              [[[1, 4, 5, 6, 9], [7, 8, 10]], [[1, 4, 5], [2, 3, 6], [7, 8, 10]], [[5, 6, 7, 9, 10, 11]],
               [[2, 3, 6], [5, 7, 10, 11]]],
              [[2, 1, :city], [2, 2, :city], [2, 3, :city], [10, 4, [195, 2]], [10, 5, [195, 2]], [6, 6, [197, 3]],
               [1, 7, [197, 5]], [1, 8, [196, 1]]],
              [[2, 11, 67], [6, 18, 68], [1, 33, 68]],
              [[7, 36]],
              { 1 => { 7 => [56..63], 8 => [56..70], 9 => [56..70], 10 => [56..70], 11 => [56..59, 67..70],
                       12 => [56..59, 67..70], 13 => [56..59, 67..70], 14 => [36..36, 39..47, 56..59, 67..70],
                       15 => [36..59, 67..76], 16 => [36..59, 67..76], 17 => [36..59, 67..76] },
                2 => { 15 => [8..25], 16 => [8..25], 17 => [8..27], 18 => [8..11], 19 => [8..11], 20 => [8..11],
                       21 => [8..11], 22 => [8..11], 23 => [8..11], 24 => [8..11], 25 => [8..11], 26 => [8..11],
                       27 => [8..11], 28 => [9..11], 29 => [9..11], 30 => [9..11], 31 => [9..11], 32 => [9..11],
                       33 => [9..11], 34 => [9..11], 35 => [3..4, 9..11], 36 => [3..4, 9..11], 37 => [3..11],
                       38 => [4..11], 39 => [5..11] },
                3 => { 18 => [20..21], 19 => [20..21], 20 => [20..21] },
                4 => { 18 => [56..57], 19 => [56..57] },
                5 => { 20 => [40..49, 53..57], 21 => [40..57], 22 => [40..57], 23 => [40..57], 24 => [40..57],
                       25 => [40..43], 26 => [40..43], 27 => [40..43], 28 => [40..43], 29 => [40..43], 30 => [40..43],
                       31 => [40..43], 32 => [40..43], 33 => [40..43], 34 => [40..43], 35 => [40..43], 36 => [40..43],
                       37 => [40..43], 38 => [40..43], 39 => [40..43] },
                6 => { 21 => [14..36], 22 => [14..36], 23 => [14..36], 24 => [14..36], 25 => [14..36], 26 => [14..16],
                       27 => [14..16], 28 => [14..16], 29 => [14..16], 30 => [14..16, 28..33], 31 => [14..16, 28..36],
                       32 => [14..16, 25..36], 33 => [14..16, 33..36], 34 => [14..16, 33..36], 35 => [14..16, 33..36],
                       36 => [14..16, 33..36], 37 => [14..36], 38 => [14..36], 39 => [14..36] },
                7 => { 25 => [55..57], 26 => [55..57], 27 => [56..59, 67..67], 28 => [56..67], 29 => [56..67] },
                8 => { 30 => [61..62], 31 => [61..62], 32 => [61..62] },
                9 => { 33 => [37..39], 34 => [37..39] },
                10 => { 33 => [56..67], 34 => [56..67], 35 => [56..67], 36 => [55..67, 75..76], 37 => [55..67, 75..76],
                        38 => [55..76], 39 => [55..75] },
                11 => { 38 => [44..54], 39 => [44..54] } }],
      195 => [[],
              [[]],
              [[2, 2, [193, 10]], [2, 3, [193, 10]], [11, 4, [196, 23]], [11, 5, [196, 23]]],
              [],
              [[2, 24], [11, 25], [11, 26], [2, 27], [11, 28]],
              { 2 => { 7 => [7..10, 12..17, 19..19, 27..29, 31..31], 8 => [6..23, 27..29, 31..31, 33..33],
                       9 => [8..24, 27..33], 10 => [14..24, 27..33], 11 => [14..32], 12 => [14..33],
                       13 => [14..16, 18..24, 27..32], 14 => [14..16, 18..24, 27..31] },
                11 => { 39 => [17..17, 22..26, 31..31, 33..35, 40..40], 40 => [17..17, 22..41], 41 => [16..41],
                        42 => [17..32], 43 => [17..19, 22..32], 44 => [16..19, 22..32], 45 => [17..19, 22..31],
                        46 => [17..19, 22..31], 47 => [22..32], 48 => [22..31], 49 => [16..31], 50 => [17..32],
                        51 => [17..32], 52 => [17..22, 29..31], 53 => [17..20] } }],
      196 => [[69, 70, 72],
              [[[22, 23, 27, 28]], [[1, 2], [22, 23, 27, 28]], [[1, 5, 7], [22, 27, 28]], [[1, 2, 5, 7], [22, 27, 28]],
               [[5, 9, 18, 22, 23]], [[1, 2], [5, 9, 18, 22, 23]], [[1, 5, 7, 9, 18, 22]], [[1, 2, 5, 7, 9, 18, 22]]],
              [[2, 2, [197, 10]], [9, 3, [197, 15]], [23, 4, [195, 11]], [23, 5, [195, 11]], [23, 6, [195, 11]],
               [1, 7, [193, 1]]],
              [[5, 15, 70], [5, 16, 72], [22, 21, 72]],
              [],
              { 1 => { 6 => [4..27], 7 => [4..27], 8 => [4..27], 9 => [24..27], 10 => [24..28, 39..43],
                       11 => [24..28, 39..43], 12 => [24..28, 39..43], 13 => [24..28, 39..43], 14 => [24..43],
                       15 => [24..43], 16 => [24..34, 38..43] },
                2 => { 6 => [39..43], 7 => [39..43], 8 => [39..43], 9 => [39..43] },
                5 => { 17 => [11..20], 18 => [11..20], 19 => [4..20], 20 => [4..43], 21 => [4..43], 22 => [13..43],
                       23 => [13..23], 24 => [21..23], 25 => [21..23], 26 => [21..23], 27 => [21..23], 28 => [21..23],
                       29 => [14..14, 21..23], 30 => [4..23], 31 => [4..23], 32 => [4..23], 33 => [21..23],
                       34 => [21..23], 35 => [21..23], 36 => [20..23], 37 => [19..23, 32..36], 38 => [18..23, 32..35],
                       39 => [8..29, 32..42], 40 => [4..42], 41 => [4..34, 38..42], 42 => [11..15, 38..42],
                       43 => [11..15] },
                7 => { 17 => [31..32], 18 => [31..32], 19 => [31..32] },
                9 => { 30 => [33..35], 31 => [33..36], 32 => [33..36], 33 => [33..36], 34 => [33..36], 35 => [33..36],
                       36 => [32..36] },
                18 => { 42 => [32..33], 43 => [32..33], 44 => [32..33], 45 => [32..33] },
                22 => { 46 => [16..37], 47 => [16..42], 48 => [11..42], 49 => [11..42], 50 => [11..14], 51 => [9..14],
                        52 => [9..14], 53 => [9..14], 54 => [11..14], 55 => [11..14], 56 => [11..39], 57 => [11..42],
                        58 => [11..42], 59 => [12..14, 39..42], 60 => [12..14, 39..41], 61 => [12..14, 39..41],
                        62 => [12..14, 39..41], 63 => [12..14, 39..41], 64 => [12..14, 39..41], 65 => [12..14, 39..41],
                        66 => [12..14, 39..42], 67 => [12..14, 39..42], 68 => [11..14, 39..42], 69 => [11..14, 39..42],
                        70 => [11..14, 39..42], 71 => [11..14, 39..42], 72 => [8..14, 41..42], 73 => [9..14, 41..42],
                        74 => [9..14, 39..41], 75 => [10..14, 39..39] },
                23 => { 49 => [3..3], 50 => [3..4, 6..6], 51 => [3..8], 52 => [4..8], 53 => [5..8] },
                27 => { 63 => [20..32], 64 => [19..19, 21..34], 65 => [19..34], 66 => [19..27], 67 => [19..27],
                        68 => [19..27], 69 => [19..34], 70 => [19..34], 71 => [19..27], 72 => [19..27],
                        73 => [19..21, 27..27], 74 => [19..19, 21..21], 75 => [19..20] },
                28 => { 69 => [35..38], 70 => [35..38] } }],
      197 => [[67, 69],
              [[], [[1, 2, 3]], [[5, 6, 7]], [[1, 2, 3], [5, 6, 7]]],
              [[3, 1, [193, 6]], [5, 2, [193, 1]], [10, 3, [196, 2]], [15, 4, [196, 9]]],
              [[3, 5, 67], [5, 11, 69], [10, 17, 70]],
              [[3, 16], [5, 18], [10, 19]],
              { 1 => { 4 => [5..12], 5 => [5..14], 6 => [5..14] },
                2 => { 7 => [13..14], 8 => [13..14], 9 => [13..14] },
                3 => { 10 => [11..17, 20..22], 11 => [11..20], 12 => [4..6, 11..20], 13 => [4..18],
                       14 => [4..6, 11..18], 15 => [4..6, 11..18], 16 => [6..6, 11..16] },
                5 => { 27 => [4..14, 26..27, 32..33], 28 => [4..14, 24..33], 29 => [4..14, 21..33], 30 => [4..33],
                       31 => [4..4, 8..29, 33..33] },
                6 => { 32 => [8..9], 33 => [8..9], 34 => [8..9] },
                7 => { 35 => [4..9] },
                10 => { 47 => [16..21, 26..28], 48 => [6..22, 24..28], 49 => [6..27], 50 => [6..27], 51 => [6..27],
                        52 => [6..8, 24..27], 53 => [6..8, 26..27], 54 => [6..8, 26..27], 55 => [5..8, 25..27],
                        56 => [6..8, 25..27], 57 => [5..8, 25..27], 58 => [5..8, 25..28], 59 => [5..8, 25..28],
                        60 => [5..8, 25..28] },
                15 => { 72 => [19..30], 73 => [18..18, 20..30], 74 => [3..30], 75 => [3..3, 7..30], 76 => [26..30],
                        77 => [26..30], 78 => [26..30], 79 => [26..30], 80 => [8..8, 11..12, 17..31], 81 => [8..31],
                        82 => [8..31], 83 => [8..15, 27..32], 84 => [8..15, 27..27, 31..32], 85 => [8..13],
                        86 => [8..13], 87 => [8..13], 88 => [8..13], 89 => [8..13] } }]
    }
    GOAL = [197, 15, 27]
    CITY = [193, 2]
    GANG_DONE = 10

    # The bit of switch sw in a state of all five.
    def self.bit(sw)
      1 << PAIRS.index { |s, _odd| s == sw }
    end

    # The five switches as they stand, one bit each.
    def self.mask
      k = 0
      PAIRS.each { |sw, _odd| k |= bit(sw) if $game_switches[sw] }
      k
    end

    # The region of map holding (x, y), or beside it for the tile of an open gate; nil off every known one.
    def self.region_at(map, x, y)
      rooms = ROOMS[map]
      return nil unless rooms
      [[x, y], [x, y - 1], [x, y + 1], [x - 1, y], [x + 1, y]].each do |tx, ty|
        found = rooms[5].find { |_r, rows| (rows[ty] || []).any? { |span| span.include?(tx) } }
        return found[0] if found
      end
      nil
    end

    # The regions joined to region in map under the switches of mask.
    def self.comp(map, region, mask)
      k = 0
      ROOMS[map][0].each_with_index { |sw, i| k |= 1 << i if mask & bit(sw) != 0 }
      (ROOMS[map][1][k] || []).find { |g| g.include?(region) } || [region]
    end

    # What ends the search in a group of regions: a gang member still standing there, then the showdown.
    def self.goal(map, group)
      if $game_variables[105].to_i < GANG_DONE
        t = ROOMS[map][4].find { |r, ev| group.include?(r) && !$game_self_switches[[map, ev, "A"]] }
        t ? [:thug, map, t[1]] : nil
      else
        map == GOAL[0] && group.include?(GOAL[1]) ? [:goal, map, GOAL[2]] : nil
      end
    end

    # The presses and doors open from a group of regions, each with the place it leads to.
    def self.moves(map, group, mask)
      out = []
      ROOMS[map][3].each do |r, ev, sw|
        next unless group.include?(r)
        k = mask ^ bit(sw)
        out.push([[:press, map, ev, sw], [map, comp(map, r, k), k]])
      end
      ROOMS[map][2].each do |r, ev, to|
        next unless group.include?(r)
        place = to == :city ? [CITY[0], comp(CITY[0], CITY[1], 0), 0] : [to[0], comp(to[0], to[1], mask), mask]
        out.push([[:door, map, ev], place])
      end
      out
    end

    # The first step from a region toward the next gang member, then the showdown, fewest steps first, or nil.
    def self.plan(map, region, mask)
      start = [map, comp(map, region, mask), mask]
      seen = { start => true }
      queue = [[start, nil]]
      until queue.empty?
        node, first = queue.shift
        found = goal(node[0], node[1])
        return(first || found) if found
        moves(node[0], node[1], node[2]).each do |step, place|
          next if seen[place]
          seen[place] = true
          queue.push([place, first || step])
        end
      end
      nil
    end

    # The step from where the player stands, kept until they change region or a switch or the gang count moves.
    def self.step
      map = $game_map.map_id
      region = region_at(map, $game_player.x, $game_player.y)
      return nil unless region
      key = [map, region, mask, $game_variables[105].to_i]
      @step = [key, plan(map, region, mask)] unless @step && @step[0] == key
      @step[1]
    end

    # True when the assist's step is the event id of this map.
    def self.right_event?(id)
      s = step
      s && s[1] == $game_map.map_id && s[2] == id ? true : false
    end

    # The assist's hint for the step from here.
    def self.hint
      s = step
      return :ss1_sewers_step_lost unless s
      case s[0]
      when :press
        odd = PAIRS.find { |sw, _odd| sw == s[3] }[1]
        [:ss1_sewers_step_press, { :a => odd, :b => odd + 1 }]
      when :door then :ss1_sewers_step_door
      when :thug then :ss1_sewers_step_thug
      else :ss1_sewers_step_goal
      end
    end

    # The events the assist may point at, on any of the maps.
    def self.step_events
      ids = [GOAL[2]]
      MAPS.each do |m|
        r = ROOMS[m]
        ids.concat(r[2].map { |d| d[1] }).concat(r[3].map { |p| p[1] }).concat(r[4].map { |t| t[1] })
      end
      ids.uniq
    end

    # The sector of each pair whose gates are lowered now, in order.
    def self.lowered
      PAIRS.map { |sw, odd| $game_switches[sw] ? odd : odd + 1 }
    end

    # The info key's line: the sectors whose gates are lowered.
    def self.info
      PokeAccess::I18n.t(:ss1_sewers_lowered, :list => PokeAccess::Routes::Text.and_list(lowered.map { |n| n.to_s }))
    end

    # The name of a panel: the pair of sectors it flips, or nil for no panel.
    def self.panel_label(ev)
      sw = (PANELS[$game_map.map_id] || {})[ev.id]
      pair = sw && PAIRS.find { |s, _o| s == sw }
      pair ? [:ss1_sewers_panel, { :a => pair[1], :b => pair[1] + 1 }] : nil
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  sewers = PokeAccess::SoulstonesSewers

  mechanic(:state, sewers::MAPS) do
    auto
    sewers::PAIRS.each { |sw, _odd| watch :switch => sw, :quiet => true }
    controls
    obstacle({ :named => /\ASwitch Gate\z/ }, :label => :ss1_sewers_gate)
    name(/\AControl Panel \d\z/, lambda { |ev| sewers.panel_label(ev) })
    count :ss1_sewers_gang, :value => lambda { [[$game_variables[105].to_i - 1, 0].max, 9].min }, :of => 9,
                           :assist => true, :hide_zero => true
    sewers.step_events.each do |id|
      spot(:event => id, :label => :puzzle_right_way, :assist => true, :when => lambda { sewers.right_event?(id) })
    end
    arrival_hint :ss1_sewers_rule, :once => true
    info { sewers.info }
    hint lambda { sewers.hint }
    solved { $game_variables[100].to_i >= 9 }
  end
end
