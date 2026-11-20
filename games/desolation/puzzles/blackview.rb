# Blackview, on the way to Emily. The Trade Center (map 202): once the scene shuts the remote gate (event 1, switch 385), a
# switch on a table to the west (event 5, no sprite) moves the front desk panel and opens it (switch 384). The Power Plant
# (map 205): eight plates in two groups of four (north round 24,19; south round 24,26) push the player two tiles, one
# diagonal and one straight, to one side or the other by switch 388, which each plate flips (leaving by the door puts it
# off); the terminal to the west (event 24, switch 389) lifts the barrier between
# the groups. The plan below was checked against each plate's two pages: east plate of the south group, terminal, west
# plate of the south group twice, south plate of the north group, then, round the north, its west plate with 388 off or
# its east plate with 388 on, either of which leaves the player in the niche before Emily's door (event 45). The map draws
# the plates whatever 388 holds. In the city (map 136) Jarred's five appliances take a Rotom of the party
# each (switches 791 to 795), and in the Rangers Guild (map 169) Majira's logs (events 2, 4 and 5) are read in turn.
module PokeAccess
  module DesolationBlackview
    PLATES = { 3 => :deso_plant_plate_north_west, 4 => :deso_plant_plate_north_east, 5 => :deso_plant_plate_north_top,
               9 => :deso_plant_plate_north_bottom, 18 => :deso_plant_plate_south_west, 14 => :deso_plant_plate_south_east,
               12 => :deso_plant_plate_south_top, 16 => :deso_plant_plate_south_bottom }

    # The plant's next step with the assist, by the terminal, the plates' switch and where the player stands.
    def self.plant_hint
      x = $game_player.x
      y = $game_player.y
      return :deso_plant_door if y <= 17 && x >= 24 && x <= 25
      return ($game_switches[388] ? :deso_plant_step_north_east : :deso_plant_step_north_west) if y <= 19
      return :deso_plant_step_south_east if x >= 26
      return :deso_plant_step_terminal unless $game_switches[389]
      return :deso_plant_step_north_bottom if y <= 24 && x >= 23 && x <= 25
      $game_switches[388] ? :deso_plant_step_south_west_back : :deso_plant_step_south_west_up
    end
  end
end

PokeAccess::Game.define("desolation") do
  bv = PokeAccess::DesolationBlackview
  mechanic(:state, 202) do
    auto
    name 5, :deso_trade_switch, :when => lambda { |_ev| !$game_switches[384] }
    name 1, :deso_trade_gate, :when => lambda { |_ev| $game_switches[385] && !$game_switches[384] }
    hint :deso_trade_hint
    active { $game_switches[385] && !$game_switches[384] }
    solved { $game_switches[384] }
  end
  mechanic(:state, 136) do
    auto
    [[52, :deso_rotom_fan], [54, :deso_rotom_mower], [56, :deso_rotom_fridge], [59, :deso_rotom_microwave],
     [61, :deso_rotom_washer]].each { |id, key| name id, key }
  end
  mechanic(:state, 169) do
    auto
    name [2, 4, 5], :deso_majira_log
  end
  mechanic(:state, 205) do
    auto
    watch :switch => 389, :quiet => true
    bv::PLATES.each { |id, key| name id, key }
    name 24, :deso_plant_terminal, :when => lambda { |_ev| !$game_switches[389] }
    hint lambda { bv.plant_hint }
    solved { $game_switches[396] }
  end
end
