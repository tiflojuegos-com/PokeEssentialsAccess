# Holon Pyramid, third floor (map 547): four squares in a row at y 38 (events 9, 11, 51 and 52, from x 45 to 48) that count
# presses in variable 164 and switch 611, shared with the Perfection Laboratory. Pressing the fourth twice, then the first
# and then the third (switch 610) opens the way to Delta Torchic, which turns the third square's event (51) into the step to
# map 548 and leaves it its own name; the second always fails, and any miss counts up to a reset.
PokeAccess::Game.define("insurgence") do
  done = lambda { $game_switches[610] }
  state = lambda { [($game_variables[164] || 0).to_i, $game_switches[611] ? true : false] }
  press = lambda { |n| lambda { [:ins_o1_pyr_press, { :n => n }] } }
  at_count = lambda { |v| lambda { !done.call && state.call == [v, true] } }
  squares = [9, 11, 51, 52]
  square = lambda do |ev|
    (ev.id == 51 && done.call) ? nil : [:ins_o1_pyr_square, { :n => squares.index(ev.id) + 1 }]
  end
  mechanic(:state, 547, :part => :squares) do
    auto
    name squares, square, :when => lambda { |ev| !(ev.id == 51 && done.call) }
    phase lambda { !done.call && state.call[0] == 0 }, :hint => press.call(4)
    phase at_count.call(1), :hint => press.call(4)
    phase at_count.call(2), :hint => press.call(1)
    phase at_count.call(3), :hint => press.call(3)
    phase lambda { !done.call }, :hint => :ins_o1_pyr_broken
    solved(nil, :quiet => true) { done.call }
  end
end
