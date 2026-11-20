# Team Aqua's hideout: warp panels within and between its two floors (maps 388 and 389), many of them leading back. WAYS
# holds, per floor, the panel that starts the shortest way to Matt (map 389, event 15) from each tile ('*' where he is
# walked to, '.' no tile), found by a search over both floors: following each tile's choice the distance only falls.
# With the assist the one of the tile the player stands on is listed as the right way and every other leaves the lists.
module PokeAccess
  module EmAquaHideout
    FIRST = 388
    SECOND = 389
    MATT = 264
    EXITS = { FIRST => [2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 25, 26, 27, 28, 29],
              SECOND => [1, 2, 3, 5, 6, 7, 8, 9, 10, 11] }
    WAYS = {
      388 => [[2, 3, 5, 7, 8, 10, 12, 13, 14, 15, 16, 17, 18, 19, 21, 25, 26, 27, 29],
        [".........................................................",
         "............s.....r..........c...........................",
         "...s....ssssss.rrrrrr......ccccc.........................",
         ".ssss..sssssss.rrrrrr......ccccc...........eee...........",
         ".sssssssssssss.rrrrrrqq...cccccca..........eee...........",
         ".sssssssssssss.rrrrrrrrrr.ccccccc........eeeeeee.........",
         ".ssss...ssssss...........................eeeeeeeeg.......",
         ".sssssssssssss...........................................",
         ".sssssss...sss...oooo.o...bbb............................",
         ".sssssssssssss..oo..o.ooo.bbb............................",
         ".sssssssssssss.ooo..o.ooo.bbbb..b........hhhiiifff.......",
         ".sssssssssssss.oooooooooo.bbbb..b........................",
         "..........................bbbbbbb........................",
         ".........................................................",
         ".pppppppppppppppppppppppp................kjjjnnnnn.......",
         ".pppppppppppppppp..ppp...pppppppp........................",
         "...................ppp...pppppppp........................",
         "................ppppppppppppppppp........................",
         "................ppppppppppppppppp........mmmmmmmml.......",
         "................p..ppp....ppppppp........mmmmmmmll.......",
         ".ddpppppppppppppppppppppppppppppp........................",
         ".pppppppppppppppppppppppppppppppp........................",
         ".........................................................",
         "........................................................."]],
      389 => [[3, 5, 6, 7, 9],
        ["..................................",
         "..................b...............",
         "............e..bbbbb....bb....bbb.",
         "...d.....eeeee.bbbbb....bb....bbb.",
         ".ddddd.eeeeeee.bbbbbb..bbbb..bbbb.",
         ".ddddd.eeeeeee.bbbbbb..bbbb..bbbb.",
         ".d..dd.eeee....bbbbbbbbbbbbbbbbbb.",
         ".d...d.eeeeeee.bbbbbbbbbbbbbbbbbb.",
         ".d...d.eeeeeee.bb..bbbbbbbbbbbbbb.",
         ".dddcc.eeeeeee.bb..b...bb.....bbb.",
         "........ee.....bbbbbb..bb..b..bbb.",
         "...............bbbbbbbbbbbbbbbbbb.",
         ".aaaaaaaaaaaaa.bbbbbbbb.bbbbbbbbb.",
         ".aaaaaaaaaaaaa.bbbbbbb..bbbbbbbbb.",
         ".aaaaaaaaaaaaa.bbbbbb.............",
         "...............bbbbbb.............",
         "........................*********.",
         "........................*********.",
         "........................*****.....",
         "......................*******.....",
         "........................*****..**.",
         "........................*********.",
         "..................................",
         ".................................."]]
    }

    # The panel the assist points to from where the player stands.
    def self.right(map)
      PokeAccess::EmPuzzles.grid_choice(WAYS[map], $game_player.x, $game_player.y)
    end
  end
end

PokeAccess::Game.define("emerald") do
  aqua = PokeAccess::EmAquaHideout
  [aqua::FIRST, aqua::SECOND].each do |map|
    mechanic(:state, map) do
      auto
      hide aqua::EXITS[map], :assist => true, :when => lambda { |ev| ev.id != aqua.right(map) }
      name aqua::EXITS[map], lambda { |ev| ev.id == aqua.right(map) ? :puzzle_right_way : nil }, :assist => true,
           :when => lambda { |ev| ev.id == aqua.right(map) }
      phase lambda { !$game_switches[aqua::MATT] }, :quiet => true, :hint => :em_aqua_hint
      solved(nil, :quiet => true) { $game_switches[aqua::MATT] }
    end
  end
end
