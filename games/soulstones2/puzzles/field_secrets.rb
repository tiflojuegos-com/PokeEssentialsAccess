# Small secrets and searches of Soulstones 2 that the player works one event at a time:
# - Caverns of Rhea (map 337): five buttons by white crystals (events 54 to 58) add to V110; at 5 S75 opens a passage on the
#   level below (map 338), where the Impeding Rock goes. The buttons are secret: what they are is said with the assist.
# - Route 23C (map 276): four damaged wards (events 48 to 50 and 51) in the route's corners, live from V218 13 (quest
#   "Treasure Hunters"), each restored facing down and adding to V218; at 17 the game sends the player back to Ormus.
# - Orion City West (map 157): the switch in a park bin (event 26) opens the hidden stairwell to Orion Underground.
# - Underwater Temple (maps 325 to 327): altars answered facing up add to V128, which opens the stairs between floors.
# - Norma Town (map 350): while the quest "Watt's the Problem" runs (V264 1 to 8) eight street lights (events 39 to 51) lose
#   their glow, and each one set right after its fight adds to V264.
module PokeAccess
  module SS2Secrets
    ALTARS = { 325 => [14], 326 => [5, 11, 17], 327 => [4, 10, 16] }
    LAMPS = [39, 40, 42, 43, 44, 49, 50, 51]

    # True once an event of this map has done its part: its self switch A.
    def self.done?(ev)
      $game_self_switches[[$game_map.map_id, ev.id, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, 337) do
    auto
    name((54..58).to_a, lambda { PokeAccess::Puzzles.assist? ? :ss2_pz_rhea_button : :ss2_pz_rhea_crystals },
         :when => lambda { |ev| !$game_switches[75] && !PokeAccess::SS2Secrets.done?(ev) })
    count :ss2_pz_rhea_buttons, :var => 110, :of => 5, :assist => true
    active { !$game_switches[75] }
    solved { $game_switches[75] }
  end

  mechanic(:state, 276) do
    auto
    name((48..51).to_a, :ss2_pz_ward,
         :when => lambda { |ev| $game_variables[218] >= 13 && !PokeAccess::SS2Secrets.done?(ev) })
    count :ss2_pz_wards, :var => 218, :from => 13, :of => 4
    active { $game_variables[218] >= 13 && $game_variables[218] < 17 }
    solved { $game_variables[218] >= 17 }
  end

  mechanic(:state, 157) do
    auto
    name 26, lambda { |ev| PokeAccess::Puzzles.assist? && !PokeAccess::SS2Secrets.done?(ev) ? :ss2_pz_orion_bin : nil },
         :when => lambda { |ev| PokeAccess::Puzzles.assist? && !PokeAccess::SS2Secrets.done?(ev) }
  end

  mechanic(:state, 350) do
    auto
    name PokeAccess::SS2Secrets::LAMPS, :ss2_pz_norma_lamp,
         :when => lambda { |ev| $game_variables[264] >= 1 && $game_variables[264] < 9 && !PokeAccess::SS2Secrets.done?(ev) }
  end

  PokeAccess::SS2Secrets::ALTARS.each do |map, ids|
    mechanic(:state, map) do
      auto
      name ids, :ss2_pz_altar, :when => lambda { |ev| !PokeAccess::SS2Secrets.done?(ev) }
      count :ss2_pz_altars, :selfs => [ids, "A", map], :announce => false
    end
  end
end
