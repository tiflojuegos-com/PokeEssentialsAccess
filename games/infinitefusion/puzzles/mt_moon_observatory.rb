# Mt. Moon's observatory (maps 828 and 830): the telescopes work at night only, and its sky is a map where each hidden star
# event, once stepped, counts for its constellation (variables 301 to 308, switches 1051 to 1058 when complete, variable 320
# the constellations done). Mew (event 43) comes with all eight and karma (variable 222) of 20 or more. Mew's stars only
# answer once a telescope was used with seven constellations done (switch 1120), so the one that completes the seventh
# leaves them out of reach until the next time. During Necrozma's darkness (switches 701 and 705) a telescope used at night
# (switch 15) only says the sky is black, and leaves the player hidden and the menu locked: the assist warns as it is used.
PokeAccess::Game.define("infinitefusion") do
  constellations = [[301, :IVYSAUR, 10, (1..10).to_a], [302, :WARTORTLE, 10, (107..116).to_a],
                    [303, :ARCANINE, 10, (53..62).to_a], [304, :MACHOKE, 16, (135..150).to_a],
                    [305, :RAPIDASH, 30, (173..202).to_a + [221]], [306, :GYARADOS, 8, (227..234).to_a],
                    [307, :ARTICUNO, 10, (276..285).to_a], [308, :MEW, 10, (327..336).to_a]]
  species = lambda { |id| PokeAccess::Data.species_name(id).to_s }
  stepped = lambda { |ev| $game_self_switches[[830, ev.id, "A"]] }
  left = lambda do
    constellations.reject { |var, _s, _n, _i| $game_switches[var + 750] }
  end
  mew_locked = lambda { $game_variables[320] >= 7 && !$game_switches[1120] && !$game_switches[1058] }
  advice = lambda do
    if $game_variables[320] >= 8
      [:ifo_mew_rule, { :karma => $game_variables[222] }]
    else
      list = left.call.map { |var, id, need, _i| "#{species.call(id)} #{[need - $game_variables[var], 0].max}" }
      [mew_locked.call ? :ifo_stars_left_mew : :ifo_stars_left, { :list => list.join(", ") }]
    end
  end

  dark_sky = lambda { $game_switches[15] && $game_switches[701] && $game_switches[705] ? :ifo_telescope_dark : nil }

  mechanic(:state, 828) do
    name [9, 12], :ifo_telescope
    on_use [9, 12], dark_sky, :assist => true
  end

  mechanic(:state, 830) do
    watch :var => 320, :label => :ifo_constellations, :number => true
    constellations.each do |_var, id, _need, ids|
      label = lambda { |_ev| PokeAccess::Puzzles.assist? ? [:ifo_star_of, { :species => species.call(id) }] : :ifo_star }
      name ids, label, :when => lambda { |ev| !stepped.call(ev) }
    end
    hint advice
  end
end
