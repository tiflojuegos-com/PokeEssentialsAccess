# Fort Rystrine (map 523): six graphic-less floor tiles hide a Vileplume that mugs the player and sends them back across
# the fort while variable 589 is 0. Once the serum is on (589 at 1) the next one has it run off (589 to 2), which the
# quest needs, so walks keep off them only before.
PokeAccess::Game.define("rejuvenation") do
  traps = [24, 31, 33, 73, 78, 90]
  mechanic(:state, 523, :part => :vileplume) do
    auto
    avoid lambda { |ev| traps.include?(ev.id) && $game_variables[589].to_i < 1 }, :assist => true
    sent_back :rjd_fr_mugged, :events => traps
    solved { $game_variables[589].to_i >= 2 }
  end
end
