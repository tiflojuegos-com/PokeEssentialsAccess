# Legend sites with switches to find: the three of the Kanto Power Plant (map 724: switches 734 to 736, stepped on,
# each turning something off), the four seals of the Primeval Forest (map 530: var 243; at 4 the autorun event 16
# opens the way into Goran Cave, switch 1287), the rock of Goran Cave that collapses to open a far passage (map 539,
# event 8, switch 1291), and the three buttons hidden on statues of the Sinister Swamp (map 791: var 152, each pressed
# only facing up; at 3 a flame lights at the graves, switch 778). The game never shows how many the plant and the swamp
# want, so their counts and places go with the assist alone.
module PokeAccess
  module EmLegendSites
    PLANT = { 12 => [734, [38, 24]], 19 => [735, [44, 12]], 22 => [736, [21, 17]] }
    SWAMP = { 87 => [100, 4], 88 => [39, 8], 94 => [44, 35] }

    # Whether the swamp button id has been pressed: the first by its own switch, the others by their self switch.
    def self.pressed?(id)
      return $game_switches[777] if id == 87
      $game_self_switches[[791, id, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("emerald") do
  site = PokeAccess::EmLegendSites
  mechanic(:state, 724) do
    auto
    name site::PLANT.keys, :em_plant_switch, :when => lambda { |ev| !$game_switches[site::PLANT[ev.id][0]] }
    count :em_plant_count, :switches => [734, 735, 736], :assist => true
    hint :em_plant_hint
    solved { [734, 735, 736].all? { |sw| $game_switches[sw] } }
  end

  mechanic(:state, 530) do
    auto
    name [1, 2, 12, 40], :em_seal
    count :em_seals_count, :var => 243, :of => 4, :hide_zero => true
    solved(:em_seals_open) { $game_switches[1287] }
  end

  mechanic(:state, 539) do
    auto
    name 8, :em_goran_rock, :when => lambda { |_ev| !$game_switches[1291] }
    solved(nil, :quiet => true) { $game_switches[1291] }
  end

  mechanic(:state, 791) do
    auto
    name site::SWAMP.keys, :em_swamp_button, :assist => true, :when => lambda { |ev| !site.pressed?(ev.id) }
    count :em_swamp_count, :var => 152, :of => 3, :assist => true, :hide_zero => true
    hint :em_swamp_hint
    solved { $game_switches[778] }
  end
end
