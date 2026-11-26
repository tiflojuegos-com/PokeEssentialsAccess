# Fiore Gym, Amaria's underwater maze: map 678 is the surface, with seventeen pools whose dive map is 681, a small room
# under each; their edge passages (touch events asking a facing) lead into the tunnels of maps 680 and 683 or to 682,
# under the arena (679). Variable 381 keeps the story (14 to 20; switch 878 for the Reshiram way). The plan is data.
module PokeAccess
  module RebornFiore
    MAPS = [678, 679, 680, 681, 682, 683]
    COLOURS = [680, 682, 683]
    AMARIA = { 683 => [38, 39, 40, 41], 680 => [44, 45] }
    PASS_KEYS = { 2 => :rbb_fiore_pass_s, 4 => :rbb_fiore_pass_w, 6 => :rbb_fiore_pass_e, 8 => :rbb_fiore_pass_n }
    STEP_KEYS = { 2 => :rbb_fiore_step_s, 4 => :rbb_fiore_step_w, 6 => :rbb_fiore_step_e, 8 => :rbb_fiore_step_n }
    REGIONS = {
      678 => [[0, 13, 15, 20, 32], [0, 16, 16, 21, 22], [0, 20, 22, 27, 32], [0, 16, 22, 28, 32], [0, 23, 26, 29, 32], [1, 15, 17, 36, 39], [1, 14, 18, 37, 40], [1, 19, 20, 39, 43], [1, 22, 24, 40, 44], [1, 21, 26, 41, 44], [2, 19, 37, 10, 26], [2, 18, 38, 11, 26], [2, 39, 39, 14, 14], [2, 29, 30, 27, 33], [2, 28, 31, 30, 33], [2, 27, 32, 31, 33], [3, 22, 24, 34, 37], [3, 21, 25, 35, 37], [4, 34, 37, 33, 37], [4, 33, 38, 34, 37], [4, 28, 38, 35, 38], [4, 27, 38, 36, 38], [4, 26, 32, 38, 39], [5, 28, 31, 42, 51], [5, 27, 32, 43, 51], [5, 33, 33, 45, 46], [6, 34, 37, 39, 45], [6, 33, 38, 40, 44], [6, 39, 39, 42, 42], [7, 36, 38, 28, 31], [7, 35, 39, 29, 32], [7, 34, 39, 30, 32], [7, 40, 40, 31, 33], [7, 41, 44, 32, 35], [7, 45, 45, 33, 33], [8, 44, 46, 18, 30], [8, 43, 46, 19, 30], [8, 42, 45, 26, 30], [8, 40, 46, 27, 30], [9, 40, 45, 37, 41]],
      679 => [[10, 16, 33, 14, 34]],
      680 => [[11, 10, 47, 8, 33], [12, 10, 38, 43, 90], [13, 11, 57, 100, 140], [14, 48, 70, 43, 55], [15, 49, 63, 65, 91], [16, 59, 89, 8, 48], [17, 70, 88, 100, 140]],
      681 => [[18, 11, 15, 17, 22], [19, 13, 18, 33, 39], [20, 18, 25, 8, 14], [21, 21, 25, 28, 31], [22, 21, 25, 33, 36], [23, 21, 25, 38, 45], [24, 27, 32, 28, 32], [25, 27, 32, 34, 39], [26, 28, 32, 41, 46], [27, 30, 38, 8, 14], [28, 34, 38, 26, 30], [29, 34, 38, 32, 36], [30, 34, 38, 38, 44], [31, 41, 47, 25, 29], [32, 41, 47, 31, 34], [33, 41, 47, 36, 41], [34, 43, 48, 17, 22]],
      682 => [[35, 12, 36, 9, 41]],
      683 => [[36, 10, 29, 9, 36], [37, 10, 65, 46, 91], [38, 10, 88, 100, 141], [39, 40, 66, 9, 36], [40, 77, 108, 40, 91]],
    }
    PONDS = [[21, 11], [33, 11], [45, 19], [14, 21], [43, 27], [37, 29], [23, 30], [29, 31], [43, 33], [36, 34], [23, 35], [29, 36], [16, 37], [43, 38], [35, 40], [23, 41], [29, 43]]
    STEPS = {
      :arena => {0 => [:dive, 6, 21], 1 => [:dive, 15, 23], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 9, 29], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 4, 31], 9 => [:dive, 13, 33], 11 => [:door, [9, 10, 12, 11], 36], 12 => [:door, [14], 19], 13 => [:door, [19, 20], 38], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [27, 28, 29, 30], 40], 17 => [:door, [22], 18], 18 => [:surface, nil, 0], 19 => [:surface, nil, 1], 20 => [:door, [6, 7], 35], 21 => [:door, [11, 12], 12], 22 => [:door, [13, 14], 37], 23 => [:door, [2], 11], 24 => [:surface, nil, 2], 25 => [:surface, nil, 4], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:door, [25, 24], 39], 30 => [:door, [3], 11], 31 => [:door, [17], 16], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [5, 6], 25], 37 => [:door, [10, 11, 12, 13], 12], 38 => [:door, [17, 18, 19, 20], 37], 39 => [:door, [33, 34, 35, 36], 14], 40 => [:door, [23, 24, 25, 26], 17]},
      :z1 => {0 => [:dive, 6, 21], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 2, 34], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [15, 16, 17, 18], 37], 13 => [:door, [19, 20], 38], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [31], 31], 17 => [:door, [22], 18], 18 => [:surface, nil, 0], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:door, [11, 12], 12], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:surface, nil, 8], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 38 => [:door, [17, 18, 19, 20], 37], 39 => [:door, [31, 32], 29], 40 => [:door, [23, 24, 25, 26], 17]},
      :z2 => {0 => [:dive, 6, 21], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 2, 34], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [15, 16, 17, 18], 37], 13 => [:door, [19, 20], 38], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [31], 31], 17 => [:door, [22], 18], 18 => [:surface, nil, 0], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:door, [11, 12], 12], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:surface, nil, 8], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [7, 14, 15, 16], 38], 39 => [:door, [31, 32], 29], 40 => [:door, [27, 28, 29, 30], 16]},
      :z3 => {0 => [:dive, 3, 18], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 2, 34], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [15, 16, 17, 18], 37], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [31], 31], 17 => [:door, [23, 24, 25, 26], 40], 18 => [:door, [16], 17], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:surface, nil, 0], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:surface, nil, 8], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [7, 14, 15, 16], 38], 38 => [:door, [21, 22], 13], 39 => [:door, [31, 32], 29], 40 => [:door, [27, 28, 29, 30], 16]},
      :r1 => {0 => [:dive, 3, 18], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 4, 31], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [13], 21], 13 => [:door, [21], 34], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [27, 28, 29, 30], 40], 17 => [:door, [23, 24, 25, 26], 40], 18 => [:door, [16], 17], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:surface, nil, 0], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:door, [17], 16], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:surface, nil, 8], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [10, 11, 12, 13], 12], 38 => [:door, [21, 22], 13], 39 => [:door, [31, 32], 29]},
      :r2 => {0 => [:dive, 3, 18], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 2, 34], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [15, 16, 17, 18], 37], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [31], 31], 17 => [:door, [23, 24, 25, 26], 40], 18 => [:door, [16], 17], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:surface, nil, 0], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:surface, nil, 8], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [7, 14, 15, 16], 38], 38 => [:door, [21, 22], 13], 39 => [:door, [31, 32], 29], 40 => [:door, [27, 28, 29, 30], 16]},
      :r3 => {0 => [:dive, 6, 21], 1 => [:dive, 12, 19], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:dive, 16, 26], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 2, 34], 9 => [:dive, 13, 33], 10 => [:door, [3], 5], 11 => [:door, [2, 3, 4], 23], 12 => [:door, [15, 16, 17, 18], 37], 13 => [:door, [19, 20], 38], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [31], 31], 17 => [:door, [22], 18], 18 => [:surface, nil, 0], 19 => [:door, [10], 12], 20 => [:door, [6, 7], 35], 21 => [:door, [11, 12], 12], 22 => [:door, [13, 14], 37], 23 => [:surface, nil, 1], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:door, [1], 11], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:surface, nil, 8], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [7, 14, 15, 16], 38], 39 => [:door, [31, 32], 29], 40 => [:door, [27, 28, 29, 30], 16]},
      :arena_warp => {0 => [:dive, 6, 21], 1 => [:dive, 15, 23], 2 => [:dive, 0, 20], 3 => [:dive, 10, 22], 4 => [:dive, 11, 25], 5 => [:door, [16], 10], 6 => [:dive, 14, 30], 7 => [:dive, 5, 28], 8 => [:dive, 4, 31], 9 => [:dive, 13, 33], 11 => [:door, [5, 6], 26], 12 => [:door, [14], 19], 13 => [:door, [19, 20], 38], 14 => [:door, [36, 37], 24], 15 => [:door, [34], 32], 16 => [:door, [27, 28, 29, 30], 40], 17 => [:door, [22], 18], 18 => [:surface, nil, 0], 19 => [:surface, nil, 1], 20 => [:door, [6, 7], 35], 21 => [:door, [11, 12], 12], 22 => [:door, [13, 14], 37], 23 => [:door, [2], 11], 24 => [:surface, nil, 2], 25 => [:door, [4, 5], 36], 26 => [:surface, nil, 5], 27 => [:door, [8, 9], 35], 28 => [:door, [18, 19], 16], 29 => [:surface, nil, 4], 30 => [:door, [3], 11], 31 => [:door, [17], 16], 32 => [:surface, nil, 7], 33 => [:door, [21], 15], 34 => [:door, [15], 13], 35 => [:surface, nil, 10], 36 => [:door, [1, 2, 3, 4], 11], 37 => [:door, [10, 11, 12, 13], 12], 38 => [:door, [17, 18, 19, 20], 37], 39 => [:door, [33, 34, 35, 36], 14], 40 => [:door, [23, 24, 25, 26], 17]},
    }
    PASSES = {
      680 => {[7, 8] => 8, [2, 3, 4] => 8, [5, 6] => 8, [32, 33] => 2, [31] => 4, [9, 10, 12, 11] => 2, [27, 28, 29, 30] => 2, [36, 37] => 2, [13] => 2, [38, 39, 40, 41] => 2, [14] => 6, [34] => 4, [35] => 4, [15, 16, 17, 18] => 2, [21] => 4, [22] => 6, [19, 20] => 2, [23, 24, 25, 26] => 2},
      681 => {[6, 7] => 8, [8, 9] => 8, [16] => 4, [15] => 6, [18, 19] => 8, [17] => 6, [11, 12] => 8, [22, 23] => 8, [25, 24] => 2, [20] => 6, [13, 14] => 2, [10] => 4, [4, 5] => 2, [21] => 6, [3] => 2, [2] => 2, [1] => 2},
      682 => {[1] => 2, [2] => 2},
      683 => {[5, 6] => 8, [33, 34, 35, 36] => 8, [1, 2, 3, 4] => 8, [31, 32] => 8, [27, 28, 29, 30] => 8, [8, 9] => 8, [10, 11, 12, 13] => 8, [23, 24, 25, 26] => 8, [7, 14, 15, 16] => 2, [21, 22] => 8, [17, 18, 19, 20] => 8},
    }

    # The gym's story variable.
    def self.story
      $game_variables[381].to_i
    end

    # The goal of the story's phase, or nil outside the maze's phases.
    def self.goal
      v = story
      r = $game_switches[878]
      return nil if v < 14 || v > 19 || (v == 18 && r)
      return :arena if v == 14 || v >= 18
      (r ? [:r1, :r2, :r3] : [:z1, :z2, :z3])[v - 15]
    end

    # The region the player stands in, by the first box of the map that holds them.
    def self.region
      x = $game_player.x
      y = $game_player.y
      b = (REGIONS[$game_map.map_id] || []).find { |q| x >= q[1] && x <= q[2] && y >= q[3] && y <= q[4] }
      b ? b[0] : nil
    end

    # The legs towards the goal, by region; the arena's way by the warp once switch 907 opens it.
    def self.table
      g = goal
      g ? STEPS[g == :arena && $game_switches[907] ? :arena_warp : g] : nil
    end

    # The next leg from the player's region, [kind, what, region it leads to], or nil.
    def self.step
      t = table
      t ? t[region] : nil
    end

    # The current map's passages, their events => the side they lead out of.
    def self.passes
      PASSES[$game_map.map_id] || {}
    end

    # True with the assist while the next leg is of this kind through this pond or passage.
    def self.right?(kind, what)
      s = PokeAccess::Puzzles.assist? ? step : nil
      !s.nil? && s[0] == kind && s[1] == what
    end

    # A passage's name by the side it leads out of; with the assist, marked when it is the next leg.
    def self.pass_label(ev)
      ids = passes.keys.find { |l| l.include?(ev.id) }
      return nil unless ids
      key = PASS_KEYS[passes[ids]]
      right?(:door, ids) ? [:rbb_fiore_right, { :name => PokeAccess::I18n.t(key) }] : key
    end

    # A pond's name by its number; with the assist, marked when diving there is the next leg.
    def self.pond_label(k)
      [right?(:dive, k) ? :rbb_fiore_pond_right : :rbb_fiore_pond, { :n => k + 1 }]
    end

    # How many of Amaria's three hiding places are behind, by the story.
    def self.found
      [[story - 15, 0].max, 3].min
    end

    # How many legs are left from here to the goal.
    def self.legs
      t = table
      r = region
      n = 0
      while t && t[r] && n < 40
        r = t[r][2]
        n += 1
      end
      n
    end

    # A leg in words: the pond to dive in, surfacing, or the side of the passage to take.
    def self.step_text(s)
      return PokeAccess::I18n.t(:rbb_fiore_step_dive, :n => s[1] + 1) if s[0] == :dive
      return PokeAccess::I18n.t(:rbb_fiore_step_surface) if s[0] == :surface
      d = passes[s[1]]
      PokeAccess::I18n.t(d ? STEP_KEYS[d] : :rbb_fiore_step_warp)
    end

    # With the assist, the next leg and how many are left, or who to talk to at the goal.
    def self.next_line
      return nil unless PokeAccess::Puzzles.assist? && goal && region
      s = step
      return [:rbb_fiore_next, { :step => step_text(s), :n => legs }] if s
      who = story == 14 && !$game_switches[878] ? :rbb_fiore_titania : :rbb_fiore_amaria
      [:rbb_fiore_talk, { :name => PokeAccess::I18n.t(who) }]
    end

    # The background cycling its colours (switch 910), as the screen shows it, while the player is on the right way.
    def self.colours_line
      return nil unless COLOURS.include?($game_map.map_id) && $game_switches[910]
      return nil if (($Settings.photosensitive rescue 0) || 0).to_i == 1
      PokeAccess::Puzzles.assist? ? :rbb_fiore_colours_right : :rbb_fiore_colours
    end
  end
