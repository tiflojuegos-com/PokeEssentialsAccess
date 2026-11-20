# Cinnabar's gym (map 193): after Blaine's first fight (switch 60) the switch with no sprite, event 28, upstairs (switch 61)
# lets him fight again. It says its own words when stepped on, so only its name is added, while it is of use.
PokeAccess::Game.define("fireash") do
  mechanic(:state, 193) do
    auto
    name 28, :fa_lava_switch, :when => lambda { |_ev| $game_switches[60] && !$game_switches[61] }
  end
end
