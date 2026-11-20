# Granite Cave B1F's cracked floor (map 34): the floorHole events drop a player on foot to B2F, while on the bike each
# holds until the same one is stepped on eight times. Across the east strip, the way down of event 63 (36,7) leads to the
# corner of B2F (map 35) with its Rare Candy (event 4) and hidden Everstone (event 5); once both are taken it is done.
PokeAccess::Game.define("infinitefusion_hoenn") do
  taken = lambda { $game_self_switches[[35, 4, "A"]] && $game_self_switches[[35, 5, "A"]] }

  mechanic(:state, 34, :part => :cracked_floor) do
    auto
    name(/\Ahole\.shadowless\z/, :if_ho_crack, :grouped => true)
    arrival_hint :if_ho_crack_rule, :once => true
    info { :if_ho_crack }
    active { PokeAccess::Puzzles.assist? && !taken.call }
    hint :if_ho_crack_hint
    solved(nil, :quiet => true) { taken.call }
  end
end
