# Magrodar Crater (map 213): the black shard rocks 1 at (46,68), 14 at (29,69), 15 at (60,42) and 23 at (42,61) step
# away from the player only at night (switch 15), so the routes push them. The springs 6 at (22,47) and 7 at (22,45)
# throw the player two tiles the way they face until switch 476 makes them plain floor.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 213, :part => :night_rocks) do
    auto
    name [1, 14, 15, 23], :rj_night_rock, :assist => true
    name [6, 7], :rj_magrodar_spring, :when => lambda { |_ev| !$game_switches[476] }
    active { PokeAccess::Puzzles.assist? }
    hint :rj_night_rock_hint
  end
end
