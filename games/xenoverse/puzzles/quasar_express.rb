# The Quasar Express (map 190): among the carriage's papers, one heap drawn with a tile (event 22) hides a switch that
# opens the door of the corridor (switch 344, event 10 of map 186). The heap is named as the papers it shows; with the
# assist, as the switch it hides, until it is pressed (its self switch A).
module PokeAccess
  module XenoQuasar
    MAP = 190
    PAPERS = 22

    # The heap's name: the switch it hides with the assist.
    def self.papers_label
      PokeAccess::Puzzles.assist? ? :xv_quasar_switch : :xv_quasar_papers
    end
  end
end

PokeAccess::Game.define("xenoverse") do
  quasar = PokeAccess::XenoQuasar
  mechanic(:state, quasar::MAP) do
    auto
    name quasar::PAPERS, lambda { |_ev| quasar.papers_label },
         :when => lambda { |_ev| !$game_self_switches[[quasar::MAP, quasar::PAPERS, "A"]] }
  end
end
