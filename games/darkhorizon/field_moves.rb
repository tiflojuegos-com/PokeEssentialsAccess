# Dark Horizon's pbStrength asks for nothing, neither the move nor a badge, and its pbPushThisBoulder pushes a boulder
# at once, Strength used or not (18_DH_Moves.rb): a boulder needs no field move. On map 115 it keeps a boulder at row 8
# or above from going up, against a softlock, which the route finder does not know.
PokeAccess::Game.define("darkhorizon") do
  push_script(/pbPushThisBoulder/)

  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    args[0] == :STRENGTH ? true : original.call
  end
end