end

PokeAccess::Game.define("reborn") do
  f = PokeAccess::RebornFiore
  f::MAPS.each do |mid|
    mechanic(:state, mid, :part => :fiore) do
      auto
      if mid == 678
        f::PONDS.each_with_index { |xy, k| spot :at => xy, :onto => true, :label => lambda { f.pond_label(k) } }
        name 16, lambda { |_ev| f.right?(:door, [16]) ? :rbb_fiore_warp_right : nil }, :assist => true
        arrival_hint :rbb_fiore_rule, :once => true
      elsif mid == 679
        name 3, lambda { |_ev| f.right?(:door, [3]) ? :rbb_fiore_warp_right : nil }, :assist => true
      else
        (f::PASSES[mid] || {}).each_key { |ids| name ids, lambda { |ev| f.pass_label(ev) }, :grouped => true }
        name f::AMARIA[mid], :rbb_fiore_amaria if f::AMARIA[mid]
        arrival_hint lambda { f.colours_line } if f::COLOURS.include?(mid)
      end
      count :rbb_fiore_found, :value => lambda { f.found }, :of => 3, :announce => false, :hide_zero => true
      [:arena, :z1, :z2, :z3, :r1, :r2, :r3].each do |g|
        phase lambda { f.goal == g }, :hint => lambda { f.next_line }
      end
      active { !f.goal.nil? }
      solved(nil, :quiet => true) { f.story >= 20 }
    end
  end
end
