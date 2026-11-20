# Deep Cavern (map 521): about 170 current_* events carry the player a tile in their direction; the core names them and
# the routes follow them on their own, so the room only says its rule on arriving.
PokeAccess::Game.define("insurgence") do
  mechanic(:state, 521) do
    auto
    arrival_hint :ins_cavern_rule
  end
end
