# Ruby Chamber (map 569, under Mt. Ember): a maze of stairs with no graphic that move the player inside the same map, each
# one named by whether it goes down or up. Those at 17, 19, 21 and 23 only go down once the Ember Cream is on (switch 573),
# which the man at event 62 makes from a Fire Gem. Walking the stairs over the tiles' passability (entering at 17,3) the ruby at
# (14,113) is reached by stairs 5, 13, 19, 6 and 68, or the longer 5, 15, 21, 33, 26, 6 and 68; with the ruby in the bag what is left
# is event 35, which throws it into the lava (switch 572).
PokeAccess::Game.define("infinitefusion") do
  carrying = lambda { ($PokemonBag.pbQuantity(:RUBY).to_i > 0) rescue false }

  mechanic(:state, 569) do
    auto
    name [5, 6, 10, 13, 15, 17, 19, 21, 23, 32, 33, 34, 39, 40, 41, 42, 68], :ifq_stairs_down
    solved(nil, :quiet => true) { $game_switches[572] }
    phase lambda { !$game_switches[573] && !$game_switches[572] }, :quiet => true, :hint => :ifq_ruby_cream,
          :hidden => right_way(62)
    phase lambda { $game_switches[573] && !$game_switches[572] && !carrying.call }, :quiet => true,
          :hint => :ifq_ruby_way, :hidden => right_way(5, 13, 19, 6, 68)
    phase lambda { $game_switches[573] && !$game_switches[572] && carrying.call }, :quiet => true,
          :hint => :ifq_ruby_lava, :hidden => right_way(35)
    name [8, 9, 11, 12, 14, 16, 18, 20, 22, 24, 26, 27, 28, 29, 30, 31, 59, 60, 67], :ifq_stairs_up
  end
end
