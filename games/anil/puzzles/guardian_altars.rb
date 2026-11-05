# The Guardian Bird altars (Cabo Azabache, Islote Recuerdo and Cueva Glaciada), drawn with no sprite: named so they can be
# found in the lists, as the game says they are hidden.
PokeAccess::Game.define("anil") do
  { 186 => 13, 190 => 8, 198 => 29 }.each do |map, altar|
    mechanic(:state, map) do
      auto
      name altar, :anil_altar
    end
  end
end
