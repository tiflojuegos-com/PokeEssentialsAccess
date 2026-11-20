# Lumiose Gym, on two maps. Map 833 is Clemont's: five identical doors in a row (events 4 to 8), of which only the second from the
# left (event 5) leads to Clemont; the rest open into rooms with a trainer and a way back to the row. Clemont's win (switch 253)
# ends it. Map 877 is its copy for Team Flare's scene, with no trainers: the rooms are empty and door 5 leads to Xerosic (event 1)
# and the stairs up the Prism Tower.
PokeAccess::Game.define("fireash") do
  mechanic(:state, 833) do
    auto
    name [4, 5, 6, 7, 8], :fa_o_clemont_door, :numbered => true
    sent_back lambda { $game_switches[253] ? nil : :fa_o_clemont_trainer }, :events => [4, 6, 7, 8]
    sent_back lambda { $game_switches[253] ? nil : :fa_o_clemont_leader }, :events => [5]
    phase lambda { !$game_switches[253] }, :quiet => true, :hint => :fa_o_clemont_hint, :hidden => right_way(5)
    solved { $game_switches[253] }
    arrival_hint :fa_o_clemont_rule
  end

  mechanic(:state, 877) do
    auto
    name [4, 5, 6, 7, 8], :fa_o_clemont_door, :numbered => true
    sent_back :fa_o_flare_empty, :events => [4, 6, 7, 8]
    sent_back :fa_o_flare_stairs, :events => [5]
    phase lambda { !$game_self_switches[[877, 1, "A"]] }, :quiet => true, :hint => :fa_o_flare_hint, :hidden => right_way(5)
    solved { $game_self_switches[[877, 1, "A"]] }
    arrival_hint :fa_o_flare_rule
  end
end
