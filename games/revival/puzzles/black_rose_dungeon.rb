# Mazmorras Ala Este (map 242), in the Black Rose Tower: a lever hidden as a brick under a poster (events 21 and 22)
# and the poster itself (17 to 20) turn switch 295 on, which takes the poster off the wall; the lever, gone from sight
# then, turns it off again. The core says what opens; this names the two.
PokeAccess::Game.define("revival") do
  mechanic(:state, 242) do
    auto
    name [21, 22], :rv_dungeon_lever, :grouped => true
    name 17..20, :rv_dungeon_poster, :grouped => true, :when => lambda { |_ev| !$game_switches[295] }
  end
end
