# Lavaridge Gym: hidden holes in the sand of the upper floor (map 236) drop the player to the basement (map 237), and
# vents there send them back up elsewhere, some to the middle of the upper floor, (13,17). WAYS holds, per floor, the
# hole or vent that starts the shortest way to Flannery from each tile ('*' where she is walked to, '.' no tile), found
# by a search over both floors: following each tile's choice the distance only falls. With the assist the one of the
# tile the player stands on is listed as the right way and every other leaves the lists.
module PokeAccess
  module EmLavaridge
    UPPER = 236
    BASEMENT = 237
    BEATEN = 7
    EXITS = { UPPER => [7, 8, 9, 10, 11, 15, 16, 17, 18, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30],
              BASEMENT => [1, 3, 5, 7, 8, 9, 11, 12, 13, 14, 15, 16, 17, 18, 19] }
    WAYS = {
      236 => [[7, 8, 9, 11, 15, 18, 20, 21, 23, 24],
        ["..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         ".....ffffff.gjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         ".....ffffff.jjjj.hhhh.........",
         "..............................",
         ".....eeee.cc.bb.*****.........",
         ".....eeee.cc.bb..***..........",
         ".....eeee.cc.bb..***..........",
         ".....eeee.cc.bb.*****.........",
         ".....eeee.cc.bb.*****.........",
         ".....eeee.cc.bb.*i***.........",
         ".....eeee.ec.bb.aaaaa.........",
         ".....eeee.cc.bb.aaaaa.........",
         ".....eeee.ee.baaaaaaaa........",
         ".....eeeeeee.aaaaaaaaa........",
         ".....deeeeee.aaaaaaaaa........",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         "..............................",
         ".............................."]],
      237 => [[3, 5, 7, 8, 9, 11, 12, 13, 15, 19],
        ["....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "......h.....h.......",
         "..hhhhhhhhhhhhhhhh..",
         "..hhhhhhhhhhhhhhhh..",
         "..gghhhhhhhhhhhhhh..",
         "....................",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.a.ii.jjj..",
         "..ffff.bb.c.ii.jjj..",
         "..ffff.bb.c.ii.jjj..",
         "..efff.bb.c.ii.jjj..",
         "..efff.bb.c.ii.jjj..",
         "..cccc.cb.c.jj.jjj..",
         "..cccc.cc.c.jj.jjj..",
         "..ccccccccc.jjjjjj..",
         "..ccccccccc.jjjjjj..",
         "..dcccccccc.jjjjjj..",
         "....................",
         "....................",
         "....................",
         "....................",
         "....................",
         "...................."]]
    }

    # The hole or vent the assist points to from where the player stands.
    def self.right(map)
      PokeAccess::EmPuzzles.grid_choice(WAYS[map], $game_player.x, $game_player.y)
    end
  end
end

PokeAccess::Game.define("emerald") do
  gym = PokeAccess::EmLavaridge
  [gym::UPPER, gym::BASEMENT].each do |map|
    mechanic(:state, map) do
      auto
      hide gym::EXITS[map], :assist => true, :when => lambda { |ev| ev.id != gym.right(map) }
      name gym::EXITS[map], lambda { |ev| ev.id == gym.right(map) ? :puzzle_right_way : nil }, :assist => true,
           :when => lambda { |ev| ev.id == gym.right(map) }
      phase lambda { !$game_switches[gym::BEATEN] }, :quiet => true, :hint => :em_lava_hint
      sent_back(map == gym::UPPER ? :em_lava_rose : :em_lava_fell, :maps => [map == gym::UPPER ? gym::BASEMENT : gym::UPPER])
      arrival_hint :em_lava_rule, :once => true if map == gym::UPPER
      solved { $game_switches[gym::BEATEN] }
    end
  end
end
