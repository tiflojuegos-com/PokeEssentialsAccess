# Revival's pbSurf (0246_Overworld_FieldMoves) refuses only when the player has none of the three: the Surf badge, a
# party Pokemon that knows Surf, or the Lapras whistle (SILBATOLAPRAS) in the bag; any one of them is enough.
PokeAccess::Game.define("revival") do
  field_move_item(:SURF, :SILBATOLAPRAS)

  override("PokeAccess::FieldMoves", :can?) do |mod, original, args|
    if args[0] == :SURF
      ok = [mod.badge_ok?(:SURF), mod.item_ready?(:SURF), mod.knows?(:SURF)]
      ok.include?(true) ? true : (ok.include?(nil) ? nil : false)
    else
      original.call
    end
  end
end
