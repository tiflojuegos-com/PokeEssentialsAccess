# The hatch of Chrysalis Manor's frozen prison: three graphic-less wall inscriptions read facing them from below (map
# 391 events 3 and 55, map 390 event 41) and the panel asking for them in turn (map 390 event 40, once variable 682
# reaches 6). The core says each answer with the assist; once the hatch opens (variable 363 at 5) none matters.
module PokeAccess
  module RejuvChrysalis
    # True until the panel has opened the hatch.
    def self.shut?
      $game_variables[363].to_i < 5
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  chrysalis = PokeAccess::RejuvChrysalis
  still = lambda { |_ev| chrysalis.shut? }
  mechanic(:state, 391, :part => :passwords) do
    auto
    name [3, 55], :rj_chrysalis_inscription, :when => still
  end
  mechanic(:state, 390, :part => :passwords) do
    auto
    name 41, :rj_chrysalis_inscription, :when => still
    name 40, :rj_chrysalis_panel, :when => still
  end
end
