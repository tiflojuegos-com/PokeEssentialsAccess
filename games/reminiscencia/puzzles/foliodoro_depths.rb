# Reminiscencia's Profundidades del Bosque Foliodoro (map 411): the way out east (event 6) loops back until the two
# Ribombee in the trees are reached. The scene starts from the wall below them (event 1); until it has run, that wall
# is named for them and the drawn Ribombee (events 4 and 5) are hidden.
PokeAccess::Game.define("reminiscencia") do
  mechanic(:state, 411) do
    pending = lambda { |_ev| !$game_self_switches[[411, 1, "A"]] }
    auto
    name 1, :rm2_foliodoro_ribombee, :when => pending
    hide [4, 5], :when => pending
  end
end
