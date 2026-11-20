# Sixth gym, Pueblo Vánitas (map 146): three thresholds with no graphic in each room, left, centre and right (events 5, 12
# and 14 in the hall, 11, 13 and 15 in the room of the wild Pokémon), lead to a challenge drawn at random; the ladies'
# clue names one of them by its side.
PokeAccess::Game.define("pokemon_z") do
  mechanic(:state, 146) do
    auto
    name [5, 11], :z_gym6_left
    name [12, 13], :z_gym6_centre
    name [14, 15], :z_gym6_right
  end
end
