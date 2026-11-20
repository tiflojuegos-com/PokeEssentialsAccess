# The wire puzzle of Urayne (map 250) and of the Memory Banks A, B and C (maps 268 to 270), run by the game's WirePuzzle
# (0223_Wire Puzzle): the player walks over floor tiles to draw a wire from a node named WireStart<circuit> to a node named
# WireEnd<circuit>, and the game lights the end only when a chain of tiles of that colour joins them. Nodes are named by the
# circuit; the wire reset panels have a name of their own. The info key says how many ends are joined, and the circuit being
# drawn; the free camera, the circuit of each tile with a wire. Nothing here writes to the game: its tables are only read.
module PokeAccess
  module UraniumWire
    # A node's name in the game: Wire, Start or End, and the circuit's letter, with what an end switches after a colon.
    def self.node_pattern; /(?:\A|;)Wire(Start|End)([A-D])(?::|;|\z)/; end

    # The maps with wires, and on each the events whose page resets or erases them.
    def self.panels
      { 250 => [], 268 => [15, 29], 269 => [20, 36], 270 => [1] }
    end

    # The maps whose whole room is the puzzle; elsewhere the puzzle is the nodes' surroundings.
    def self.rooms; [268, 269, 270]; end

    # How many tiles around the nodes still count as the puzzle's area.
    def self.margin; 6; end

    # The script lines an event's live page runs from the action button.
    def self.active_scripts(event)
      return [] unless PokeAccess.ivar(event, :@trigger) == 0
      list = PokeAccess.ivar(event, :@list)
      return [] unless list.is_a?(Array)
      list.map { |command| PokeAccess::Routes::Effects.script_of(command) }
    end

    # The name of a node by its circuit and whether it starts or ends it.
    def self.node_name(event)
      match = node_pattern.match(event.name.to_s)
      [match[1] == "Start" ? :ura_wire_start : :ura_wire_end, { :circuit => match[2] }]
    end

    # Whether the event's live page starts that circuit's wire: before, the node is still the memory it holds.
    def self.node?(event)
      match = node_pattern.match(event.name.to_s)
      return false unless match
      script = /\A\s*WirePuzzle\.setColor\(\s*:#{match[2]}\s*\)\s*;?\s*\z/
      active_scripts(event).any? { |line| line =~ script }
    end

    # Whether the event's live page resets or erases the wires.
    def self.panel?(event)
      active_scripts(event).any? { |line| line =~ /\A\s*WirePuzzle\.(?:resetWires|setColor\(\s*:Erace)/ }
    end

    # The events whose name holds a node.
    def self.node_events
      return [] unless $game_map
      $game_map.events.values.select { |event| event.name.to_s =~ node_pattern }
    end

    # Whether the player stands in the box of the map's nodes and a margin around.
    def self.near?
      events = node_events
      return false if events.empty? || !$game_player
      xs = events.map { |event| event.x }
      ys = events.map { |event| event.y }
      $game_player.x.between?(xs.min - margin, xs.max + margin) && $game_player.y.between?(ys.min - margin, ys.max + margin)
    end

    # Whether the game has the puzzle set up on this map: its tables hold the wires drawn until the map is left.
    def self.mounted?
      !table(:@@wireStates).nil?
    end

    # Whether the map's wire puzzle answers: its room, its surroundings, or the game's tables standing, unless solved.
    def self.live?
      return false unless $game_map && panels.key?($game_map.map_id) && !solved?
      rooms.include?($game_map.map_id) || near? || mounted?
    end

    # The self switches the map's ends name, as [event id, letter] ("S" being the end's own event).
    def self.switch_keys
      node_events.map do |event|
        event.name.to_s.split(";").map do |part|
          next [] unless part =~ /\AWireEnd[A-D]:(.+)\z/
          $1.split(":").map { |item| item =~ /\A(S|\d+)([A-D])\z/ ? [$1 == "S" ? event.id : $1.to_i, $2] : nil }.compact
        end
      end.flatten(2).uniq
    end

    # Whether every switch the ends name is on: the game keeps them after it empties its tables on leaving the map.
    def self.solved?
      keys = switch_keys
      !keys.empty? && keys.all? { |id, letter| $game_self_switches[[$game_map.map_id, id, letter]] }
    end

    # The rule, said on arriving at the map where the whole room is the puzzle and, elsewhere, while near the nodes.
    def self.rule
      near? || rooms.include?($game_map.map_id) ? :ura_wire_rule : nil
    end

    # A class variable of the game's WirePuzzle, or nil while it is not there.
    def self.table(name)
      return nil unless defined?(::WirePuzzle)
      ::WirePuzzle.send(:class_variable_get, name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # How many wire ends the map's nodes name, as the game counts them.
    def self.total
      return 0 unless $game_map && panels.key?($game_map.map_id)
      $game_map.events.values.inject(0) do |sum, event|
        sum + event.name.to_s.split(";").select { |part| part =~ /\AWireEnd[A-D]:/ }.length
      end
    end

    # Whether the wires drawn so far join the end at (x, y) to a start of its colour. The game stops its own check at the
    # first end left open, so each end is checked here by itself.
    def self.joined?(color, x, y)
      starts = table(:@@startPoints)
      return false unless starts.is_a?(Array)
      (starts[color] || []).any? do |point|
        point != [x, y] && ::WirePuzzle.checkConnection(point, [x, y], color)
      end
    end

    # The four steps of the game's search as [RPG direction code, dx, dy].
    def self.directions; [[8, 0, -1], [2, 0, 1], [4, -1, 0], [6, 1, 0]]; end

    # The cells around one, as [direction code, x, y].
    def self.around(cell)
      directions.map { |code, dx, dy| [code, cell[0] + dx, cell[1] + dy] }
    end

    # Whether a cell touches a node, the way the game's search reaches an end.
    def self.beside?(cell, node)
      (cell[0] - node[0]).abs + (cell[1] - node[1]).abs == 1
    end

    # The cheapest path of cells from one beside the start to the first beside the end, over the cells in cost (a hash of
    # [x, y] to the price of stepping on it); nil when there is none.
    def self.cheapest(cost, from, to)
      best = {}
      before = {}
      open = []
      around(from).each do |code, x, y|
        next unless cost[[x, y]]
        best[[x, y]] = cost[[x, y]]
        open.push([x, y])
      end
      closed = {}
      until open.empty?
        cell = open.min_by { |c| best[c] }
        open.delete(cell)
        closed[cell] = true
        return path_to(cell, before) if beside?(cell, to)
        around(cell).each do |code, x, y|
          step = [x, y]
          next unless cost[step] && !closed[step]
          price = best[cell] + cost[step]
          next unless best[step].nil? || price < best[step]
          best[step] = price
          before[step] = cell
          open.push(step) unless open.include?(step)
        end
      end
      nil
    end

    # The cells from the first of a search to the one given, following where each came from.
    def self.path_to(cell, before)
      path = [cell]
      path.unshift(before[path.first]) while before[path.first]
      path
    end

    # The wires, a path of cells per circuit [letter, start, end] with no cell shared, over the free cells (a hash keyed by
    # [x, y]); each runs from a cell beside its start to the first cell beside its end. The circuits take their cheapest
    # path in turn, a cell costing more for each other wire on it and for each round it has been fought over, until none is
    # shared; nil when that does not happen in a few hundred rounds.
    def self.solve(free, circuits)
      history = {}
      uses = {}
      paths = {}
      present = 0.6
      free.each_key { |cell| history[cell] = 0.0; uses[cell] = 0 }
      300.times do
        circuits.each do |letter, from, to|
          (paths[letter] || []).each { |cell| uses[cell] -= 1 }
          cost = {}
          free.each_key { |cell| cost[cell] = (1.0 + history[cell]) * (1.0 + present * uses[cell]) }
          paths[letter] = cheapest(cost, from, to)
          return nil unless paths[letter]
          paths[letter].each { |cell| uses[cell] += 1 }
        end
        shared = uses.select { |cell, n| n > 1 }.map { |cell, n| cell }
        return paths if shared.empty?
        shared.each { |cell| history[cell] += 0.5 }
        present *= 1.3
      end
      nil
    end

    # A path's steps as RPG direction codes, one per move from cell to cell.
    def self.moves(path)
      (1...path.length).map do |i|
        dx = path[i][0] - path[i - 1][0]
        dy = path[i][1] - path[i - 1][1]
        dy < 0 ? 8 : dy > 0 ? 2 : dx < 0 ? 4 : 6
      end
    end

    # The map's wire cells around the nodes, as the game finds them: those with the tile the template event's first page
    # draws, in any layer. A hash keyed by [x, y].
    def self.wire_cells
      template = $game_map.events.values.find { |event| event.name == "WireTemplate" }
      events = node_events
      return {} if template.nil? || events.empty?
      tile = template.tile_id
      xs = events.map { |event| event.x }
      ys = events.map { |event| event.y }
      cells = {}
      [xs.min - margin, 0].max.upto([xs.max + margin, $game_map.width - 1].min) do |x|
        [ys.min - margin, 0].max.upto([ys.max + margin, $game_map.height - 1].min) do |y|
          cells[[x, y]] = true if (0...3).any? { |z| $game_map.data[x, y, z] == tile }
        end
      end
      cells
    end

    # The free camera's line on a tile with a wire drawn: its circuit, the letter whose self switch the game's
    # setEventColor turns on for the wire segment there; nil on any other tile.
    def self.cell_line(x, y)
      segment = PokeAccess::World::Events.at(x, y).map { |rec| rec.ev }.find { |ev| ev.name.to_s == "WireSegment" }
      return nil unless segment
      letter = %w[A B C D].find { |l| $game_self_switches[[$game_map.map_id, segment.id, l]] }
      letter ? PokeAccess::I18n.t(:ura_wire_cell, :circuit => letter) : nil
    end

    # The map's circuits as [letter, start, end], each with a single start and a single end, in letter order.
    def self.circuits
      nodes = {}
      node_events.each do |event|
        event.name.to_s.split(";").each do |part|
          next unless part =~ /\AWire(Start|End)([A-D])(?::|\z)/
          (nodes[[$2, $1]] ||= []).push([event.x, event.y])
        end
      end
      %w[A B C D].map do |letter|
        from = nodes[[letter, "Start"]]
        to = nodes[[letter, "End"]]
        from && to && from.length == 1 && to.length == 1 ? [letter, from[0], to[0]] : nil
      end.compact
    end

    # The game's number for a circuit's colour.
    def self.color_of(letter); "ABCD".index(letter) + 1; end

    # How to draw the circuits still to join: [paths by letter, those circuits, whether the wires drawn have to be erased].
    # The wires of the circuits already joined stay where they are; nil when there is nothing to draw or no way found.
    def self.plan
      all = circuits
      cells = wire_cells
      return nil if all.empty? || cells.empty?
      open = all.reject { |letter, from, to| joined?(color_of(letter), to[0], to[1]) }
      return nil if open.empty?
      states = table(:@@wireStates)
      free = cells.dup
      if states.respond_to?(:[])
        (all - open).each { |letter, from, to| free.delete_if { |cell, free_cell| states[cell[0], cell[1]] == color_of(letter) } }
      end
      key = [free.keys.sort, open]
      unless @plan_key == key
        @plan_key = key
        paths = solve(free, open)
        redone = paths ? nil : solve(cells, all)
        @plan = paths ? [paths, open, false] : (redone ? [redone, all, !panels[$game_map.map_id].empty?] : nil)
      end
      @plan
    end

    # Each circuit still to join as the first tile beside its start and the steps from there, over the tiles; with the
    # wires in the way, the order to erase them first where the map has a panel to do it: elsewhere the game paints over
    # any colour, so the whole layout is just drawn again. Empty while there is no way found.
    def self.hint
      found = plan
      return "" unless found
      paths, circuits, erase = found
      lines = circuits.map do |letter, from, to|
        path = paths[letter]
        side = PokeAccess::Routes::Text.side(moves([from, path.first]).first)
        PokeAccess::I18n.t(:ura_wire_path, :circuit => letter, :side => side,
                           :steps => PokeAccess::Routes::Text.steps(moves(path)))
      end
      lines.unshift(PokeAccess::I18n.t(:ura_wire_redo)) if erase
      PokeAccess.sentences(lines)
    end

    # The line for the info key: the circuit being drawn, and how many ends are joined.
    def self.status
      count = total
      return nil if count == 0
      states = table(:@@endPointStates)
      joined = states.is_a?(Hash) ? states.keys.select { |node| joined?(*node) }.length : 0
      line = PokeAccess::I18n.t(:ura_wire_connections, :connected => joined, :total => count)
      color = table(:@@currentColor)
      return line unless color.is_a?(Integer) && color.between?(1, 4)
      PokeAccess.sentences([PokeAccess::I18n.t(:ura_wire_drawing, :circuit => %w[A B C D][color - 1]), line])
    end
  end
end

PokeAccess::Game.define("uranium") do
  PokeAccess::UraniumWire.panels.each do |map, panels|
    mechanic(:state, map, :part => :wire) do
      auto
      name(PokeAccess::UraniumWire.node_pattern, lambda { |ev| PokeAccess::UraniumWire.node_name(ev) },
           :when => lambda { |ev| PokeAccess::UraniumWire.node?(ev) })
      name(panels, :ura_wire_erase, :when => lambda { |ev| PokeAccess::UraniumWire.panel?(ev) }) unless panels.empty?
      arrival_hint lambda { PokeAccess::UraniumWire.rule }, :once => PokeAccess::UraniumWire.rooms.include?(map)
      solved(nil) { PokeAccess::UraniumWire.solved? }
      active { PokeAccess::UraniumWire.live? }
      info { PokeAccess::UraniumWire.status }
      hint lambda { PokeAccess::UraniumWire.hint }
    end
  end
  camera_tile(:maps => PokeAccess::UraniumWire.panels.keys) { |x, y| PokeAccess::UraniumWire.cell_line(x, y) }
end
