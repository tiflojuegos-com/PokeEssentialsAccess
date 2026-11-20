# Sonata Gym (map 269): fifty-six invisible flowerbed edges (JUMP_UPDOWN, ids 1 to 33 vertical, 34 to 56 horizontal) hop the
# player two tiles toward where they face when they bump into one. Switch 7 is the fourth badge. The routes read them as
# hedges, so the assisted route to Harmony carries every jump.
PokeAccess::Game.define("insurgence") do
  beaten = lambda { $game_switches[7] }
  mechanic(:state, 269) do
    auto
    name 1..33, :ins_flower_jump_v, :grouped => true
    name 34..56, :ins_flower_jump_h, :grouped => true
    active { !beaten.call }
    solved(nil, :quiet => true) { beaten.call }
    arrival_hint :ins_sonata_rule
    hint :ins_sonata_hint
  end
end
