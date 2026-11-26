# Ashen Frost's Maze House (map 771, Case Twenty): variable 345 is the tour, each talk with the owner (EV31, then EV32,
# EV33, EV35, EV36, EV37) adding 1. At 6 the last room's east door (EV29) sets 7 and the owner at the entrance (EV40)
# ends the house at 8, counting it in variable 353. The assist says who or what is next.
module PokeAccess
  module AshenMazeHouse
    MAP = 771
    TOUR = 345
    OWNERS = { 1 => 32, 2 => 33, 3 => 35, 4 => 36, 5 => 37 }
    LAST_DOOR = 29
    FINAL_OWNER = 40

    # The tour's value.
    def self.tour
      $game_variables[TOUR].to_i
    end

    # The event the tour waits on now, or nil.
    def self.next_id
      v = tour
      return OWNERS[v] if OWNERS[v]
      return LAST_DOOR if v == 6
      v == 7 ? FINAL_OWNER : nil
    end

    # Where the event the tour waits on stands, or nil.
    def self.target
      ev = next_id && $game_map.events[next_id]
      ev ? [ev.x, ev.y] : nil
    end

    # The assist's line for the tour's step.
    def self.hint
      id = next_id
      return nil unless id
      return :afd_maze_door if id == LAST_DOOR
      id == FINAL_OWNER ? :afd_maze_final : :afd_maze_owner
    end

    # The spot's name for the tour's step.
    def self.target_label
      next_id == LAST_DOOR ? :afd_maze_door_spot : :afd_maze_owner_spot
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  maze = PokeAccess::AshenMazeHouse
  mechanic(:state, maze::MAP, :part => :afd_maze) do
    auto
    spot :at => lambda { maze.target }, :label => lambda { maze.target_label }, :assist => true
    hint lambda { maze.hint }
    active { maze.tour < 8 }
    solved(nil, :quiet => true) { maze.tour >= 8 }
  end
end
