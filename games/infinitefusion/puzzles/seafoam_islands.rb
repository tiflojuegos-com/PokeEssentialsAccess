# Seafoam Islands' ice walls (map 808): the transfers inside the map that climb or drop the ice wall with the
# Ice Pick, named by what they do and merged by row. The sliding ice itself is the core's.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 808) do
    auto
    name [4, 5, 6, 7], :ifo_ice_up, :grouped => true
    name [8, 9, 10, 11, 25, 26, 27, 28], :ifo_ice_down, :grouped => true
  end
end
