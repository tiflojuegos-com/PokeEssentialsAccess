# Boulder Phase in Storage Facility B3 (map 781): once the old man (event 20) is helped, the boulder (event 21) goes on
# (7, 12), below the door (7, 11); his "It's stuck!" (event 22) puts it back on (6, 29). Self switch B of event 23 ends
# it.
module PokeAccess
  module AshenBoulderPhase
    MAP = 781
    DOOR = [7, 11]
    GOAL = [7, 12, 7, 12]

    # Whether a self switch of an event of the map is on.
    def self.self?(id, letter)
      $game_self_switches[[MAP, id, letter]] ? true : false
    end

    # True while the old man waits for the boulder: helped, and the boulder not yet in place.
    def self.waiting?
      self?(20, "A") && !self?(23, "B")
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  bp = PokeAccess::AshenBoulderPhase
  mechanic(:state, bp::MAP, :part => :boulder) do
    auto
    phase lambda { bp.waiting? }, :title => :afg_bp_title,
                                  :spots => [{ :at => bp::DOOR, :label => :afg_bp_door }],
                                  :track => { :event => 21, :label => :afg_bp_boulder, :goal => bp::GOAL,
                                              :goal_label => :afg_bp_goal }
    solved(nil, :quiet => true) { bp.self?(23, "B") }
    active { bp.waiting? }
  end
end
