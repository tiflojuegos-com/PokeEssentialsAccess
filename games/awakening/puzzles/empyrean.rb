# The Empyrean tower's floors 16 and 20. On floor 16 (map 482) eleven hidden tiles off the way turn switch 448 on, and
# the event at (14, 7) unsticks the door of floor 15 (switch 449) only while it is off; coming up again from floor 15
# turns it off. With the puzzle assist the routes keep off those tiles, and a phase says how to start over once one
# is stepped on. On floor 20 (map 484) a glint on a statue at (48, 7) is the button that opens the floor's stuck door.
PokeAccess::Game.define("awakening") do
  mechanic(:state, 482) do
    auto
    avoid 2..12, :assist => true
    phase lambda { PokeAccess::Puzzles.assist? && $game_switches[448] && !$game_switches[449] }, :quiet => true,
          :hint => :awk_p16_failed
    solved { $game_switches[449] }
  end

  mechanic(:state, 484) do
    auto
    name 6, :awk_statue_button, :when => lambda { |_ev| !$game_self_switches[[484, 2, "A"]] }
    solved { $game_self_switches[[484, 2, "A"]] }
  end
end
