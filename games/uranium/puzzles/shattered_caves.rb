# Chloe's whirlpool (map 254): the plank (event 1) sets variable 131 to 24, which lays the way into the whirlpool (events 2
# and 3) that takes the player under the sea. The Shattered Caves (map 258): two cracked floors (events 35 and 36) give way
# and drop the player to (66, 64), lower in the same cave. They are drawn as tiles, which the lists leave out, so the free
# camera names each while it shows.
PokeAccess::Game.define("uranium") do
  floors = [35, 36]

  mechanic(:state, 254) do
    auto
    name 1, :ura_rp_plank
  end

  mechanic(:state, 258) do
    auto
    name floors, :ura_rp_cracked_floor, :when => false
    sent_back :ura_rp_cracked_fell, :to => [66, 64], :events => floors
  end

  camera_tile(:maps => [258]) do |x, y|
    shown = floors.map { |id| $game_map.events[id] }.any? { |ev| ev && ev.x == x && ev.y == y && ev.tile_id.to_i > 0 }
    shown ? PokeAccess::I18n.t(:ura_rp_cracked_floor) : nil
  end
end
