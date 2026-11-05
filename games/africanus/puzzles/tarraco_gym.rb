# Tarraco's water gym (map 112): six levers, each leaving on a group of piers over the water (switches 204 to 208) and
# putting the rest away. Reaching the leader takes a chain of them, each lever within reach once the one before has
# laid its piers: events 110, 112, 113, 115 and 117 in that order; 120, reachable only at the end, lays them all.
# The levers are numbered in reading order, so the player's lever 6 is event 110 and lever 1 is event 117. Each row
# below is the switches on, the lever that left them so, and the lever to take next (none: the leader is in reach). The
# leader's medal (switch 118) ends it: no rule on arriving, nothing on the info key.
PokeAccess::Game.define("africanus") do
  chain = [[[], nil, 6], [[205], 6, 5], [[204], 5, 4], [[206], 4, 3], [[207], 3, 1], [[206, 208], 1, nil],
           [[204, 205, 206, 207, 208], 2, nil]]
  mechanic(:state, 112) do
    auto
    name [110, 112, 113, 115, 117, 120], :af_tarraco_lever, :numbered => true
    arrival_hint :af_tarraco_rule
    solved { $game_switches[118] }
    chain.each do |on, lever, following|
      phase(lambda { [204, 205, 206, 207, 208].all? { |s| ($game_switches[s] ? true : false) == on.include?(s) } },
            :title => lever ? [:af_tarraco_on, { :n => lever }] : :af_tarraco_off,
            :hint => following ? [:af_tarraco_next, { :n => following }] : :af_tarraco_leader)
    end
  end
end
