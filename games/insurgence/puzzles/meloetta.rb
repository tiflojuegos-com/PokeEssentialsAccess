# Meloetta's tile pedestals (maps 192 and 660 Koril Cave, 222 Helios Sewers, 243 Whirl Islands, 373 Nasca Town, 283 Fiery
# Caverns, 424 Misty Way, 553 Holon Volcano, 474 Void Gauntlet): an event with no graphic (a tile on Misty Way) that
# starts the tile puzzle when faced upward and, once solved, gives a Mysterious Scroll.
PokeAccess::Game.define("insurgence") do
  pedestal = lambda do |_ev|
    PokeAccess::Puzzles.assist? ? :ins_o1_pedestal_reward : :ins_o1_pedestal
  end
  [[192, 2], [660, 2], [222, 3], [243, 23], [373, 2], [283, 2], [424, 6], [553, 6], [474, 5]].each do |map, id|
    mechanic(:state, map, :part => :meloetta) do
      auto
      name id, pedestal
    end
  end
end
