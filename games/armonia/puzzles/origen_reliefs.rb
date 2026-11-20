# The hidden rooms of Pirámides Origen (maps 144 and 145): a sarcophagus asks how many statues of a Pokémon the room holds (event
# 12 of map 144, event 1 of map 145), and a wrong number throws the player out to map 36. The statues are reliefs drawn on the
# walls with the map's tiles, three kinds by their tileset: Volcarona (tiles 616), Haxorus (618) and Lucario (632), two by two.
# Each is named on the wall tile under it, where it is faced, until its room's sarcophagus opens. The core says the number with
# the assist, as the page compares it.
module PokeAccess
  module ArmoniaReliefs
    SPECIES = { :v => :VOLCARONA, :h => :HAXORUS, :l => :LUCARIO }
    # Each room's sarcophagus and its statues by kind, as the bottom left tile of each.
    ROOMS = {
      144 => [12, { :v => [[6, 5], [51, 5], [67, 5], [10, 19], [27, 19], [30, 19], [43, 19], [63, 19]],
                    :h => [[22, 5], [43, 5], [75, 5], [14, 19], [22, 19], [39, 19], [47, 19], [67, 19]],
                    :l => [[14, 5], [35, 5], [59, 5], [18, 19], [35, 19], [71, 19]] }],
      145 => [1, { :v => [[18, 4], [7, 19], [18, 19], [55, 19], [7, 34], [34, 34], [55, 34], [2, 49], [18, 49], [39, 49]],
                   :h => [[7, 4], [50, 4], [2, 19], [23, 19], [39, 19], [50, 19], [18, 34], [39, 34], [50, 34], [7, 49], [55, 49]],
                   :l => [[2, 4], [23, 4], [55, 4], [34, 19], [2, 34], [23, 34], [23, 49], [34, 49], [50, 49]] }]
    }

    # The name of a statue of one kind, by the game's own name of its Pokémon.
    def self.label(kind)
      [:arm_origen_relief, { :name => PokeAccess::Data.species_name(SPECIES[kind]).to_s }]
    end
  end
end

PokeAccess::Game.define("armonia") do
  PokeAccess::ArmoniaReliefs::ROOMS.each do |map, (sarcophagus, statues)|
    mechanic(:state, map) do
      auto
      open = lambda { !$game_self_switches[[map, sarcophagus, "A"]] }
      statues.each do |kind, tiles|
        tiles.each { |at| spot(:at => at, :label => lambda { PokeAccess::ArmoniaReliefs.label(kind) }, :when => open) }
      end
    end
  end
end
