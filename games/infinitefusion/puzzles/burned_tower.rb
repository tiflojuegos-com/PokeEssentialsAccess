# Burned Tower (maps 704, 697, 611 and the basement 696): sand drops the player to the floor below, landing where vars 149 and
# 150 say; the ghosts (events 4, 6, 7 and 8 of 697, 1, 3, 4, 8, 9 and 10 of 704) bounce the player a tile and move elsewhere,
# and the small gaps (11 and 13 of 697, 7 of 704) are jumped with the Wailmer Pail. Morty switches 383 on, which unlocks
# Ecruteak's gym. The stairs between floors are plain transfers, so only a landing on those vars is said as a fall.
PokeAccess::Game.define("infinitefusion") do
  floors = [611, 697, 704]
  sand = lambda { |x, y| floors.include?($game_map.map_id) && PokeAccess::World::Terrain.kind(x, y) == :sand }
  fall = lambda do
    dropped = $game_variables[149] == $game_player.x && $game_variables[150] == $game_player.y
    dropped && $game_variables[5] == $game_map.map_id ? :if_jo_tower_fall : nil
  end
  rule = lambda { [:if_jo_tower_rule, { :item => PokeAccess::Data.item_name(:WAILMERPAIL).to_s }] }

  terrain_rule(:kinds => [:sand]) { |x, y, _d| sand.call(x, y) ? false : nil }
  PokeAccess::World::Terrain.label_rule { |x, y| sand.call(x, y) ? :if_jo_sand_drop : nil }

  mechanic(:state, 697) do
    auto
    name [11, 13], :if_jo_gap
    obstacle({ :events => [4, 6, 7, 8] }, :moving => true)
    watch :switch => 383, :label => :if_jo_ecruteak_gym, :on => :if_jo_gym_open, :off => :if_jo_gym_locked
    arrival_hint rule
    sent_back fall, :maps => [704]
  end

  mechanic(:state, 704) do
    auto
    name 7, :if_jo_gap
    obstacle({ :events => [1, 3, 4, 8, 9, 10] }, :moving => true)
    arrival_hint rule
  end

  mechanic(:state, 611) do
    auto
    sent_back fall, :maps => [697]
  end

  mechanic(:state, 696) do
    auto
    sent_back fall, :maps => [611]
  end
end
