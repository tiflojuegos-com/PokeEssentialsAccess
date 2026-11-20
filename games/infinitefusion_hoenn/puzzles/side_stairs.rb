# Side stairs of Hoenn: events with no graphic, one over the other, that call side_stairs_right or side_stairs_left. Touched
# facing right (or left) they move the player up and across in a diagonal, facing the other way down and back. They stand in
# the Rustboro Gym (map 78, right), Rusturf Tunnel (map 28, right) and Stern's Shipyard (map 88, both). Routes do not count
# the diagonal, so the rule says to ask for them again after the stairs. It is said once per map.
PokeAccess::Game.define("infinitefusion_hoenn") do
  mechanic(:state, 78) do
    auto
    name [8, 9], :if_ho_side_stairs
    arrival_hint :if_ho_side_stairs_rule, :once => true
  end

  mechanic(:state, 28) do
    auto
    name [22, 23], :if_ho_side_stairs
    arrival_hint :if_ho_side_stairs_rule, :once => true
  end

  mechanic(:state, 88) do
    auto
    name [9, 10, 11, 12, 13], :if_ho_side_stairs
    arrival_hint :if_ho_side_stairs_both_rule, :once => true
  end
end
