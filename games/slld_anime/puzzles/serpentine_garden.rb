# Gwormholed (episode 5, map 361): Purrlit has 90 seconds and seven hearts (variable 53) to cover seven holes (events 9,
# 15 and 18 to 22, each its self switch A once covered; variable 57 counts them) while seven wild Pokemon (events 8 and
# 24 to 29) chase it within five tiles, each touch a heart less. Seven covered, Donna ends it.
PokeAccess::Game.define("slld_anime") do
  holes = [9, 15, 18, 19, 20, 21, 22]
  mechanic(:state, 361) do
    auto
    name holes, :slld_hole, :when => lambda { |ev| !$game_self_switches[[361, ev.id, "A"]] }
    obstacle(/\A(PIXWEE|PIXWEE_female|HAMSTAR|CHEEPIP|BUDCHEEP_female|BUDCHEEP_FLYING)\z/, :moving => true,
             :label => :slld_chaser)
    watch :var => 53, :label => :slld_hearts, :number => true
    count :slld_holes, :var => 57, :of => 7
    solved(nil, :quiet => true) { $game_variables[57] >= 7 }
  end
end
