# Route 17 (map 321), Johannes's Banette dolls: while his test runs (variable 63 at 1), eleven dolls among the Strength
# boulders vanish as they are touched and add one to variable 64; at 11 a parallel event ends the test (63 at 2). The
# two exits and the door of his house set the count back and bring the dolls back, so they are touched in one visit.
# With the assist, the next doll of a simulated order and what it still needs, read off where the boulders stand.
module PokeAccess
  module HeroLegacyDolls
    MAP = 321
    # The dolls in an order found against the map from Johannes's door (42, 7), fewest pushes first at each doll: the
    # doll, its tile, and what is done before it, [boulder, the tile it stands on, the direction it is pushed], or a
    # breakable rock smashed, [rock, its tile, :smash].
    ORDER = [[61, [29, 10], [[46, [31, 9], 4], [46, [30, 9], 4], [42, [29, 7], 4], [42, [28, 7], 4], [42, [27, 7], 2],
                             [42, [27, 8], 2], [42, [27, 9], 2], [42, [27, 10], 2]]],
             [21, [29, 15], [[43, [29, 11], 2], [44, [30, 11], 4], [45, [30, 12], 2], [45, [30, 13], 2],
                             [45, [30, 14], 2]]],
             [22, [32, 13], [[48, [32, 14], 6]]],
             [20, [23, 10], [[41, [26, 9], 4], [41, [25, 9], 4], [39, [22, 7], 4], [59, [22, 8], 2],
                             [8, [21, 8], :smash], [7, [21, 10], :smash]]],
             [15, [17, 11], [[35, [16, 9], 4], [34, [16, 10], 2], [34, [16, 11], 2]]],
             [14, [16, 14], [[33, [16, 13], 4]]],
             [18, [12, 8], [[35, [15, 9], 8], [31, [14, 9], 4], [30, [14, 8], 8]]],
             [17, [13, 10], [[32, [14, 10], 2]]],
             [13, [13, 15], [[1, [13, 11], :smash]]],
             [6, [7, 12], [[26, [10, 11], 4], [24, [7, 13], 4]]],
             [19, [10, 7], [[26, [9, 11], 8], [26, [9, 10], 8], [26, [9, 9], 8]]]]
    DIRS = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    def self.taken?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # Where a push in each direction moves a boulder.
    STEP = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
    # The boulders the order never pushes, on the tiles it needs them on.
    HOME = { 25 => [7, 11], 27 => [13, 13], 28 => [14, 12], 29 => [12, 9], 36 => [16, 8], 37 => [16, 7], 38 => [20, 8],
             40 => [26, 8] }

    # The next doll of the order not touched yet, as its row of ORDER, or nil.
    def self.next_step
      ORDER.find { |row| !taken?(row[0]) }
    end

    # Each boulder's tiles along the whole order: where it stands before each of its pushes, then where it ends.
    def self.tracks
      @tracks ||= begin
        t = {}
        last = {}
        ORDER.each do |row|
          row[2].each do |id, xy, dir|
            next if dir == :smash
            (t[id] ||= []) << xy
            last[id] = [xy[0] + STEP[dir][0], xy[1] + STEP[dir][1]]
          end
        end
        last.each { |id, xy| t[id] << xy }
        t
      end
    end

    # How many of its pushes a boulder has had, by where it stands now, or nil when it stands off the order.
    def self.pushed(id)
      ev = $game_map.events[id]
      ev && tracks[id].index([ev.x, ev.y])
    end

    # What is left to do up to the next doll of the order: the pushes whose boulder has not had them yet and the
    # rocks still standing, in order; nil when a boulder stands where the order never puts it.
    def self.steps_left(row)
      return nil unless HOME.all? { |id, xy| (ev = $game_map.events[id]).nil? || [ev.x, ev.y] == xy }
      done = Hash.new(0)
      left = []
      ORDER[0..ORDER.index(row)].each do |r|
        r[2].each do |id, xy, dir|
          if dir == :smash
            ev = $game_map.events[id]
            left << [id, xy, dir] if ev && PokeAccess::World::Mechanics::State.drawn?(ev)
            next
          end
          at = pushed(id)
          return nil unless at
          left << [id, xy, dir] if done[id] >= at
          done[id] += 1
        end
      end
      left
    end

    # The assist's line: what the next doll still needs, then the doll; or that the boulders have left the order.
    def self.hint
      row = next_step
      return nil unless row
      x, y = row[1]
      left = steps_left(row)
      return :hl_banette_offplan unless left
      return [:hl_banette_next, { :x => x, :y => y }] if left.empty?
      steps = left.map do |_b, (bx, by), dir|
        next PokeAccess::I18n.t(:hl_banette_smash, :x => bx, :y => by) if dir == :smash
        PokeAccess::I18n.t(:hl_banette_push, :x => bx, :y => by, :dir => PokeAccess::I18n.t(DIRS[dir]))
      end
      [:hl_banette_pushes, { :steps => steps.join("; "), :x => x, :y => y }]
    end
  end
end

PokeAccess::Game.define("herolegacy") do
  dolls = PokeAccess::HeroLegacyDolls
  running = lambda { $game_variables[63] == 1 }
  banette = lambda { PokeAccess::Data.species_name(:BANETTE).to_s }
  mechanic(:state, dolls::MAP) do
    auto
    name dolls::ORDER.map { |row| row[0] }, lambda { |_ev| PokeAccess::I18n.t(:hl_banette_doll, :name => banette.call) }
    dolls::ORDER.each do |row|
      spot :event => row[0], :label => :hl_banette_next_doll, :assist => true,
           :when => lambda { running.call && dolls.next_step == row }
    end
    phase running, :quiet => true, :hint => lambda { dolls.hint },
          :progress => { :var => 64, :of => dolls::ORDER.length, :label => :hl_banette_count, :announce => true,
                        :assist => true }
    arrival_hint lambda { running.call ? :hl_banette_rule : nil }
    solved { $game_variables[63] >= 2 }
  end
end
