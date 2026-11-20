# Crystal Caves (maps 443 and 585, the same cave in two times): the Tesseract spot (event 3, at 33,49) is where the
# Tesseract carries the player from one to the other.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, [443, 585]) do
    auto
    name 3, :ins_u1_tesseract_spot
  end
end
