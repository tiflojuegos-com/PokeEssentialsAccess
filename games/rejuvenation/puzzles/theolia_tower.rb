# Tower of Theolia (map 339), the Glacier Badge gym: three Angie statues drag a ladder or statue 44 in the room below;
# 44 moves the mirror crack 43, which breaks at (81, 89) (switch 1450). Rock Smash breaks one mirror of the first room
# (event 30, switch 1449) and of the third (162). A blocked move is lost; past ladder 55, variable 96 goes to 138.
module PokeAccess
  module RejuvTheolia
    MAP = 339
    DIRS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # [statue x, statue y, dragged x, dragged y, facing of the next push], from each pair's start.
    PLAN_1 = [[59, 72, 59, 96, 2], [59, 73, 59, 95, 4], [58, 73, 58, 95, 2], [58, 74, 58, 94, 2], [58, 75, 58, 93, 2],
              [58, 76, 58, 92, 4], [57, 76, 57, 92, 4], [56, 76, 56, 92, 4], [55, 76, 55, 92, 4], [54, 76, 54, 92, 4],
              [53, 76, 53, 92, 4], [52, 76, 52, 92, 8], [52, 75, 52, 93, 8], [52, 74, 52, 94, 8], [52, 73, 52, 95, 8]]
    PLAN_2B = [[80, 73, 82, 95, 4], [79, 73, 81, 95, 2],
               [80, 73, 82, 92, 2], [80, 74, 82, 93, 2], [80, 75, 82, 94, 2], [80, 76, 82, 95, 2], [80, 77, 82, 96, 6],
               [80, 77, 83, 96, 2], [80, 78, 83, 96, 4], [79, 78, 82, 96, 4]]
    PLAN_3 = [[118, 72, 104, 72, 2], [118, 73, 104, 73, 2], [118, 74, 104, 74, 2], [118, 75, 104, 74, 4],
              [117, 75, 103, 74, 4], [116, 75, 102, 74, 4], [116, 75, 101, 74, 4], [116, 75, 100, 74, 4],
              [116, 75, 99, 74, 4], [116, 75, 98, 74, 4], [116, 75, 97, 74, 4], [116, 75, 96, 74, 4],
              [116, 75, 95, 74, 8], [116, 74, 95, 73, 8]]
    # Statue 44 moving the crack: only its own tile counts, wherever the crack is.
    PLAN_2A = [[82, 95, 8], [82, 94, 8], [82, 93, 8], [82, 92, 6]]
    # Each statue's room as [x0, x1, y0, y1], the statue, what it drags, the dragged piece's goal, the plan and the
    # servant that puts them back.
    PAIRS = [
      { :room => [49, 61, 70, 78], :statue => 32, :piece => 33, :goal => [52, 96], :plan => PLAN_1, :servant => 177 },
      { :room => [71, 83, 89, 97], :statue => 44, :piece => nil, :goal => nil, :plan => PLAN_2A, :servant => 181 },
      { :room => [71, 83, 70, 78], :statue => 53, :piece => 44, :goal => [81, 96], :plan => PLAN_2B, :servant => 176 },
      { :room => [115, 122, 70, 77], :statue => 56, :piece => 55, :goal => [95, 72], :plan => PLAN_3, :servant => 178 }
    ]
    # The rooms the ladders stand in: the box, the ladder and its goal.
    LADDER_ROOMS = [[[49, 61, 89, 97], 33, [52, 96]], [[71, 83, 89, 97], 44, [81, 96]], [[93, 105, 70, 76], 55, [95, 72]]]
    RED_TILES = [[52, 72], [52, 96], [81, 96], [95, 72]]
    MIRRORS = [29, 30, 46, 47, 49, 50, 51, 52, 160, 161, 162]
    MIRROR_TRAPS = [29, 46, 47, 49, 50, 51, 52, 160, 161]

    # True until the ritual past the last ladder.
    def self.live?
      $game_variables[96].to_i < 138
    end

    # True while no event of the map runs.
    def self.idle?
      !($game_system.map_interpreter.running? rescue false)
    end

    # True while the player stands in a box [x0, x1, y0, y1].
    def self.in?(box)
      x = $game_player.x
      y = $game_player.y
      x >= box[0] && x <= box[1] && y >= box[2] && y <= box[3]
    end

    # An event's tile, or nil.
    def self.tile(id)
      ev = $game_map.events[id]
      ev ? [ev.x, ev.y] : nil
    end

    # True once a pair's dragged piece is on its goal, or the mirror crack has broken.
    def self.done?(pair)
      return $game_switches[1450] ? true : false if pair[:goal].nil?
      tile(pair[:piece]) == pair[:goal]
    end

    # The key a pair's plan reads the live state by.
    def self.state(pair)
      return tile(pair[:statue]) if pair[:piece].nil?
      s = tile(pair[:statue])
      p = tile(pair[:piece])
      s && p ? s + p : nil
    end

    # The plan as state => facing of the next push.
    def self.steps(pair)
      @steps ||= {}
      @steps[pair[:statue]] ||= begin
        h = {}
        pair[:plan].each { |row| h[row[0..-2]] = row[-1] }
        h
      end
    end

    # The next push's facing for a pair as things stand, :reset off the plan, or nil when nothing is asked here.
    def self.next_push(pair)
      return nil unless live? && in?(pair[:room]) && !done?(pair)
      steps(pair)[state(pair)] || :reset
    end

    # The line of a push: the way the statue goes and the side it is faced from.
    def self.push_line(dir)
      [:rj_theolia_push, { :dir => PokeAccess::Puzzles.face_name(dir), :from => PokeAccess::Puzzles.face_name(10 - dir) }]
    end

    # The tile the player pushes from for a plan state.
    def self.push_from(pair, key)
      dx, dy = DIRS[steps(pair)[key]]
      sx, sy = pair[:piece].nil? ? key : key[0, 2]
      [sx - dx, sy - dy]
    end

    # The hint of a ladder's room: use the ladder, break the mirror, go up through it, or go down to the statue.
    def self.ladder_hint(box, ladder, goal)
      return nil unless live? && in?(box)
      return nil if ladder == 44 && !$game_switches[1450]
      return :rj_theolia_hint_ladder if tile(ladder) == goal
      return :rj_theolia_hint_down if ladder == 55
      return :rj_theolia_hint_crack if ladder == 44
      $game_switches[1449] ? :rj_theolia_hint_up : :rj_theolia_hint_mirror
    end

    # A mirror's label: with the assist, the one that breaks names where it leads.
    def self.mirror_label(id)
      return :rj_theolia_mirror unless PokeAccess::Puzzles.assist?
      id == 162 ? :rj_theolia_mirror_secret : :rj_theolia_mirror_right
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  tower = PokeAccess::RejuvTheolia
  mechanic(:state, tower::MAP, :part => :theolia) do
    auto
    name [32, 53, 56], :rj_theolia_statue
    name 44, lambda { |_ev| $game_switches[1450] ? :rj_theolia_ladder : :rj_theolia_statue }
    name [33, 55], :rj_theolia_ladder
    name [43, 48], :rj_theolia_crack
    name tower::MIRRORS, lambda { |ev| tower.mirror_label(ev.id) },
         :when => lambda { |ev| ev.character_name.to_s.empty? }
    hide tower::MIRROR_TRAPS, :assist => true
    name tower::PAIRS.map { |pr| pr[:servant] }, :rj_theolia_servant, :assist => true
    tower::RED_TILES.each { |xy| spot :at => xy, :label => :rj_theolia_red_tile }
    watch :switch => 1450, :say => :rj_theolia_mirror_broken
    tower::PAIRS.each do |pair|
      tower.steps(pair).each_key do |key|
        test = lambda { PokeAccess::Puzzles.assist? && tower.idle? && tower.next_push(pair) && tower.state(pair) == key }
        phase(test, :title => lambda { tower.push_line(tower.steps(pair)[key]) })
        spot :at => tower.push_from(pair, key), :label => :rj_theolia_push_from, :onto => true, :assist => true,
             :when => lambda { tower.next_push(pair) && tower.state(pair) == key }
      end
      phase(lambda { PokeAccess::Puzzles.assist? && tower.idle? && tower.next_push(pair) == :reset },
            :title => :rj_theolia_reset)
      phase(lambda { PokeAccess::Puzzles.assist? && tower.idle? && tower.live? && tower.in?(pair[:room]) &&
                     pair[:goal] && tower.done?(pair) }, :title => :rj_theolia_hint_back)
    end
    tower::LADDER_ROOMS.each do |box, ladder, goal|
      [:rj_theolia_hint_ladder, :rj_theolia_hint_down, :rj_theolia_hint_crack, :rj_theolia_hint_up,
       :rj_theolia_hint_mirror].each do |key|
        phase(lambda { PokeAccess::Puzzles.assist? && tower.idle? && tower.ladder_hint(box, ladder, goal) == key },
              :title => key)
      end
    end
    solved(nil, :quiet => true) { !tower.live? }
  end
end
