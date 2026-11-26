# The ground floor of the Amontillado Factory (map 561): switch EV20 lowers the spikes EV21 and switch EV22 the pair
# EV23 and EV24, each through the spikes' self switch A. The ladder up (EV31) needs neither.
PokeAccess::Game.define("ashenfrost") do
  mechanic(:state, 561, :part => :spikes) do
    auto
    name [20, 22], :afh_switch
    name [21, 23, 24], lambda { |ev| $game_self_switches[[561, ev.id, "A"]] ? :afh_spikes_down : :afh_spikes }
  end
end
