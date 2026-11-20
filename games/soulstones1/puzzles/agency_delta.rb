# Agency Base: Delta (maps 238 and 240): the control panels of map 238 open the gates of sectors 1 and 2 (switches 271
# and 273) and turn the electric barrier of map 240 off (switch 272, event 25); two panels of map 240 (events 38 and 39)
# turn the rotary (switch 270), which each pass through it turns too. Only the barrier stands in the way of the story,
# which ends in the north-west of map 238 (switch 9).
PokeAccess::Game.define("soulstones1") do
  barrier_hint = lambda { $game_switches[272] ? :ss1_agency_hint_north : :ss1_agency_hint_barrier }

  mechanic(:state, 238) do
    auto
    watch :switch => 272, :label => :ss1_agency_barrier, :on => :ss1_agency_barrier_off, :off => :ss1_agency_barrier_on
    name 25, :ss1_agency_barrier_panel
    name 7, :ss1_agency_gates1_panel
    name 26, :ss1_agency_gates2_panel
    spot(:event => 25, :label => :puzzle_right_way, :assist => true, :when => lambda { !$game_switches[272] })
    hint barrier_hint
    solved { $game_switches[9] }
  end

  mechanic(:state, 240) do
    auto
    watch :switch => 272, :label => :ss1_agency_barrier, :on => :ss1_agency_barrier_off, :off => :ss1_agency_barrier_on
    name [38, 39], :ss1_agency_rotary_panel
    name 40..42, :ss1_agency_barrier_wall, :when => lambda { |_ev| !$game_switches[272] }
    hint barrier_hint
    solved { $game_switches[9] }
  end
end
