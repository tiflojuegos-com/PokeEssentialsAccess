# Rocket HQ of Five Island: the cell the player wakes in (map 199), where a toilet, the bed, the sink and the sleeping
# guard open the way one after another (switches 81 to 83); the Rattata chase of the cave behind the cell's wall (map
# 328), where twenty invisible floor tiles each send the rat to another corner of a grid of corridors (variable 58,
# its last corner in 59) until two rockfalls (switches 139 and 140) let it be cornered and caught; and the warp tiles of
# the base (maps 234, 235 and 99), whose way on is the tile beside the entrance.
module PokeAccess
  module SeviiRocketHq
    PRISON = 199
    CHASE = 328
    BASE = 234
    # The rat's corner for each value of variable 58: 1 to 3 the top row, 4 to 6 the middle one, 7 and 8 the bottom one;
    # 10 cornered, 11 caught.
    RAT_WORDS = { 1 => :sevii_rat_top_left, 2 => :sevii_rat_top, 3 => :sevii_rat_top_right, 4 => :sevii_rat_left,
                  5 => :sevii_rat_middle, 6 => :sevii_rat_right, 7 => :sevii_rat_bottom_left, 8 => :sevii_rat_bottom,
                  10 => :sevii_rat_cornered, 11 => :sevii_rat_caught }
    # The chase's floor tiles: events 5 and 7 to 25.
    TILES = [5] + (7..25).to_a
    # The tile to step on next by [rat's corner, its last corner, switch 139, switch 140]: the one that corners the rat
    # in the fewest steps whatever its random turns pick, walkable from every tile that leads to that state, with the
    # rockfall at the left corner of the middle row closing it (simulated against the tile events,
    # auditoria/puzzles-2026-11/_pulido/sim/sevii/chase_sim.rb). From the start it takes ten tiles when EV23, with
    # switch 140 on, sends the rat to the top middle; its jump to a label the page lacks runs on, so the rat may go to
    # the bottom middle instead, and the table goes on from there.
    NEXT_TILE = {
      [1, 1, false, false] => 5, [1, 2, false, false] => 5, [1, 2, true, false] => 10, [1, 2, true, true] => 10,
      [1, 4, false, false] => 5, [1, 4, true, false] => 10,
      [2, 1, false, false] => 20, [2, 1, true, false] => 14, [2, 1, true, true] => 14, [2, 3, false, false] => 14,
      [2, 3, true, false] => 20, [2, 3, true, true] => 20, [2, 5, false, false] => 14, [2, 5, true, false] => 15,
      [2, 5, true, true] => 15,
      [3, 2, false, false] => 12, [3, 2, true, false] => 13, [3, 2, true, true] => 13, [3, 6, true, false] => 13,
      [3, 6, true, true] => 13,
      [4, 1, false, false] => 21, [4, 5, false, false] => 16, [4, 5, true, false] => 19, [4, 7, false, false] => 16,
      [5, 1, true, true] => 23, [5, 2, false, false] => 17, [5, 2, true, false] => 23, [5, 2, true, true] => 23,
      [5, 4, false, false] => 17, [5, 6, false, false] => 17, [5, 6, true, false] => 18, [5, 6, true, true] => 23,
      [5, 7, true, true] => 22, [5, 8, false, false] => 17, [5, 8, true, false] => 22, [5, 8, true, true] => 22,
      [6, 3, false, false] => 25, [6, 3, true, false] => 25, [6, 3, true, true] => 24, [6, 5, true, false] => 25,
      [6, 5, true, true] => 24, [6, 8, true, false] => 25,
      [7, 4, false, false] => 9, [7, 4, true, false] => 11, [7, 8, true, false] => 11, [7, 8, true, true] => 11,
      [8, 5, true, false] => 7, [8, 5, true, true] => 7, [8, 7, false, false] => 7, [8, 7, true, false] => 8,
      [8, 7, true, true] => 8
    }

    # The chase as NEXT_TILE reads it.
    def self.chase_state
      [$game_variables[58].to_i, $game_variables[59].to_i, $game_switches[139] ? true : false,
       $game_switches[140] ? true : false]
    end

    # The tile event to step on next, or nil once the rat is cornered or out of the table.
    def self.next_tile
      NEXT_TILE[chase_state]
    end

    # The assisted line of the chase: talk to the rat once cornered, else step on the listed tile.
    def self.chase_hint
      v = $game_variables[58].to_i
      return :sevii_chase_catch_hint if v == 10
      return nil if v >= 11
      next_tile ? :sevii_chase_tile_hint : :sevii_chase_free_hint
    end

    # True while the guard's own switch A is off: he has not been searched yet.
    def self.guard_unsearched?
      !$game_self_switches[[PRISON, 5, "A"]]
    end
  end
end

PokeAccess::Game.define("sevii") do
  hq = PokeAccess::SeviiRocketHq

  mechanic(:state, hq::PRISON, :part => :cell) do
    auto
    name 13, :sevii_cell_toilet
    name 14, :sevii_cell_bed
    name 12, :sevii_cell_sink
    name 47, :sevii_cell_crack
    name 5, lambda { |_ev| $game_switches[82] ? :sevii_cell_guard_asleep : nil }
    hide [21, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33], :assist => true
    phase(lambda { !$game_switches[81] }, :quiet => true, :hint => :sevii_cell_flush_hint)
    phase(lambda { $game_switches[81] && !$game_switches[82] }, :quiet => true, :hint => :sevii_cell_nap_hint)
    phase(lambda { $game_switches[82] && !$game_switches[83] }, :quiet => true, :hint => :sevii_cell_sink_hint)
    phase(lambda { $game_switches[83] && hq.guard_unsearched? }, :quiet => true, :hint => :sevii_cell_guard_hint)
    phase(lambda { $game_switches[83] && !$game_switches[84] }, :quiet => true, :hint => :sevii_cell_crack_hint)
    solved(nil, :quiet => true) { $game_switches[84] }
  end

  mechanic(:state, hq::CHASE) do
    auto
    watch :var => 58, :label => :sevii_rat, :words => hq::RAT_WORDS
    hq::TILES.each do |tile|
      spot :event => tile, :label => :sevii_chase_tile, :assist => true, :onto => true,
           :when => lambda { hq.next_tile == tile }
    end
    avoid hq::TILES, :assist => true
    arrival_hint :sevii_chase_rule, :once => true
    hint lambda { hq.chase_hint }
    solved(nil, :quiet => true) { $game_variables[58].to_i >= 11 }
  end

  mechanic(:state, hq::BASE, :part => :way_on) do
    auto
    spot :event => 3, :label => :sevii_hq_way_on, :assist => true, :onto => true
    hint :sevii_hq_way_hint
    solved(nil, :quiet => true) { $game_switches[120] }
  end
end
