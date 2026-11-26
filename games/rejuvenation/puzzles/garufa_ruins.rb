# Cubi Excellus (map 107), Garufa Ruins: Pokémon statues pushed one tile the way the player faces onto yellow tiles.
# The parallel event 7 checks exact tiles in two rooms (variable 514 at 2 and 4: statues 4 to 6, then 34 to 38) and
# lifts a seal. A blocked push is lost and leaving the room puts the statues back, so the plans are searched from START.
module PokeAccess
  module RejuvGarufa
    MAP = 107
    DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    START = { 4 => [13, 13], 5 => [8, 13], 6 => [11, 10], 34 => [37, 46], 35 => [34, 44], 36 => [33, 39],
              37 => [37, 42], 38 => [39, 43] }
    # [statue, facing of the push, tile the player pushes from], in order.
    PLAN_1 = [[4, 4, [14, 13]], [4, 4, [13, 13]], [4, 4, [12, 13]], [4, 4, [11, 13]], [4, 8, [9, 14]], [4, 4, [10, 12]],
              [5, 6, [7, 13]], [4, 8, [8, 13]], [5, 6, [8, 13]], [5, 6, [9, 13]], [6, 2, [11, 9]], [6, 6, [10, 11]],
              [6, 6, [11, 11]]]
    PLAN_2 = [[34, 4, [38, 46]], [34, 4, [37, 46]], [34, 4, [36, 46]], [36, 6, [32, 39]], [36, 6, [33, 39]],
              [36, 6, [34, 39]], [36, 2, [36, 38]], [36, 6, [35, 40]], [36, 6, [36, 40]], [36, 6, [37, 40]],
              [35, 8, [34, 45]], [35, 8, [34, 44]], [34, 8, [34, 47]], [34, 8, [34, 46]], [34, 8, [34, 45]],
              [37, 6, [36, 42]], [35, 6, [33, 42]], [34, 8, [34, 44]], [34, 8, [34, 43]], [34, 4, [35, 41]],
              [34, 8, [33, 42]], [35, 6, [34, 42]], [35, 6, [35, 42]], [37, 2, [38, 41]], [37, 2, [38, 42]],
              [37, 2, [38, 43]], [37, 6, [37, 45]], [38, 4, [40, 43]], [38, 2, [38, 42]], [35, 6, [36, 42]],
              [38, 2, [38, 43]], [38, 2, [38, 44]], [35, 2, [38, 41]], [38, 4, [39, 46]], [38, 4, [38, 46]],
              [38, 4, [37, 46]], [38, 4, [36, 46]], [38, 8, [34, 47]]]
    # Each room: the box the player stands in, the value of variable 514 it is solved from, its statues, the plan, the
    # goal of each statue and the drawn copy of each.
    ROOMS = [
      { :box => [2, 19, 5, 19], :stage => 2, :statues => [4, 5, 6], :plan => PLAN_1,
        :goals => { 4 => [8, 11], 5 => [11, 13], 6 => [13, 11] },
        :drawn => { 4 => [8, 38], 5 => [11, 40], 6 => [13, 38] } },
      { :box => [31, 57, 36, 49], :stage => 4, :statues => [34, 35, 36, 37, 38], :plan => PLAN_2,
        :goals => { 34 => [33, 40], 35 => [38, 43], 36 => [39, 40], 37 => [39, 45], 38 => [34, 45] },
        :drawn => { 34 => [49, 40], 35 => [54, 43], 36 => [55, 40], 37 => [55, 45], 38 => [50, 45] } }
    ]

    # The statues' tiles after each push of a room's plan, as tiles => index of the next push.
    def self.states(room)
      @states ||= {}
      @states[room[:stage]] ||= begin
        pos = {}
        room[:statues].each { |id| pos[id] = START[id] }
        out = {}
        room[:plan].each_with_index do |(id, dir, _from), i|
          out[room[:statues].map { |s| pos[s] }] = i
          dx, dy = DIRS[dir]
          pos[id] = [pos[id][0] + dx, pos[id][1] + dy]
        end
        out
      end
    end

    # True while the player stands in a room whose statues still count.
    def self.live?(room)
      return false unless $game_variables[514].to_i == room[:stage]
      x = $game_player.x
      y = $game_player.y
      b = room[:box]
      x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3]
    end

    # The index of the next push in a room's plan as the statues stand, :reset off the plan, or nil when idle elsewhere
    # or with every statue on its tile.
    def self.next_push(room)
      return nil unless live?(room) && !($game_system.map_interpreter.running? rescue false)
      tiles = room[:statues].map { |id| (ev = $game_map.events[id]) ? [ev.x, ev.y] : nil }
      return nil if tiles == room[:statues].map { |id| room[:goals][id] }
      states(room)[tiles] || :reset
    end

    # A statue's name, by the event's own name.
    def self.statue_name(id)
      ev = $game_map.events[id]
      ev ? ev.name.to_s : ""
    end

    # The line of a push of the plan.
    def self.push_line(room, i)
      id, dir, _from = room[:plan][i]
      [:rj_garufa_push, { :name => statue_name(id), :dir => PokeAccess::Puzzles.face_name(dir),
                          :from => PokeAccess::Puzzles.face_name(10 - dir) }]
    end

    # A yellow tile's label: with the assist, the statue it waits for.
    def self.yellow_label(id)
      PokeAccess::Puzzles.assist? ? [:rj_garufa_goes, { :name => statue_name(id) }] : :rj_garufa_yellow
    end

    # The line as a seal lifts: variable 514 at 3 or 5.
    def self.seal_line
      [3, 5].include?($game_variables[514].to_i) ? :rj_garufa_seal : nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  ruins = PokeAccess::RejuvGarufa
  mechanic(:state, ruins::MAP, :part => :garufa) do
    auto
    name ruins::START.keys, lambda { |ev| [:rj_garufa_statue, { :name => ev.name.to_s }] }
    watch :var => 514, :say => lambda { ruins.seal_line }
    ruins::ROOMS.each do |room|
      room[:goals].each do |id, xy|
        spot :at => xy, :label => lambda { ruins.yellow_label(id) }
      end
      room[:drawn].each do |id, xy|
        spot :at => xy, :label => lambda { [:rj_garufa_drawn, { :name => ruins.statue_name(id) }] }
      end
      room[:plan].each_with_index do |(_id, _dir, from), i|
        phase(lambda { PokeAccess::Puzzles.assist? && ruins.next_push(room) == i },
              :title => lambda { ruins.push_line(room, i) })
        spot :at => from, :label => :rj_garufa_push_from, :onto => true, :assist => true,
             :when => lambda { ruins.next_push(room) == i }
      end
      phase(lambda { PokeAccess::Puzzles.assist? && ruins.next_push(room) == :reset }, :title => :rj_garufa_reset)
    end
    solved(nil, :quiet => true) { $game_variables[514].to_i >= 5 }
  end
end
