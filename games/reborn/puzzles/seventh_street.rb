# 7th Street (map 324): the trash can by the wall (events 55 at (29,9) and 51 at (30,9)) hides a switch; either half
# asks "A secret switch! Press it?", the left one faced from below alone. Yes sets switch 2034: the can shifts left and
# the wall above (event 53 at (30,8)) becomes the door to Beryl Wall, the way to the Subseven Sanctum.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 324, :part => :trash_switch) do
    auto
    name [51, 55], lambda { |_ev| PokeAccess::Puzzles.assist? ? :rbb_7th_trash_switch : :rbb_7th_trash },
         :grouped => true, :when => lambda { |_ev| !$game_switches[2034] }
    right_choice [51, 55], :takes => { :switch => 2034 }
    hint :rbb_7th_hint
    active { !$game_switches[2034] }
    solved(nil, :quiet => true) { $game_switches[2034] }
  end
end
