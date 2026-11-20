# Helios Sewers (map 180): the Manaphy statue (event 19, 85,58) stands at the foot of a sealed corridor (x 84 to 86, y 39
# to 59) walled off from the sewer. Heart Swap used within seven tiles of the statue trades places with it, and from the
# corridor a stretch of water (y 33 to 38) leads north to Delta Heatmor (event 20, 99,16), which takes Surf.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 180, :part => :statue) do
    auto
    name 19, lambda { |_ev| PokeAccess::Puzzles.assist? ? :ins_o2_helios_statue_hint : nil }
  end
end
