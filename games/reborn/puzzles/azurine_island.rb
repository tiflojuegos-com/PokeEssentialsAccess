# Azurine Island (map 206): ten Foongus lie on the ground looking like items (events 38 to 47, named Item, drawn
# pkmn_foongus) and start a wild fight when examined. With the assist they are named for what they are.
PokeAccess::Game.define("reborn") do
  mechanic(:state, 206) do
    auto
    name (38..47), :rba_az_foongus, :assist => true
  end
end
