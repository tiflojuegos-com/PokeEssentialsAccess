# Uranium's devices stand in for a Pokemon that knows a field move, the move's badge still asked (its
# PField_HiddenMoves): boxing gloves for Rock Smash, the power glove for Strength, a surfboard for Surf, a climbing pick
# for Waterfall and scuba gear for Dive. Playing as L (outfit 1), Strength wants no badge but a power cell.
PokeAccess::Game.define("uranium") do
  field_move_tool(:ROCKSMASH, :BOXINGGLOVES)
  field_move_tool(:STRENGTH, :POWERGLOVE)
  field_move_tool(:SURF, :SURFBOARD)
  field_move_tool(:WATERFALL, :CLIMBINGPICK)
  field_move_tool(:DIVE, :SCUBAGEAR)

  # Its Kernel.pbSurf, and the action button's prompt at the water before it, refuse while anyone walks along as a
  # dependent event.
  surf_company(:dependents)

  override("PokeAccess::FieldMoves", :can?) do |_mod, original, args|
    base = original.call
    fm = PokeAccess::FieldMoves
    next base unless args[0] == :STRENGTH && base == false && (PokeAccess::Engine.player.outfit rescue nil) == 1
    fm.badge_ok?(:STRENGTH) ? base : fm.bag_has?(:POWERCELL)
  end
end
