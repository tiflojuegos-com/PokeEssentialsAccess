# The false wall of the Rococo Retreat (map 496, EV5, Case Eleven): once Hart and his Magikarp search the room (variable
# 144 at 3), the door drawn on the wall is the sliding wall the case goes on through.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 496, :part => :false_wall) do
    auto
    searching = lambda { |_ev| $game_variables[144].to_i == 3 && !$game_self_switches[[496, 5, "A"]] }
    name 5, lambda { |ev| searching.call(ev) ? :afh_rococo_false_wall : nil }, :assist => true, :when => searching
  end
end
