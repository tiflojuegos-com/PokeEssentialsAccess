# Espurr on the Wispy Path (map 95): walks, chats and games raise variable 532, its friendship, told in words only as
# the player says goodbye; at 1000 Espurr joins and variable 533 goes to 3.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 95, :part => :espurr) do
    auto
    active { PokeAccess::Puzzles.assist? && $game_variables[533].to_i < 3 }
    count :rj_espurr_friendship, :value => lambda { [$game_variables[532].to_i, 1000].min }, :of => 1000,
                                 :announce => false, :assist => true
  end
end
