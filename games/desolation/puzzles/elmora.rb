# Echoes of Elmora (variable 189). In Elmora Village (map 399), once Lisa goes to the damaged shrine (189 at 3), the pillar
# with inscriptions (event 37, no sprite) hides a footprint beside it, which moves the quest on. In the Waterscape Temple
# (map 454) the book of symbols (event 18) can be translated with Lisa's diary (ELMORAMEMOIR) once 189 is 9, which
# takes the player to Caelum Lake.
module PokeAccess
  module DesolationElmora
    # The hint of the quest from where it stands, or nil.
    def self.hint
      v = $game_variables[189].to_i
      return :deso_elmora_pillar_hint if v == 3
      return :deso_elmora_book_hint if v >= 9
      nil
    end
  end
end

PokeAccess::Game.define("desolation") do
  elmora = PokeAccess::DesolationElmora
  mechanic(:state, 399) do
    auto
    name 37, :deso_elmora_pillar
    hint lambda { elmora.hint }
    active { $game_variables[189].to_i == 3 }
  end
  mechanic(:state, 454) do
    auto
    name 18, :deso_elmora_book
    hint lambda { elmora.hint }
    active { $game_variables[189].to_i >= 9 && $game_variables[194].to_i == 0 }
  end
end
