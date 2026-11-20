# The Sacred Lighthouse's rooms (map 238): from the first (30,8) the floor ahead of each arrival leads on, (30,7) to
# (30,29), (30,24) to (30,46) and (30,41) to (31,66), while the tile right behind each arrival (events 13, 23 and 24)
# sends the player back to the first room.
PokeAccess::Game.define("uranium") do
  mechanic(:state, 238, :part => :rooms) do
    auto
    sent_back :ura_r3_lighthouse_back, :to => [30, 8], :events => [13, 23, 24]
  end
end
