# Sario Town's gate (map 222, after the League): five pillars (events 31 and 33 to 36) each take their stone, counted by
# variable 188, and the fifth opens the hole (event 32, switch 796). The hole leads to another dimension with Cellance at the
# front of the party at midday or midnight (switches 773 and 774), or else with the Ballance Crystal in the bag; switches 797
# to 799 mark the three ways done.
PokeAccess::Game.define("solarlight") do
  mechanic(:state, 222) do
    auto
    [[31, :solar_sario_earth], [33, :solar_sario_core], [34, :solar_sario_sea], [35, :solar_sario_volt],
     [36, :solar_sario_wind]].each do |id, kind|
      name id, lambda { |_ev| [:solar_sario_pillar, { :stone => PokeAccess::I18n.t(kind) }] }
    end
    name 32, :solar_sario_hole
    count :solar_sario_stones, :var => 188, :of => 5
    phase lambda { $game_switches[796] }, :quiet => true, :hint => :solar_sario_hint
    solved { $game_switches[797] && $game_switches[798] && $game_switches[799] }
  end
end
