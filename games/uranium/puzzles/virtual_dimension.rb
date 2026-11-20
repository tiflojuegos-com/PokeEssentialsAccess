# The Virtual Dimension memory game (map 62): four tiles (events 3 to 6, left to right, sounding higher each) and a button
# (event 8) that starts a random sequence kept by the game's $Simon handler. Four rounds won (variable 129) open the
# corridor to the north (events 7 and 19 to 22).
module PokeAccess
  module UraniumSimon
    # The event id of the tile the player must press next, or nil while no sequence waits for the player.
    def self.next_tile
      game = $Simon
      return nil unless game && game.instance_variable_get(:@simonRunning)
      answer = game.instance_variable_get(:@simonAnswer)
      played = game.instance_variable_get(:@simonPlayer)
      return nil unless answer && played
      color = answer[played.length]
      color ? [3, 4, 5, 6][color] : nil
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 62) do
    auto
    arrival_hint :ura_po_simon_rule, :once => true
    count :ura_po_simon_rounds, :value => lambda { [$game_variables[129].to_i, 4].min }, :of => 4
    name 3..6, :ura_po_simon_tile, :numbered => true
    name 8, :ura_po_simon_button
    (3..6).each do |id|
      spot :event => id, :label => :ura_po_simon_next, :assist => true,
           :when => lambda { PokeAccess::UraniumSimon.next_tile == id }
    end
  end
end
