# Massilia's gym (map 89): each of its three rooms has a rack with two shields and two swords, and a weapon must be taken
# before going on. The shield or the sword sets the question the trainer of the room asks, so the racks are named for what
# they hold until the room's weapon is taken (switches 67 and 69, then variable 32 from 5). The right answer to a trainer gives an
# item, which is how the assist tells it.
PokeAccess::Game.define("africanus") do
  racks = [[[1, 2], [3, 4], lambda { $game_switches[67] }],
           [[20, 21], [15, 16], lambda { $game_switches[69] }],
           [[28, 29], [33, 34], lambda { $game_variables[32].to_i >= 5 }]]
  mechanic(:state, 89) do
    auto
    right_choice [5, 17, 27], :takes => :item
    racks.each do |shields, swords, taken|
      name shields, :af_shield, :when => lambda { |_ev| !taken.call }
      name swords, :af_sword, :when => lambda { |_ev| !taken.call }
    end
  end
end
