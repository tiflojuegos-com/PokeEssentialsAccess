# Crestlight Gym (episode 12). Its hall (map 232) is platforms joined by invisible paths over an abyss: touch events
# named "Fall size(w,h)" cover the rest, add to variable 437 and put the player back on the last Save Spot crossed. Of
# the ten "Light<n> activater" switches, two ask a way: Up (event 51) and Left (event 93) light the path, the other
# leads to a Super Potion. The door at 19,3 (event 30, switch 354) ends it. Map 29: event 33 at 13,14 fights only facing
# west.
PokeAccess::Game.define("slld_anime") do
  mechanic(:state, 232) do
    auto
    name(/\ALight\d+ activater\z/, :slld_light_switch)
    name(/\ASave Spot\z/, :slld_save_spot)
    avoid(/\AFall size/, :assist => true)
    sent_back :slld_fall_back, :events => /\AFall size/
    watch :var => 437, :label => :slld_falls, :number => true
    answer 51, "Up"
    answer 93, "Left"
    solved(nil, :quiet => true) { $game_switches[354] }
  end
  mechanic(:state, 29) do
    auto
    spot :at => [13, 14], :label => :slld_battle_spot, :onto => true,
         :when => lambda { PokeAccess::SlldField.battle_tile?(33) }
  end
end
