# Vitro's gym of Mahogany (map 75): an ice floor to slide across, and two pads (events 4 and 5) that join its two sides, the first
# at the top left to the bottom right, the second back. Fredo waits at the top right; switch 10 is the badge.
PokeAccess::Game.define("vitro") do
  mechanic(:state, 75) do
    name [4, 5], :vitro_mahogany_pad
    phase lambda { true }, :title => :vitro_mahogany_ice, :quiet => true, :hint => :vitro_mahogany_hint
    solved { $game_switches[10] }
    sent_back :vitro_mahogany_to_south, :to => [25, 22], :events => 4
    sent_back :vitro_mahogany_to_north, :to => [7, 2], :events => 5
    arrival_hint :vitro_mahogany_rule
  end
end
