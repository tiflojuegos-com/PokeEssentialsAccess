# Rejuvenation's Zorua room (map 107, variable 514 from 6): ten statues (events 39 to 48) to push onto their marks,
# planned push by push from the live layout, with the tile to push from listed under the assist. Switch 1028 is the end.
module PokeAccess
  module RejuvZorua
    MAP = 107
    STAGE = 6
    BOX = [5, 30, 70, 104]
    DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    STATUES = [39, 40, 41, 42, 43, 44, 45, 46, 47, 48]
    START = { 39 => [18, 82], 40 => [18, 94], 41 => [27, 88], 42 => [10, 88], 43 => [19, 76], 44 => [19, 73],
              45 => [23, 85], 46 => [13, 85], 47 => [26, 76], 48 => [17, 102] }
    GOALS = { 39 => [7, 86], 40 => [9, 80], 41 => [10, 74], 42 => [26, 74], 43 => [22, 101], 44 => [27, 80],
              45 => [15, 92], 46 => [27, 86], 47 => [16, 87], 48 => [14, 101] }
    # [statue, facing of the push, tile the player pushes from], in order.
    PLAN = [[39, 2, [18, 81]], [40, 8, [18, 95]], [40, 4, [19, 93]], [40, 8, [17, 94]], [40, 8, [17, 93]],
            [40, 4, [18, 91]], [40, 4, [17, 91]], [40, 4, [16, 91]], [40, 4, [15, 91]], [40, 8, [13, 92]],
            [40, 8, [13, 91]], [40, 8, [13, 90]], [40, 8, [13, 89]], [40, 8, [13, 88]], [46, 6, [12, 85]],
            [46, 2, [14, 84]], [46, 2, [14, 85]], [46, 2, [14, 86]], [46, 2, [14, 87]], [46, 2, [14, 88]],
            [46, 6, [13, 90]], [46, 6, [14, 90]], [46, 6, [15, 90]], [46, 6, [16, 90]], [46, 6, [17, 90]],
            [46, 6, [18, 90]], [46, 6, [19, 90]], [46, 6, [20, 90]], [46, 6, [21, 90]], [46, 6, [22, 90]],
            [46, 8, [24, 91]], [46, 8, [24, 90]], [46, 6, [23, 88]], [46, 6, [24, 88]], [46, 8, [26, 89]],
            [46, 6, [25, 87]], [40, 8, [13, 87]], [40, 8, [13, 86]], [40, 8, [13, 85]], [40, 8, [13, 84]],
            [40, 8, [13, 83]], [40, 6, [12, 81]], [40, 6, [13, 81]], [40, 6, [14, 81]], [40, 8, [16, 82]],
            [40, 6, [15, 80]], [40, 8, [17, 81]], [40, 8, [17, 80]], [40, 8, [17, 79]], [40, 8, [17, 78]],
            [40, 4, [18, 76]], [40, 4, [17, 76]], [40, 4, [16, 76]], [40, 4, [15, 76]], [40, 4, [14, 76]],
            [40, 4, [13, 76]], [40, 8, [11, 77]], [40, 4, [12, 75]], [40, 4, [11, 75]], [40, 2, [9, 74]],
            [40, 2, [9, 75]], [40, 2, [9, 76]], [40, 2, [9, 77]], [40, 2, [9, 78]], [45, 2, [23, 84]],
            [45, 2, [23, 85]], [45, 2, [23, 86]], [45, 2, [23, 87]], [45, 2, [23, 88]], [45, 2, [23, 89]],
            [45, 4, [24, 91]], [45, 4, [23, 91]], [45, 4, [22, 91]], [45, 4, [21, 91]], [45, 4, [20, 91]],
            [45, 2, [18, 90]], [45, 4, [19, 92]], [45, 4, [18, 92]], [45, 4, [17, 92]], [48, 8, [17, 103]],
            [48, 4, [18, 101]], [48, 4, [17, 101]], [48, 4, [16, 101]], [44, 6, [18, 73]], [44, 6, [19, 73]],
            [44, 2, [21, 72]], [44, 2, [21, 73]], [44, 2, [21, 74]], [44, 6, [20, 76]], [44, 6, [21, 76]],
            [44, 6, [22, 76]], [44, 6, [23, 76]], [43, 2, [19, 75]], [43, 2, [19, 76]], [43, 2, [19, 77]],
            [43, 2, [19, 78]], [43, 2, [19, 79]], [43, 6, [18, 81]], [43, 6, [19, 81]], [43, 6, [20, 81]],
            [43, 2, [22, 80]], [43, 2, [22, 81]], [43, 2, [22, 82]], [43, 2, [22, 83]], [43, 2, [22, 84]],
            [43, 2, [22, 85]], [43, 2, [22, 86]], [43, 2, [22, 87]], [43, 2, [22, 88]], [43, 2, [22, 89]],
            [43, 4, [23, 91]], [43, 4, [22, 91]], [43, 4, [21, 91]], [43, 2, [19, 90]], [43, 2, [19, 91]],
            [43, 4, [20, 93]], [43, 2, [18, 92]], [43, 2, [18, 93]], [43, 2, [18, 94]], [43, 6, [17, 96]],
            [43, 2, [19, 95]], [43, 2, [19, 96]], [43, 2, [19, 97]], [43, 2, [19, 98]], [43, 2, [19, 99]],
            [43, 6, [18, 101]], [43, 6, [19, 101]], [43, 6, [20, 101]], [47, 2, [26, 75]], [47, 4, [27, 77]],
            [44, 6, [24, 76]], [44, 2, [26, 75]], [44, 2, [26, 76]], [44, 2, [26, 77]], [44, 6, [25, 79]],
            [44, 2, [27, 78]], [47, 8, [25, 78]], [47, 4, [26, 76]], [47, 4, [25, 76]], [47, 4, [24, 76]],
            [47, 4, [23, 76]], [47, 4, [22, 76]], [47, 4, [21, 76]], [47, 2, [19, 75]], [47, 2, [19, 76]],
            [47, 2, [19, 77]], [47, 2, [19, 78]], [47, 2, [19, 79]], [39, 2, [18, 82]], [39, 2, [18, 83]],
            [39, 2, [18, 84]], [39, 2, [18, 85]], [39, 8, [18, 88]], [39, 8, [18, 87]], [39, 8, [18, 86]],
            [39, 8, [18, 85]], [39, 8, [18, 84]], [39, 8, [18, 83]], [39, 8, [18, 82]], [39, 4, [19, 80]],
            [39, 2, [17, 79]], [39, 4, [18, 81]], [39, 4, [17, 81]], [39, 2, [15, 80]], [39, 2, [15, 81]],
            [39, 4, [16, 83]], [39, 4, [15, 83]], [39, 2, [13, 82]], [39, 2, [13, 83]], [39, 2, [13, 84]],
            [39, 4, [14, 86]], [39, 4, [13, 86]], [39, 4, [12, 86]], [39, 4, [11, 86]], [39, 4, [10, 86]],
            [39, 4, [9, 86]], [47, 4, [20, 81]], [47, 2, [18, 80]], [47, 2, [18, 81]], [47, 2, [18, 82]],
            [47, 2, [18, 83]], [47, 2, [18, 84]], [47, 2, [18, 85]], [47, 4, [19, 87]], [47, 4, [18, 87]],
            [42, 6, [9, 88]], [42, 6, [10, 88]], [42, 6, [11, 88]], [42, 8, [13, 89]], [42, 8, [13, 88]],
            [42, 8, [13, 87]], [42, 8, [13, 86]], [42, 8, [13, 85]], [42, 8, [13, 84]], [42, 8, [13, 83]],
            [42, 6, [12, 81]], [42, 6, [13, 81]], [42, 6, [14, 81]], [42, 8, [16, 82]], [42, 6, [15, 80]],
            [42, 6, [16, 80]], [42, 6, [17, 80]], [42, 8, [19, 81]], [42, 8, [19, 80]], [42, 8, [19, 79]],
            [42, 8, [19, 78]], [42, 6, [18, 76]], [42, 6, [19, 76]], [42, 6, [20, 76]], [42, 6, [21, 76]],
            [42, 6, [22, 76]], [42, 6, [23, 76]], [42, 6, [24, 76]], [42, 8, [26, 77]], [42, 8, [26, 76]],
            [41, 4, [28, 88]], [41, 4, [27, 88]], [41, 4, [26, 88]], [41, 4, [25, 88]], [41, 4, [24, 88]],
            [41, 8, [22, 89]], [41, 8, [22, 88]], [41, 8, [22, 87]], [41, 8, [22, 86]], [41, 8, [22, 85]],
            [41, 8, [22, 84]], [41, 8, [22, 83]], [41, 4, [23, 81]], [41, 4, [22, 81]], [41, 4, [21, 81]],
            [41, 4, [20, 81]], [41, 4, [19, 81]], [41, 4, [18, 81]], [41, 8, [16, 82]], [41, 6, [15, 80]],
            [41, 8, [17, 81]], [41, 8, [17, 80]], [41, 8, [17, 79]], [41, 8, [17, 78]], [41, 4, [18, 76]],
            [41, 4, [17, 76]], [41, 4, [16, 76]], [41, 4, [15, 76]], [41, 4, [14, 76]], [41, 4, [13, 76]],
            [41, 8, [11, 77]], [41, 8, [11, 76]], [41, 4, [12, 74]], [46, 8, [27, 88]]]

    # The statues' tiles before each push => the indexes of the pushes made from them, in order.
    def self.states
      @states ||= begin
        pos = {}
        START.each { |id, xy| pos[id] = xy }
        out = {}
        PLAN.each_with_index do |(id, dir, _from), i|
          (out[STATUES.map { |s| pos[s] }] ||= []).push(i)
          pos[id] = [pos[id][0] + DIRS[dir][0], pos[id][1] + DIRS[dir][1]]
        end
        out
      end
    end

    # Drops the push said last, as the map changes and the statues go back.
    def self.forget
      @tiles = nil
      @index = nil
    end

    # The push for a layout: the first after the one said last, else the one pushed from nearest the player.
    def self.index_for(tiles)
      return @index if tiles == @tiles
      list = states[tiles]
      @tiles = tiles
      @index = list ? (list.find { |k| @index.is_a?(Integer) && k > @index } || nearest(list)) : :reset
    end

    # Of the pushes made from one layout, the one whose tile to push from is nearest the player.
    def self.nearest(list)
      list.min_by { |k| (PLAN[k][2][0] - $game_player.x).abs + (PLAN[k][2][1] - $game_player.y).abs }
    end

    # True while the player stands in the room and its statues still count.
    def self.live?
      return false unless $game_map.map_id == MAP && $game_variables[514].to_i >= STAGE && !$game_switches[1028]
      x = $game_player.x
      y = $game_player.y
      x >= BOX[0] && x <= BOX[1] && y >= BOX[2] && y <= BOX[3]
    end

    # The index of the next push as the statues stand, :reset off the plan, or nil when idle elsewhere or all placed.
    def self.next_push
      return nil unless live? && !($game_system.map_interpreter.running? rescue false)
      tiles = STATUES.map { |id| (ev = $game_map.events[id]) ? [ev.x, ev.y] : nil }
      return nil if tiles == STATUES.map { |id| GOALS[id] }
      index_for(tiles)
    end

    # A statue's name, by the event's own name without the number some carry.
    def self.statue_name(id)
      ev = $game_map.events[id]
      ev ? ev.name.to_s.sub(/\s+\d+\z/, "") : ""
    end

    # The line of push i.
    def self.push_line(i)
      id, dir, _from = PLAN[i]
      [:rj_garufa_push, { :name => statue_name(id), :dir => PokeAccess::Puzzles.face_name(dir),
                          :from => PokeAccess::Puzzles.face_name(10 - dir) }]
    end

    # The tile to push from now, or nil.
    def self.push_from
      i = next_push
      i.is_a?(Integer) ? PLAN[i][2] : nil
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  zorua = PokeAccess::RejuvZorua
  mechanic(:state, zorua::MAP, :part => :zorua) do
    auto
    name zorua::STATUES, lambda { |ev| [:rj_garufa_statue, { :name => zorua.statue_name(ev.id) }] }
    zorua::GOALS.each do |id, xy|
      spot :at => xy, :label => lambda { [:rj_garufa_goes, { :name => zorua.statue_name(id) }] }, :assist => true,
           :when => lambda { zorua.live? }
    end
    [0, 1].each do |odd|
      phase(lambda { PokeAccess::Puzzles.assist? && (i = zorua.next_push).is_a?(Integer) && i % 2 == odd },
            :title => lambda { zorua.push_line(zorua.next_push) })
    end
    phase(lambda { PokeAccess::Puzzles.assist? && zorua.next_push == :reset }, :title => :rj_garufa_reset)
    spot :at => lambda { zorua.push_from }, :label => :rj_garufa_push_from, :onto => true, :assist => true
    solved(nil, :quiet => true) { $game_switches[1028] }
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RejuvZorua.forget }
