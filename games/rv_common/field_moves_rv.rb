# The engine's field moves refuse while the story forbids them: Reborn's and Rejuvenation's HiddenMoves.rb check the
# NotPlayerCharacter switch first (the player plays someone else), and the three games' Surf the Cant_Surf one.
# Desolation has no NotPlayerCharacter, which its Game_Switches reads as off.
PokeAccess::Hooks.override("PokeAccess::FieldMoves", :can?, :tag => "rv_common") do |_mod, original, args|
  away = ($game_switches[:NotPlayerCharacter] rescue false)
  dry = args[0] == :SURF && ($game_switches[:Cant_Surf] rescue false)
  away || dry ? false : original.call
end

# The three games' Kernel.pbSurf refuses first of all while anyone walks along as a dependent event.
PokeAccess::Pathfinder.surf_company(:dependents)
