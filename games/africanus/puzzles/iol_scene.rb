# Africanvs' Iol (map 236) has no puzzle: event 26, with no graphic, only turns on the switch that draws the cultists of a scene, though
# it reads as a silent control.
PokeAccess::Game.define("africanus") do
  mechanic(:state, 236) do
    auto
    not_control 26
  end
end
