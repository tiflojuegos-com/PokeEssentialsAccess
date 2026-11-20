# Old Shipwreck (map 806): the barrels carry the editor's name StrengthBoulder, so they would be called rocks; they are
# pushed with Strength like them, so they are named in the lists alone and never counted as a puzzle.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 806) do
    auto
    name(/StrengthBoulder/, :ifu_barrel, :when => false)
  end
end
