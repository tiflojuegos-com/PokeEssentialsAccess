# Cartago Nova's gym (map 117): a dark maze with two invisible torch holders in opposite corners, event 4 at (2, 27)
# and event 1 at (41, 18), lit in either order (switches 143 and 144). With both lit the barrier of event 2 at (11, 8)
# goes.
PokeAccess::Game.define("africanus") do
  mechanic(:state, 117) do
    auto
    name [4, 1], :af_torch, :when => lambda { |ev| !$game_self_switches[[117, ev.id, "A"]] }
    count :af_torches, :switches => [143, 144]
    obstacle({ :events => 2 }, :label => :af_torch_barrier)
    solved(:af_torch_open) { $game_switches[143] && $game_switches[144] }
    arrival_hint :af_torch_rule
    hint :af_torch_hint
  end
end
