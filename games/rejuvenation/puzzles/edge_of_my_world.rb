# Edge of My World (map 617): the door drawn on the house (event 9) asks "Knock on the door?". The first two knocks get
# no answer (self switches A, then B); the third throws out the Fairy Tale field notes as event 30 (self switch C).
# Switch 2031 marks the notes read.
module PokeAccess
  module RejuvEdgeWorld
    # True once the third knock has thrown the notes out, or they have been read.
    def self.done?
      $game_self_switches[[617, 9, "C"]] || $game_switches[2031]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  edge = PokeAccess::RejuvEdgeWorld
  mechanic(:state, 617) do
    auto
    name 9, :rj_edge_door, :when => lambda { |_ev| !edge.done? }
    watch :self => [9, "C"], :say => :rj_edge_flew
    active { PokeAccess::Puzzles.assist? && !edge.done? }
    hint :rj_edge_hint
    solved(nil, :quiet => true) { edge.done? }
  end
end
