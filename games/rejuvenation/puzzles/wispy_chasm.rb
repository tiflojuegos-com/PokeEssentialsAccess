# Wispy Chasm's four Shuppet (map 12, events 3, 17, 43, 59): unseen tiles beside each make it jump two tiles away as the
# player steps on them; one driven to the end of a dead end and stepped at once more flies off, adding one to variable
# 525 and setting its switch (1039 to 1042). With all four, the tiles before the barrier take 525 to 5 and lift it.
module PokeAccess
  module RejuvChasm
    # Shuppet event => [its number, its switch, the tile to step on next by its tile, then by its tile [[boxes [x0, y0,
    # x1, y1]], the tile] while the player stands in one].
    SHUPPETS = {
      3 => [1, 1039, {
        [19, 59] => [18, 57], [16, 61] => [16, 63], [18, 61] => [18, 59], [20, 61] => [18, 61],
        [22, 61] => [20, 61], [16, 63] => [16, 61], [18, 63] => [18, 61]
      }, {
        [18, 61] => [[[14, 63, 21, 69]], [16, 61]],
        [18, 63] => [[[16, 61, 17, 61]], [16, 63]]
      }],
      17 => [2, 1040, {
        [29, 36] => [30, 37], [28, 35] => [30, 35], [26, 35] => [24, 35], [24, 35] => [26, 35],
        [24, 37] => [26, 37], [26, 37] => [24, 37], [24, 33] => [24, 35], [26, 33] => [26, 35],
        [28, 33] => [28, 35], [24, 31] => [24, 33], [26, 31] => [24, 31], [24, 29] => [24, 31],
        [26, 27] => [24, 29], [28, 31] => [26, 31], [30, 31] => [28, 31], [32, 31] => [30, 31],
        [35, 31] => [35, 29], [35, 29] => [37, 29], [35, 33] => [35, 31], [35, 35] => [35, 33],
        [35, 37] => [35, 35]
      }, {
        [24, 35] => [[[26, 37, 26, 37]], [24, 37]]
      }],
      43 => [3, 1041, {
        [7, 38] => [8, 37], [7, 40] => [8, 39], [8, 39] => [6, 39], [6, 39] => [6, 41],
        [10, 39] => [8, 39], [9, 40] => [8, 39], [6, 41] => [7, 42], [8, 41] => [6, 41],
        [10, 41] => [8, 41], [12, 41] => [10, 41], [7, 42] => [6, 43], [6, 43] => [6, 41],
        [8, 43] => [6, 43], [10, 43] => [8, 43], [13, 37] => [13, 38]
      }, {}],
      59 => [4, 1042, {
        [54, 45] => [54, 48], [54, 46] => [54, 48], [54, 48] => [54, 46], [52, 46] => [54, 46],
        [50, 46] => [52, 46], [49, 46] => [47, 46], [47, 46] => [49, 46], [46, 48] => [46, 50],
        [46, 50] => [46, 48], [46, 51] => [46, 53], [46, 53] => [46, 51], [46, 54] => [46, 53],
        [48, 53] => [46, 53], [48, 54] => [46, 54], [50, 53] => [48, 53], [50, 54] => [50, 55],
        [52, 54] => [54, 54], [54, 54] => [54, 52], [54, 52] => [54, 50], [54, 50] => [54, 48],
        [50, 51] => [50, 53], [50, 49] => [50, 51]
      }, {
        [50, 54] => [[[46, 46, 46, 51], [46, 46, 54, 46], [50, 37, 54, 41], [52, 42, 52, 45], [54, 46, 54, 54]], [52, 54]]
      }]
    }

    def self.caught?(id)
      $game_switches[SHUPPETS[id][1]] ? true : false
    end

    # True until the barrier lifts.
    def self.live?
      $game_variables[525].to_i < 5
    end

    # The tile to step on next to drive Shuppet id on, or nil once it is caught or off the plan.
    def self.next_tile(id)
      return nil if caught?(id)
      ev = $game_map.events[id]
      return nil unless ev
      at = [ev.x, ev.y]
      boxes, tile = SHUPPETS[id][3][at]
      px = $game_player.x
      py = $game_player.y
      return tile if boxes && boxes.any? { |x0, y0, x1, y1| px >= x0 && px <= x1 && py >= y0 && py <= y1 }
      SHUPPETS[id][2][at]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  chasm = PokeAccess::RejuvChasm
  mechanic(:state, 12, :part => :shuppet) do
    auto
    arrival_hint lambda { $game_variables[525].to_i < 4 ? :rj_chasm_rule : nil }
    count :rj_chasm_caught, :switches => [1039, 1040, 1041, 1042], :assist => true
    chasm::SHUPPETS.each do |id, (n, _sw, _next, _areas)|
      spot :at => lambda { chasm.next_tile(id) }, :label => [:rj_chasm_step, { :n => n }], :onto => true,
           :assist => true, :when => lambda { chasm.live? }
    end
    hint :rj_chasm_hint
    active { PokeAccess::Puzzles.assist? && chasm.live? }
    solved { !chasm.live? }
  end
end
