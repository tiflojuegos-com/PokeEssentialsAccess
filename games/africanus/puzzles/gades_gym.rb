# Gades' rock gym (map 270): six statues that turn a quarter to the right at each Yes, and what the parallel event 22
# checks: Machop at (11, 6) and Machoke at (26, 6) face east, Machamp at (32, 6) south, Machop at (21, 22) and Machoke
# at (16, 22) west, Machamp at (5, 22) north, which switches 187 on and takes the tiles off the leader's way. Seven
# Rampardos send the player back to the entrance at (18, 32), and four Unown, M, D, I and X from west to east, spell
# the 1509 the number entry of event 24 wants.
PokeAccess::Game.define("africanus") do
  turning = [[:machop, /\A066\z/, :af_gades_machop, { [11, 6] => 6, [21, 22] => 4 }],
             [:machoke, /\A067\z/, :af_gades_machoke, { [26, 6] => 6, [16, 22] => 4 }],
             [:machamp, /\A068\z/, :af_gades_machamp, { [32, 6] => 2, [5, 22] => 8 }]]
  turning.each do |part, graphic, label, facings|
    mechanic(:facing, 270, :part => part) do
      statues graphic, label
      goals facings
    end
  end

  mechanic(:state, 270, :part => :rule) do
    arrival_hint :af_gades_rule
    solved(:af_gades_open) { $game_switches[187] }
    sent_back :af_gades_rampardos, :to => [18, 32], :events => [6, 7, 8, 11, 31, 32, 33]
  end

  mechanic(:state, 270, :part => :code) do
    [[12, "M"], [13, "D"], [15, "I"], [14, "X"]].each do |event, letter|
      name event, [:af_gades_letter, { :letter => letter }]
    end
  end
end
