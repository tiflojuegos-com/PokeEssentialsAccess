# Solar 1.0.1 accepts these tools without a badge or a Pokemon knowing the move.
# The normal move branches ask for the badge; Strength accepts its badge alone.
# The final Surf copy permits its following Pokemon, but refuses other dependent events.
PokeAccess::Game.define("solar_light_lunar_dark") do
  field_move_item(:CUT, :CLIPPERS)
  field_move_item(:ROCKSMASH, :HAMMER)
  field_move_item(:STRENGTH, :STRENGTHGLOVES)
  field_move_item(:SURF, :SURFBOARD)
  field_move_item(:DIVE, :SNORKLE)
  field_move_item(:WATERFALL, :BOARDMOTOR)
  override("PokeAccess::FieldMoves", :can?) do |mod, original, args|
    if args[0] == :STRENGTH
      available = [mod.item_ready?(:STRENGTH), mod.badge_ok?(:STRENGTH)]
      available.include?(true) ? true : (available.include?(nil) ? nil : false)
    else
      original.call
    end
  end
  surf_company(:dependents) { defined?(Following_Activated_Switch) && $game_switches[Following_Activated_Switch] }
end
