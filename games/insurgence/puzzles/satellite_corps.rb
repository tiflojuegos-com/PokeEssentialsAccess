# Satellite Corps (maps 575, 576 and 577, floors 2 to 4): on each floor a broken electronic lock starts a tile puzzle and,
# once solved, opens the floor's electronic door (the event that lock sets its self switch A on). The door's upper half has no
# action and lies next to the lock, so it stays out of the lists and the lock is the one target.
PokeAccess::Game.define("insurgence") do
  lock = lambda do |_ev|
    PokeAccess::Puzzles.assist? ? :ins_o1_lock_door : :ins_o1_lock
  end
  [[575, [4, 2]], [576, [2, 4]], [577, [2, 1]]].each do |map, ids|
    mechanic(:state, map, :part => :lock) do
      auto
      name ids[0], lock
      hide ids[1]
    end
  end
end
