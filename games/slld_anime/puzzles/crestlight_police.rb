# Episode 11's police chain in Crestlight. The policeman by the ketchup stain (map 37, event 3) speaks only to a player
# facing east from 8,10, setting switch 340; the station guard (map 39) then hints at a distraction, and Purrlit's Ember
# on the trash can with no graphic (event 11) sends him away. Upstairs, the Camouflaged Heist (map 368): sixteen
# Trainer(2) policemen see two tiles ahead; one that sees Wormune adds to variable 359 and sends it to 13,24; the red
# locker (event 18, used from 12,6) holds the uniform (switch 344).
PokeAccess::Game.define("slld_anime") do
  mechanic(:state, 37) do
    auto
    spot :at => [8, 10], :label => :slld_police_spot, :onto => true,
         :when => lambda { $game_switches[339] && !$game_switches[340] }
  end
  mechanic(:state, 39) do
    auto
    name 11, :slld_trash_can, :when => lambda { |_ev| !$game_switches[344] }
    on_reach 11, { :text => /pile of paper/ },
             lambda { |_ev| [:puzzle_answer, { :a => PokeAccess::Data.species_name(:PURRLIT).to_s }] }, :assist => true
  end
  watchers(368)
  mechanic(:state, 368) do
    auto
    spot :event => 18, :label => :slld_red_locker, :when => lambda { !$game_switches[344] }
    sent_back :slld_caught_back, :to => [13, 24]
    watch :var => 359, :label => :slld_caught, :number => true
    solved(nil, :quiet => true) { $game_switches[344] }
  end
end
