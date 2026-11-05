# The old woman's errand on Ruta 15 and Cataratas Logro (maps 179, 180, 209 and 210): the piles of rubbish, drawn with a graphic
# of their own whose file name says nothing, while they are there to pick up. The game says how full the bag is.
PokeAccess::Game.define("armonia") do
  mechanic(:state, [179, 180, 209, 210]) do
    auto
    name(/\AOW_Basura\z/, :arm_trash_heap)
  end
end
