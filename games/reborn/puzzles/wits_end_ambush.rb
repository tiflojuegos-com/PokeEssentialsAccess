# Castle at Wit's End (map 698), the last hall of both ways (RebornWitsEnd::HALL): a floor column, x 34 (events 86 to
# 91, switch 877) or x 36 (80 to 85, with variable 362 from 1), has Lin's knight Rylin knock the player out and carry
# them to Tower Corybantia with variable 381 at 3, so the far door and the hole beyond (event 79) are never reached.
module PokeAccess
  module RebornWitsEndAmbush
    COLUMNS = [80, 81, 82, 83, 84, 85, 86, 87, 88, 89, 90, 91]
  end
end

PokeAccess::Game.define("reborn") do
  ambush = PokeAccess::RebornWitsEndAmbush
  castle = PokeAccess::RebornWitsEnd
  mechanic(:state, castle::MAP, :part => :ambush) do
    auto
    name ambush::COLUMNS, :rbk_castle_ambush, :assist => true, :grouped => true
    hint :rbk_castle_ambush_hint
    active { PokeAccess::Puzzles.assist? && castle.in_hall? }
  end
end
