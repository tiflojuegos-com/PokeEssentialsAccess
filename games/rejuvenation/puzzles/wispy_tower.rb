# Wispy Tower's statue (map 73, event 9): a touch event with no graphic on the statue's tile, the only way into the
# Forsaken Laboratory, taken walking into it from below. A sighted player sees a statue; the assist tells the stairs.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 73, :part => :statue) do
    auto
    name 9, lambda { |_ev| PokeAccess::Puzzles.assist? ? :rj_wispy_statue_stairs : :rj_wispy_statue }
  end
end
