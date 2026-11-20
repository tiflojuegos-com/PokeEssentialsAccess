# Murk Forest, Spiders' Area (map 750): six Ariados (events 6 to 11) and a Delta Metang count in variable 165, and the
# Delta Metagrossite item (event 23) lies in a sealed pocket at the west edge beside a Manaphy statue (event 24); Heart
# Swap used within seven tiles of that statue trades places with it. Walking cannot reach the pocket.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 750) do
    auto
    count :ins_o2_spiders, :selfs => [[6, 7, 8, 9, 10, 11], "A", 750], :of => 6, :assist => true
    name 24, lambda { |_ev| PokeAccess::Puzzles.assist? && !$game_self_switches[[750, 23, "B"]] ? :ins_o2_murk_statue_hint : nil }
  end
end
