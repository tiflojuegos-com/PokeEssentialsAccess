# Victory Road's Ruby Room (map 803): the red crystal drawn at (25,24), event 41, flips switch 1209 as the key reacts to
# it. With it off, the Rock Climb point of event 42 (25,28) stands; with it on, the one of event 43 (27,26) instead.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 803, :part => :climbs) do
    auto
    name 41, :rbc_ruby_crystal
    name [42, 43], :rbc_ruby_climb
  end
end
