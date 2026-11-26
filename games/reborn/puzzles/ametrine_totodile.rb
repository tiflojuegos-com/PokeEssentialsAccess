# Ametrine Mountain B2F (map 377): with switch 414 on, the Totodile (event 16) hides on a random tile (x 10 to 15, y 16
# to 19) as an action with no graphic, answered from its tile with the action button; a reload leaves it at (12, 17).
# Variable 186 is 1 while it hides and 2 once caught; Blindstep (2226) draws it. Its tile is said with the assist.
module PokeAccess
  module RebornAmetrineTotodile
    MAP = 377
    TOTODILE = 16
    HIDING = 186
    BLINDSTEP = 2226

    # True while the Totodile hides unseen.
    def self.hiding?
      $game_variables[HIDING].to_i == 1 && !$game_switches[BLINDSTEP]
    end

    # The tile the Totodile hides on, or nil.
    def self.tile
      ev = $game_map.events[TOTODILE]
      ev && hiding? ? [ev.x, ev.y] : nil
    end
  end
end

PokeAccess::Game.define("reborn") do
  am = PokeAccess::RebornAmetrineTotodile
  mechanic(:state, am::MAP, :part => :totodile) do
    auto
    hide am::TOTODILE, :when => lambda { |_ev| am.hiding? }
    spot(:at => lambda { am.tile }, :label => :rbj_am_totodile, :assist => true, :onto => true,
         :when => lambda { am.hiding? })
    solved(nil, :quiet => true) { $game_variables[am::HIDING].to_i >= 2 }
  end
end
