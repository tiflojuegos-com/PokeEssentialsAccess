# Beryl Library's back room (map 427): the hole in the floor by the Growlithe (event 2, no graphic) is where the police
# errand (variable 78) takes the player on; named so it is not taken for a sign. The shelves of map 426 that let the
# player through are forced moves the routes already take.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 427) do
    auto
    name 2, :rbf_library_hole
  end
end
