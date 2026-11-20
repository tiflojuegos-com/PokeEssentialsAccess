# The Rocket lab under Celadon (map 179): an electric barrier on row 7 holds Raikou, Entei and Suicune until the two
# switches with no sprite, EV15 and EV16, are both turned off (S328 and S329); then an autorun event lets the beasts run.
PokeAccess::Game.define("anil") do
  mechanic(:state, 179) do
    auto
    name [15, 16], :anil_lab_switch
    obstacle(/rayosBarrera/i, :label => :anil_bin_barrier)
    count :anil_lab_switches, :switches => [328, 329]
    hint :anil_lab_hint
    solved(nil) { $game_switches[328] && $game_switches[329] }
  end
end
