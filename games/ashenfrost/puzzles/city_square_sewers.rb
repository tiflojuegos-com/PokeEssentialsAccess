# City Square Sewers (map 786): the wall switch (EV13) lowers the three spikes of column 11 (EV10 to EV12) through their
# self switch A; the spikes only shorten the way.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 786, :part => :spikes) do
    auto
    name 13, :afh_switch
    name 10..12, lambda { |ev| $game_self_switches[[786, ev.id, "A"]] ? :afh_spikes_down : :afh_spikes }, :grouped => true
  end
end
