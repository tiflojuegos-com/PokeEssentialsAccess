# Perseida's Elemental Altar (map 94, Nebula Island): seven monoliths each take one evolution stone and give an amulet for it,
# adding one to variable 39, and the mythical Eevee shows once the seventh is paid. The assist counts the stones offered.
PokeAccess::Game.define("perseida") do
  mechanic(:state, 94) do
    auto
    count :perseida_altar_stones, :var => 39, :of => 7, :assist => true
  end
end
