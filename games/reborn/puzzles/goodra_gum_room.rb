# The GUM Room of the Water Treatment Center (map 606): 29 sewer pipes, used facing along their row or column, move one
# tile away from the player when the tile ahead is free. Terminal 33 at (37, 3) counts in variable 62 the pipes on their
# TARGETS tile and gives the Goomy with all 29; with a password (switches 2226, 2227) it offers to skip.
module PokeAccess
  module RebornGumRoom
    TARGETS = {
      1 => [14, 4], 2 => [22, 12], 3 => [15, 14], 4 => [14, 16], 5 => [21, 16], 6 => [26, 18], 7 => [24, 14],
      8 => [30, 17], 9 => [30, 13], 10 => [30, 11], 11 => [30, 9], 12 => [30, 7], 13 => [30, 5], 14 => [26, 4],
      15 => [32, 4], 16 => [24, 4], 17 => [22, 4], 18 => [18, 4], 19 => [26, 2], 20 => [34, 8], 21 => [33, 15],
      22 => [32, 18], 23 => [19, 11], 24 => [21, 13], 25 => [13, 8], 26 => [20, 2], 27 => [22, 2], 30 => [12, 4],
      31 => [30, 19]
    }
    STARTS = {
      1 => [22, 4], 2 => [22, 12], 3 => [14, 14], 4 => [14, 18], 5 => [21, 18], 6 => [28, 18], 7 => [28, 14],
      8 => [30, 13], 9 => [30, 11], 10 => [30, 9], 11 => [30, 7], 12 => [30, 5], 13 => [30, 3], 14 => [30, 4],
      15 => [32, 4], 16 => [28, 4], 17 => [26, 4], 18 => [24, 4], 19 => [26, 2], 20 => [34, 8], 21 => [33, 15],
      22 => [34, 18], 23 => [19, 7], 24 => [21, 9], 25 => [13, 5], 26 => [16, 2], 27 => [18, 2], 30 => [18, 4],
      31 => [30, 15]
    }
    # Each step: the pipe, the way it goes and how many times it is used. Pipes shut each other in: three that start on
    # their tile (events 21, 20 and 19) have to leave it for a while to open a way.
    PLAN = [
      [3, 6, 1], [4, 8, 2], [5, 8, 2], [21, 2, 2], [6, 4, 2], [22, 4, 2], [21, 8, 2], [31, 2, 4], [8, 2, 4], [7, 4, 4],
      [20, 8, 2], [9, 2, 2], [20, 2, 2], [10, 2, 2], [11, 2, 2], [30, 4, 6], [25, 2, 3], [1, 4, 8], [27, 6, 4],
      [26, 6, 4], [23, 2, 4], [24, 2, 4], [18, 4, 6], [19, 6, 2], [17, 4, 4], [16, 4, 4], [14, 4, 4], [12, 2, 2],
      [13, 2, 2], [19, 4, 2]
    ]
    WAYS = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }
    TERMINAL = 33
    PASSWORDS = [2226, 2227]

    # Where a pipe stands now, or nil.
    def self.at(id)
      ev = ($game_map.events[id] rescue nil)
      ev ? [ev.x, ev.y] : nil
    end

    # How many pipes stand on their tile, as the terminal counts them.
    def self.placed
      TARGETS.count { |id, xy| at(id) == xy }
    end

    # True once the terminal has given the Goomy.
    def self.solved?
      $game_self_switches[[606, TERMINAL, "A"]] ? true : false
    end

    # The plan's steps replayed from STARTS: [pipe, way, uses, tile before, tile after].
    def self.runs
      @runs ||= begin
        tiles = STARTS.dup
        PLAN.map do |id, way, n|
          from = tiles[id]
          dx, dy = WAYS[way]
          to = [from[0] + dx * n, from[1] + dy * n]
          tiles[id] = to
          [id, way, n, from, to]
        end
      end
    end

    # How many uses of a step a tile is from the step's start, or nil off its line.
    def self.along(run, xy)
      _id, way, n, from, _to = run
      dx, dy = WAYS[way]
      (0..n).find { |k| xy == [from[0] + dx * k, from[1] + dy * k] }
    end

    # A pipe's place in its own steps: [steps done, uses into the next], or nil off them. A tile on the lines of two
    # steps reads on the later one once the steps between are done, else on the earlier.
    def self.progress(id, xy)
      own = runs.select { |r| r[0] == id }
      return(xy == TARGETS[id] ? [0, 0] : nil) if own.empty?
      (own.length - 1).downto(0) do |k|
        a = along(own[k], xy)
        next unless a && (k.zero? || between_done?(own[k - 1], own[k]))
        return(a == own[k][2] ? [k + 1, 0] : [k, a])
      end
      nil
    end

    # True when every step of the plan between two steps stands done.
    def self.between_done?(first, last)
      runs[(runs.index(first) + 1)...runs.index(last)].all? { |r| at(r[0]) == r[4] }
    end

    # Where a pipe off the plan should go back to: the nearest tile its steps pass by.
    def self.home(id, xy)
      tiles = [TARGETS[id]] + runs.select { |r| r[0] == id }.map { |r| [r[3], r[4]] }.flatten(1)
      tiles.min_by { |t| (t[0] - xy[0]).abs + (t[1] - xy[1]).abs }
    end

    # The plan as things stand: [:back, pipes off it], [:step, its index, uses made] or nil once it is all done; kept
    # while no pipe moves.
    def self.next_step
      tiles = TARGETS.keys.map { |id| at(id) }
      return @memo[1] if @memo && @memo[0] == tiles
      @memo = [tiles, find_step]
      @memo[1]
    end

    # The plan's next step, read afresh (next_step); a pipe whose event is missing is left out.
    def self.find_step
      state = {}
      off = []
      TARGETS.each_key do |id|
        xy = at(id)
        next unless xy
        st = progress(id, xy)
        st ? state[id] = st : off << id
      end
      return [:back, off] unless off.empty?
      seen = Hash.new(0)
      runs.each_with_index do |r, i|
        k = seen[r[0]]
        seen[r[0]] += 1
        st = state[r[0]]
        return [:step, i, st[1]] if st && st[0] <= k
      end
      nil
    end

    # The tile to use the step's pipe from, or nil.
    def self.stand
      s = next_step
      return nil unless s && s[0] == :step
      xy = at(runs[s[1]][0])
      dx, dy = WAYS[runs[s[1]][1]]
      xy ? [xy[0] - dx, xy[1] - dy] : nil
    end

    # With the assist, the next step, the pipes to put back, or the terminal once all are placed.
    def self.hint
      return nil if solved?
      s = next_step
      return(placed == TARGETS.length ? :rb1_gum_boot : nil) unless s
      return back_line(s[1]) if s[0] == :back
      id, way, n = runs[s[1]]
      x, y = at(id)
      sx, sy = stand
      [:rb1_gum_step, { :i => s[1] + 1, :total => runs.length, :x => x, :y => y, :sx => sx, :sy => sy,
                        :dir => PokeAccess::I18n.t(DIRS[way]), :n => n - s[2] }]
    end

    # The pipes off the plan, each with the way back to where it should be.
    def self.back_line(ids)
      list = ids.map do |id|
        xy = at(id)
        t = home(id, xy)
        PokeAccess::I18n.t(:rb1_gum_back_item, :x => xy[0], :y => xy[1],
                           :way => PokeAccess::Puzzles.offset_phrase(t[0] - xy[0], t[1] - xy[1]))
      end
      [:rb1_gum_back, { :list => list.join("; ") }]
    end

    # A pipe's name: with the puzzle assist, the way the plan moves it next, else how far it still is from its tile.
    def self.label(ev)
      return :rbe_gum_pipe unless PokeAccess::Puzzles.assist?
      s = next_step
      if s && s[0] == :step && runs[s[1]][0] == ev.id
        return [:rb1_gum_pipe_next, { :dir => PokeAccess::I18n.t(DIRS[runs[s[1]][1]]) }]
      end
      x, y = TARGETS[ev.id]
      way = PokeAccess::Puzzles.goal_offset([x, y, x, y], [ev.x, ev.y])
      way.empty? ? :rbe_gum_pipe_placed : [:rbe_gum_pipe_way, { :way => way }]
    end

    # With the assist, how the puzzle is skipped while neither password is on; nil otherwise.
    def self.rule
      return nil unless PokeAccess::Puzzles.assist?
      PASSWORDS.any? { |sw| $game_switches[sw] } ? nil : :rbe_gum_skip_hint
    end
  end
end

PokeAccess::Game.define("reborn") do
  gum = PokeAccess::RebornGumRoom
  mechanic(:state, 606, :part => :pipes) do
    auto
    name gum::TARGETS.keys, lambda { |ev| gum.label(ev) }
    name gum::TERMINAL, :rbe_gum_terminal
    count :rbe_gum_placed, :value => lambda { gum.placed }, :of => gum::TARGETS.length, :assist => true
    spot :at => lambda { gum.stand }, :onto => true, :assist => true, :label => :rb1_gum_stand
    arrival_hint lambda { gum.rule }
    hint lambda { gum.hint }
    active { PokeAccess::Puzzles.assist? && !gum.solved? }
    solved(nil, :quiet => true) { gum.solved? }
  end
end
