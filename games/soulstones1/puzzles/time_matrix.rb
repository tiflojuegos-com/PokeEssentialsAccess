# The Time Matrix (maps 48, 386 and 387): with Jason along (switch 140), five "Transparent Object" holograms per level,
# touched once each (self switch A), raise the level's variable (270, 271, 272); the "Invisible Barrier" lets the player
# through at 5, or at 6 on the third level, where the story fight beside the barrier adds the last one. The level ends
# with switch 139, 142 or 144, set past the barrier.
module PokeAccess
  module SoulstonesTimeMatrix
    # Map => [objects, barriers, variable, needed, finished switch].
    LEVELS = { 48 => [[69, 70, 76, 77, 78], [71, 75, 79, 80], 270, 5, 139],
               386 => [[77, 78, 80, 81, 82], [79, 83, 84, 85], 271, 5, 142],
               387 => [[67, 68, 69, 70, 71], [46, 47], 272, 6, 144] }
  end
end

PokeAccess::Game.define("soulstones1") do
  PokeAccess::SoulstonesTimeMatrix::LEVELS.each do |map, (objects, barriers, var, needed, done)|
    mechanic(:state, map) do
      auto
      name objects, :ss1_matrix_object, :when => lambda { |ev| !$game_self_switches[[map, ev.id, "A"]] }
      name barriers, :ss1_matrix_barrier, :when => lambda { |_ev| $game_variables[var].to_i < needed }
      count :ss1_matrix_objects, :value => lambda { objects.count { |id| $game_self_switches[[map, id, "A"]] } },
                                 :of => 5, :announce => true, :hide_zero => true
      arrival_hint :ss1_matrix_rule, :once => true
      hint(map == 387 ? :ss1_matrix_hint_last : :ss1_matrix_hint)
      solved { $game_switches[done] || $game_variables[var].to_i >= needed }
    end
  end
end
