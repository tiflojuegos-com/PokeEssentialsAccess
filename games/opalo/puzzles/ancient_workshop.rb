# Opalo's Ancient Workshop: the energy nodes of the annex (map 152), the room whose floor changes once the power is back
# (358), the maze of pushing tiles and platforms (357) and the message terminals (359). The floor part counts as solved while
# the power is off, so its rule is told once, when the power is back. The four terminals read (variable 180) open the exit of
# the messages room and end its rule and its count.
module PokeAccess
  # What the tiles of the maze do, read off the live page of each event.
  module OpaloMaze
    STEPS = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1] }

    # A tile's name, with where it takes the player, as a shift from its own tile, when the puzzle assist is on.
    def self.label(ev)
      list = PokeAccess.ivar(ev, :@list)
      list = [] unless list.is_a?(Array)
      jump = landing(list, ev)
      push = jump ? nil : pushed(list)
      return :op_wk_tile unless jump || push
      return(jump ? :op_wk_platform : :op_wk_pusher) unless PokeAccess::Puzzles.assist?
      [jump ? :op_wk_platform_to : :op_wk_pusher_to, { :to => phrase(jump || push) }]
    end

    # The shift of a transfer to a spot of this map, or nil.
    def self.landing(list, ev)
      cmd = list.find { |c| c.code == 201 && c.parameters[0] == 0 && c.parameters[1] == $game_map.map_id }
      cmd ? [cmd.parameters[2] - ev.x, cmd.parameters[3] - ev.y] : nil
    end

    # The shift of the steps a page gives the player, or nil with none.
    def self.pushed(list)
      dx = 0
      dy = 0
      list.each do |cmd|
        next unless cmd.code == 209 && cmd.parameters[0] == -1
        cmd.parameters[1].list.each do |move|
          step = STEPS[move.code]
          next unless step
          dx += step[0]
          dy += step[1]
        end
      end
      dx == 0 && dy == 0 ? nil : [dx, dy]
    end

    # A shift said as the step guide says a leg.
    def self.phrase(shift)
      PokeAccess::Puzzles.offset_phrase(shift[0], shift[1])
    end
  end

  # The message terminals of map 359.
  module OpaloTerminals
    # A terminal's name, with whether its self switch A says it was read.
    def self.label(ev)
      $game_self_switches[[$game_map.map_id, ev.id, "A"]] ? :op_wk_terminal_read : :op_wk_terminal
    end
  end
end

PokeAccess::Game.define("opalo") do
  mechanic(:state, 152) do
    auto
    name [1, 6, 7], :op_wk_node
    count :op_wk_nodes, :var => 188, :of => 3, :announce => false
    active { $game_variables[188] < 3 }
    hint :op_wk_nodes_hint
  end

  mechanic(:state, 358, :part => :floor) do
    auto
    solved { !$game_switches[642] }
    active { $game_switches[642] }
    arrival_hint :op_wk_floor, :once => true
  end

  mechanic(:state, 358, :part => :nodes) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? && $game_variables[179] >= 11 && !$game_switches[642] },
          :title => :op_wk_nodes_title, :quiet => true, :hint => :op_wk_door_hint
  end

  mechanic(:state, 357) do
    watch :switch => 639, :label => :op_wk_lever, :quiet => true
    controls
    on_use 60, :op_wk_lever_said, :assist => true
    name [12..24, 64], lambda { |ev| PokeAccess::OpaloMaze.label(ev) }
    name 25..59, lambda { |ev| PokeAccess::OpaloMaze.label(ev) }
    arrival_hint :op_wk_maze_rule
    active { true }
    hint :op_wk_maze_hint
  end

  mechanic(:state, 359) do
    name [17, 18, 20, 22], lambda { |ev| PokeAccess::OpaloTerminals.label(ev) }
    count :op_wk_messages, :var => 180, :of => 4
    arrival_hint :op_wk_messages_rule
    solved { $game_variables[180] >= 4 }
  end
end
