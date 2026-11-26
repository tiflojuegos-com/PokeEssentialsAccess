# Wispy Ruins (map 489): the boulder of event 79 pushed onto 55,56 sets switch 320, and a door opens nearby (event 81,
# a way to Wispy Chasm).
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 489, :part => :boulder) do
    auto
    phase(lambda { !$game_switches[320] }, :quiet => true,
          :track => { :event => 79, :label => :rjd_wr_boulder, :goal => [55, 56, 55, 56], :goal_label => :rjd_wr_goal })
  end
end
