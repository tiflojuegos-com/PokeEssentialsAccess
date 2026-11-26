# The S.S. Paradise (map 456): four floor buttons each turn on a colour for good: red (event 70, switch 1006), green
# (46, 1008), yellow (71, 1009), blue (72, 1007). Red, blue and yellow take down the laser of their colour across the
# corridor at (15 to 17; 70, 69 and 67), which hurts when walked into.
PokeAccess::Game.define("rejuvenation") do
  mechanic(:state, 456, :part => :lasers) do
    auto
    name 70, :rjg_sp_button_red
    name 46, :rjg_sp_button_green
    name 71, :rjg_sp_button_yellow
    name 72, :rjg_sp_button_blue
    name 73..75, :rjg_sp_laser_red, :grouped => true, :when => lambda { |_ev| !$game_switches[1006] }
    name 76..78, :rjg_sp_laser_blue, :grouped => true, :when => lambda { |_ev| !$game_switches[1007] }
    name 79..81, :rjg_sp_laser_yellow, :grouped => true, :when => lambda { |_ev| !$game_switches[1009] }
  end
end
