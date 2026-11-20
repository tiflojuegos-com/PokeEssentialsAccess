# The Daruma rooms: the four of the Route 17 lab's second basement (maps 318, 320, 321 and 322) and Pueblo Garnet's
# challenge room (map 386). The Darmanitan (events named "daruma") are pushed onto the tiles of light, terrain 43, where
# darumacomp counts them; once all are on one, the room's switch is set. M resets the room and N pulls one back. The
# routes already push them; this lists the free tiles of light and counts the Darmanitan on one, and the assist gives the
# next push of a plan found by search, as long as the Darmanitan stand where the plan has them.
module PokeAccess
  module RealideaDaruma
    GOAL_TAG = 43
    ROOMS = {
      318 => [444, [[3, 19], [3, 20], [4, 19], [4, 20], [5, 19], [5, 20]]],
      320 => [443, [[4, 8], [4, 9], [4, 10], [4, 11], [4, 12], [4, 13], [11, 8], [11, 9], [11, 10], [11, 11], [11, 12],
                    [11, 13]]],
      321 => [446, [[11, 17], [11, 19], [11, 21], [12, 16], [13, 19], [14, 15], [16, 22]]],
      322 => [445, [[19, 11], [19, 13], [20, 14], [21, 11], [22, 12], [22, 14]]],
      386 => [500, [[14, 19], [15, 14], [15, 15], [15, 16], [15, 17], [15, 18], [15, 19], [16, 17], [17, 17]]]
    }

    # A way through each room found by search from its Darmanitan as the room starts and the player at its entry, the
    # player staying put on each push and the Darmanitan moved by the strict passability, as pbPushThisEvent moves
    # them: runs of [x, y, way, pushes].
    PLANS = {
      318 => [[6, 17, 2, 1], [8, 17, 2, 1], [7, 20, 4, 2], [5, 17, 4, 1], [5, 18, 2, 1], [5, 20, 4, 2], [5, 19, 2, 1],
              [6, 18, 4, 1], [5, 18, 2, 1], [8, 18, 4, 2], [5, 20, 4, 1], [5, 19, 2, 1], [4, 17, 6, 1], [4, 18, 2, 1],
              [6, 18, 6, 1], [7, 18, 4, 4], [3, 18, 2, 1], [5, 17, 6, 1], [6, 17, 2, 1], [6, 18, 4, 1], [5, 18, 2, 1]],
      320 => [[10, 13, 6, 1], [5, 13, 4, 1], [11, 13, 8, 5], [10, 11, 2, 1], [5, 11, 4, 1], [10, 12, 2, 1], [10, 13, 6, 1],
              [11, 13, 8, 4], [10, 9, 2, 2], [10, 11, 6, 1], [11, 11, 2, 2], [9, 12, 2, 1], [9, 10, 2, 1], [9, 11, 6, 2],
              [11, 13, 8, 1], [9, 13, 8, 2], [9, 11, 6, 1], [10, 11, 2, 2], [10, 13, 6, 1], [9, 8, 2, 3], [9, 11, 6, 1],
              [10, 11, 2, 2], [6, 12, 2, 1], [5, 9, 2, 1], [10, 13, 8, 3], [10, 10, 6, 1], [6, 13, 8, 2], [5, 10, 8, 1],
              [6, 11, 4, 1], [5, 11, 2, 1], [5, 12, 4, 1], [5, 9, 2, 1], [6, 10, 2, 1], [6, 11, 4, 1], [5, 10, 4, 1],
              [6, 8, 2, 5], [6, 13, 8, 2], [5, 11, 8, 2], [6, 11, 4, 1], [5, 9, 4, 1], [5, 11, 8, 3], [5, 8, 4, 1]],
      321 => [[15, 18, 2, 1], [15, 19, 4, 5], [12, 20, 8, 1], [11, 18, 8, 1], [10, 19, 6, 1], [10, 16, 6, 2],
              [12, 15, 6, 2], [11, 19, 2, 1], [12, 19, 6, 1], [11, 20, 8, 1], [13, 19, 6, 3], [16, 19, 2, 3],
              [11, 19, 4, 1], [10, 19, 6, 1], [11, 19, 2, 2], [14, 18, 2, 1], [14, 19, 4, 4], [10, 19, 6, 3],
              [10, 17, 2, 2], [10, 19, 6, 1]],
      322 => [[21, 14, 6, 1], [19, 14, 6, 1], [22, 11, 2, 1], [20, 11, 4, 1], [19, 11, 6, 1], [19, 12, 2, 1],
              [20, 11, 4, 1], [22, 12, 4, 1], [21, 12, 8, 1], [22, 14, 4, 1], [22, 13, 8, 1], [21, 14, 8, 2],
              [22, 12, 8, 1], [22, 11, 2, 3], [21, 12, 6, 1]],
      386 => [[14, 14, 6, 1], [13, 16, 2, 1], [14, 16, 6, 1], [13, 17, 6, 2], [14, 18, 2, 1], [14, 15, 2, 1],
              [16, 16, 2, 1], [16, 19, 4, 1], [16, 18, 6, 1], [17, 18, 8, 1], [13, 18, 6, 2], [14, 16, 8, 1],
              [14, 15, 6, 1]]
    }
    # The tiles the Darmanitan stand on as each room is entered, where the plans start.
    STARTS = {
      318 => [[4, 18], [5, 17], [5, 18], [6, 17], [7, 20], [8, 17]],
      320 => [[5, 9], [5, 11], [5, 13], [6, 8], [6, 10], [6, 12], [9, 8], [9, 10], [9, 12], [10, 9], [10, 11], [10, 13]],
      321 => [[10, 16], [10, 17], [11, 18], [12, 15], [12, 20], [14, 18], [15, 18]],
      322 => [[19, 12], [19, 14], [20, 11], [21, 14], [22, 11], [22, 13]],
      386 => [[13, 16], [13, 18], [14, 14], [14, 15], [14, 16], [14, 18], [16, 16], [16, 18], [16, 19]]
    }
    STEP = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    FACES = { 2 => :face_south, 4 => :face_west, 6 => :face_east, 8 => :face_north }

    # The room's Darmanitan.
    def self.darumas
      $game_map.events.values.select { |ev| ev.name == "daruma" }
    end

    # The plan of a room push by push, from the Darmanitan where they stand now: [[x, y, way, pushes left in its run,
    # tiles before the push], ...].
    def self.pushes(map, start)
      tiles = start.sort
      out = []
      (PLANS[map] || []).each do |x, y, way, n|
        dx, dy = STEP[way]
        n.times do |i|
          bx = x + dx * i
          by = y + dy * i
          out.push([bx, by, way, n - i, tiles])
          tiles = tiles.reject { |t| t == [bx, by] }.push([bx + dx, by + dy]).sort
        end
      end
      out
    end

    # What the puzzle assist says: the next push of the plan from the tiles the Darmanitan stand on now, or to reset
    # the room once they stand off the plan.
    def self.next_push
      map = $game_map.map_id
      start = STARTS[map]
      return nil unless start
      now = darumas.map { |ev| [ev.x, ev.y] }.sort
      step = pushes(map, start).find { |p| p[4] == now }
      return :rea_daruma_off_plan unless step
      where = PokeAccess::Puzzles.offset_phrase(step[0] - $game_player.x, step[1] - $game_player.y)
      [:rea_daruma_push, { :where => where, :dir => PokeAccess::I18n.t(FACES[step[2]]), :n => step[3] }]
    end

    # How many Darmanitan stand on a tile of light.
    def self.connected
      darumas.select { |ev| $game_map.terrain_tag(ev.x, ev.y) == GOAL_TAG }.size
    end

    # True while a Darmanitan stands on the tile.
    def self.taken?(x, y)
      darumas.any? { |ev| ev.x == x && ev.y == y }
    end
  end
end

PokeAccess::Game.define("realidea") do
  daruma = PokeAccess::RealideaDaruma
  daruma::ROOMS.each do |map, (done, goals)|
    mechanic(:state, map) do
      auto
      goals.each do |x, y|
        spot :at => [x, y], :label => :rea_daruma_goal, :onto => true, :when => lambda { !daruma.taken?(x, y) }
      end
      count :rea_daruma_lit, :value => lambda { daruma.connected }, :of => goals.size
      solved(nil) { $game_switches[done] }
      hint lambda { daruma.next_push }
    end
  end
end
