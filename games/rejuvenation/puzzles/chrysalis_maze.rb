# Chrysalis Courtyard (map 391), the first trial's Soul Labyrinth: a hedge maze with one way, from the start (30,57) to
# its exit (event 19), which sets variable 679 to 3; the entrance skip (event 50) does too. Event 16 sets 679 to 2 and
# Dusknoir (event 7) then walks toward the player, sending them back to the start on touch.
module PokeAccess
  module RejuvMaze
    MAP = 391
    EXIT = 19
    DUSKNOIR = 7
    START = [30, 57]
    MAZE = [0, 57, 9, 58]

    # True until the labyrinth is crossed or skipped.
    def self.open?
      $game_variables[679].to_i < 3
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  maze = PokeAccess::RejuvMaze
  mechanic(:state, maze::MAP, :part => :maze) do
    auto
    name maze::EXIT, :rje_maze_exit, :when => lambda { |_ev| maze.open? }
    obstacle({ :events => [maze::DUSKNOIR] }, :moving => true)
    sent_back :rje_maze_caught, :to => maze::START, :events => [maze::DUSKNOIR]
    inside = at(*maze::MAZE)
    phase(lambda { maze.open? && inside.call }, :quiet => true, :hint => :rje_maze_hint)
    solved(nil, :quiet => true) { !maze.open? }
  end
end
