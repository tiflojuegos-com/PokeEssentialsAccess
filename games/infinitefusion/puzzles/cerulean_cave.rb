# Cerulean Cave (maps 322 first floor and 323 second floor): the holes of the second floor (events on tile 582) drop the player
# on a fixed spot of the first floor, and the pockets of each floor only join through stairs and, from the west pocket, one
# hole: the one at (8, 16), which lands on (6, 18). The stairs that go on to Mewtwo's floor (19, 25) are reached that way.
PokeAccess::Game.define("infinitefusion") do
  holes = [5, 6, 7, 8, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 23, 24, 25, 26, 27, 30, 31, 32]
  landings = [[18, 25], [30, 4], [6, 18], [25, 16], [33, 24], [33, 20], [6, 7]]
  right_hole = 6
  way = lambda { PokeAccess::Puzzles.assist? }

  mechanic(:state, 323) do
    auto
    name holes - [right_hole], :ifu_cerulean_hole, :grouped => true
    name right_hole, lambda { |_ev| way.call ? :ifu_cerulean_right_hole : :ifu_cerulean_hole }
    arrival_hint :ifu_cerulean_rule, :once => true
    hint :ifu_cerulean_hint
    active { way.call }
  end

  mechanic(:state, 322) do
    auto
    landings.each { |at| sent_back :ifu_cerulean_fell, :maps => [323], :to => at }
    hint :ifu_cerulean_hint
    active { way.call }
  end
end
