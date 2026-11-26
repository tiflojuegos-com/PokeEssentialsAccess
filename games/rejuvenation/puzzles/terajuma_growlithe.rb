# The lady's Growlithe in the Terajuma Jungle (map 210): walks, pats, games and bones raise variable 538, its
# friendship, told in words only as the walk ends; at 1000 it joins and variable 539 goes to 3. On a walk (switch 347)
# the path's edges, events 40 to 45, bring the player back to (49,9) and end it.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 210, :part => :growlithe) do
    auto
    active { PokeAccess::Puzzles.assist? && $game_variables[539].to_i < 3 }
    count :rj_growlithe_friendship, :value => lambda { [$game_variables[538].to_i, 1000].min }, :of => 1000,
                                    :announce => false, :assist => true
    sent_back :rj_growlithe_walk_over, :to => [49, 9], :events => 40..45
  end
end
