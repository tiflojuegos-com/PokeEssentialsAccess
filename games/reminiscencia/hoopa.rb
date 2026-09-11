# The Hoopa gacha's prize is printed by pbAddPokemonRNG and its refusals by pbMessage, both spoken by the
# dialogue reader; what nobody said is the balance the screen keeps in its corner -- heart scales and
# coins, repainted after every spin -- which is what the offer of a shiny extra is decided on. It is one
# pbDrawTextPositions batch in drawMaintext, captured and said queued.
PokeAccess::Game.define("reminiscencia") do
  around("HoopaGacha", :drawMaintext, :optional => true) do |_s, nxt, _a|
    PokeAccess::PaintCapture.speak_around(:rem_hoopa, false) { nxt.call }
  end
end
