# Pokemon Solar Light & Lunar Dark 1.0.1: its field moves, by 0116_PField_FieldMoves.rb and 0216_Following Pokemon.rb,
# and the one person the map's editor name misnames.
PokeAccess::Game.define("solarlight") do
  # Keira (map 242, event 3) carries the editor name "Keira Room".
  event_name do |event|
    if PokeAccess.ivar(event, :@map_id) == 242 && event.id == 3 && event.character_name == "BWKeira" &&
       PokeAccess::Locator.own_name(event) == "Keira Room"
      PokeAccess::I18n.t(:solar_keira)
    end
  end

  # Each field function takes its tool from the bag, with no badge and no Pokemon that knows the move; Flash and Fly take
  # theirs in the party's and the bag's handlers (0127_PItem_ItemEffects.rb).
  field_move_item(:CUT, :CLIPPERS)
  field_move_item(:ROCKSMASH, :HAMMER)
  field_move_item(:STRENGTH, :STRENGTHGLOVES)
  field_move_item(:SURF, :SURFBOARD)
  field_move_item(:DIVE, :SNORKLE)
  field_move_item(:WATERFALL, :BOARDMOTOR)
  field_move_item(:FLASH, :FLASHLIGHT)
  field_move_item(:FLY, :SERVICEWHISTLE)

  # Its Kernel.pbStrength takes the badge alone, with no Pokemon that knows the move.
  override("PokeAccess::FieldMoves", :can?) do |mod, original, args|
    if args[0] == :STRENGTH
      (mod.item_ready?(:STRENGTH) || mod.badge_ok?(:STRENGTH)) ? true : false
    else
      original.call
    end
  end

  # The Kernel.pbSurf it runs (the Following Pokemon script's) refuses while anyone walks along as a dependent event,
  # unless the following Pokemon's switch is on.
  surf_company(:dependents) { $game_switches[Following_Activated_Switch] }
end
