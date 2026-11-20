# Vipik Gym (maps 225, the forest, and 226, inside the trunks): twelve holes of the forest and thirteen of the trunks, none
# drawn as an event, each asks to crawl in and moves the player to its pair on the other map. Walking inside either map
# links the holes of one region only, so the way to Xavier (switch 5 once beaten) is forest 2, trunk 2, forest 12, trunk 9.
PokeAccess::Game.define("insurgence") do
  forest_way = [2, 12]
  trunk_way = [2, 9]
  holes = lambda do |way|
    lambda { |ev| PokeAccess::Puzzles.assist? && way.include?(ev.id) ? :ins_tree_hole_way : :ins_tree_hole }
  end
  beaten = lambda { $game_switches[5] }
  mechanic(:state, 225) do
    auto
    name 2..13, holes.call(forest_way)
    sent_back :ins_tree_out, :maps => [226]
    active { !beaten.call }
    solved(nil, :quiet => true) { beaten.call }
    arrival_hint :ins_vipik_rule, :once => true
    hint :ins_vipik_hint
  end
  mechanic(:state, 226) do
    auto
    name 1..13, holes.call(trunk_way)
    sent_back :ins_tree_in, :maps => [225]
    active { !beaten.call }
    solved(nil, :quiet => true) { beaten.call }
    hint :ins_vipik_hint
  end
end
