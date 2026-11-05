# Palacio Luminalia (maps 172, 191): turn the three "malvoBusto" busts to the facings the map's events check (4 west,
# 6 east, 8 north); each sets its variable (162, 163, 164) to 1 while facing its goal and map 191 turns switch 398 on
# once all three do, so the win is the three variables, or 398 for good once on.
PokeAccess::Game.define("pokemon_z") do
  { 172 => { [35, 11] => 6 }, 191 => { [18, 52] => 4, [12, 7] => 8 } }.each do |map, facings|
    mechanic(:facing, map) do
      statues(/malvoBusto/i, :statue_bust)
      goals facings
      solved { $game_switches[398] || [162, 163, 164].all? { |v| $game_variables[v] == 1 } }
    end
  end

  # Palacio Luminalia (map 190): the Talismán de Malvo shines on the middle seat of the long table's upper side, event
  # 94, an invisible tile to stand on, by action there or used from the bag (its handler checks that tile); with switch
  # 412 on, an autorun carries the player to the Reflection Chambers.
  mechanic(:state, 190) do
    phase lambda { !$game_switches[412] && PokeAccess::FieldMoves.bag_has?(:TALISMANMALVO) }, :quiet => true,
          :hint => :z_chair_hint, :spots => [{ :event => 94, :label => :z_chair }]
  end
end
