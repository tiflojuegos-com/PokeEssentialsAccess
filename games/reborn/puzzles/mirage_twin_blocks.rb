# Mirage Tower floors 1 to 6 (maps 668, 670 to 674) and the postgame tower (map 880): pushing a pen's control block
# moves its twin the same way while it can (on 880 either moves the other); both on their lights solve the floor. The
# assist plans both (Routes::Effects.push_twins); two pens of 880 are too large to search, so their pushes are data.
module PokeAccess
  module RebornMirageTwins
    # Map => [control block, its light tile, twin, its light tile, value of variable 377 once solved].
    FLOORS = { 668 => [23, [11, 20], 24, [18, 20], 1], 670 => [53, [20, 21], 1, [27, 25], 2],
               671 => [10, [12, 26], 32, [15, 26], 3], 672 => [49, [22, 26], 1, [30, 26], 4],
               673 => [92, [26, 35], 8, [20, 32], 6], 674 => [109, [29, 50], 34, [38, 53], 5] }

    TOWER = 880

    # Map 880's pens the routes plan, as [part, control, its light tile, twin, its light tile, the room's box
    # [x0, y0, x1, y1], solved test].
    PENS = [[:twin_blocks_1, 23, [17, 31], 24, [25, 34], [12, 28, 29, 36], lambda { $game_variables[646].to_i >= 1 }],
            [:twin_blocks_2, 147, [62, 32], 148, [70, 32], [57, 28, 74, 36], lambda { $game_variables[646].to_i >= 2 }],
            [:twin_blocks_bonus2, 233, [17, 197], 234, [25, 197], [12, 193, 29, 201], lambda { $game_switches[1761] }]]

    # Map 880's pens with their pushes as data: [part, control, twin, the lights, the room's box, solved test, where
    # the blocks start, steps as [block pushed, direction, tile pushed from, [control's tile, twin's tile] after]].
    # A light is a tile, or the event of a light that moves (the bonus pen's circles, 155 and 156, at every push), so
    # states and steps carry their tiles after the blocks'.
    PLANNED = [
      [:twin_blocks_3, 149, 150, [[18, 87], [23, 87]], [9, 82, 31, 92], lambda { $game_variables[646].to_i >= 3 },
       [[14, 87], [27, 87]],
       [[149, 4, [15, 87], [[14, 87], [26, 87]]], [149, 2, [14, 86], [[14, 88], [26, 87]]],
        [150, 4, [27, 87], [[14, 88], [25, 87]]], [150, 4, [26, 87], [[14, 88], [24, 87]]],
        [150, 4, [25, 87], [[14, 88], [23, 87]]], [149, 8, [14, 89], [[14, 87], [23, 86]]],
        [149, 8, [14, 88], [[14, 86], [23, 85]]], [150, 4, [24, 85], [[14, 86], [22, 85]]],
        [150, 4, [23, 85], [[14, 86], [21, 85]]], [149, 2, [14, 85], [[14, 87], [21, 86]]],
        [150, 6, [20, 86], [[15, 87], [21, 86]]], [149, 6, [14, 87], [[16, 87], [21, 86]]],
        [150, 8, [21, 87], [[16, 87], [21, 85]]], [149, 6, [15, 87], [[17, 87], [22, 85]]],
        [149, 6, [16, 87], [[18, 87], [23, 85]]], [149, 2, [18, 86], [[18, 87], [23, 86]]],
        [149, 2, [18, 86], [[18, 87], [23, 87]]]]],
      [:twin_blocks_bonus1, 157, 158, [155, 156], [57, 141, 76, 158], lambda { $game_switches[1760] },
       [[62, 150], [71, 151], [62, 154], [71, 153]],
       [[157, 2, [62, 149], [[62, 151], [71, 152], [62, 153], [71, 152]]],
        [157, 2, [62, 150], [[62, 152], [71, 153], [62, 152], [71, 151]]],
        [157, 2, [62, 151], [[62, 153], [71, 153], [62, 151], [71, 150]]],
        [157, 2, [62, 152], [[62, 154], [71, 153], [62, 150], [71, 149]]],
        [157, 8, [62, 155], [[62, 153], [71, 152], [62, 151], [71, 150]]],
        [157, 8, [62, 154], [[62, 152], [71, 151], [62, 152], [71, 151]]]]]
    ]
    DIR_WORD = { 2 => :dir_down, 4 => :dir_left, 6 => :dir_right, 8 => :dir_up }

    # True while a pen is not solved yet (its test).
    def self.open?(done); !PokeAccess::World::Mechanics.truth(done); end

    # A light tile as a goal box.
    def self.box(at); [at[0], at[1], at[0], at[1]]; end

    # True while the player stands in a box [x0, y0, x1, y1].
    def self.inside?(b)
      px = $game_player.x
      py = $game_player.y
      px >= b[0] && px <= b[2] && py >= b[1] && py <= b[3]
    end

    # Where an event stands, or nil.
    def self.tile_of(id)
      ev = ($game_map.events[id] rescue nil)
      ev ? [ev.x, ev.y] : nil
    end

    # A light's tile now: its own, or where its event stands.
    def self.light_at(light)
      light.is_a?(Array) ? light : tile_of(light)
    end

    # Where a planned pen's control and twin stand, then its moving lights, as the plan writes it; nil with one missing.
    def self.standing(pl)
      tiles = ([pl[1], pl[2]] + pl[3].reject { |l| l.is_a?(Array) }).map { |id| tile_of(id) }
      tiles.include?(nil) ? nil : tiles
    end

    # The planned pen's next push as [index, step]; nil once solved, off the plan or past its last push.
    def self.next_push(pl)
      cur = open?(pl[5]) && standing(pl)
      return nil unless cur
      states = [pl[6]] + pl[7].map { |s| s[3] }
      i = states.index(cur)
      i && i < pl[7].length ? [i, pl[7][i]] : nil
    end

    # True while an open planned pen stands where the plan has no push left: off its states, or at its end unsolved.
    def self.off_plan?(pl)
      standing(pl) && !next_push(pl) && open?(pl[5]) ? true : false
    end

    # The tile the next planned push is made from, with the assist.
    def self.push_at(pl)
      n = PokeAccess::Puzzles.assist? && next_push(pl)
      n && n[1][2]
    end

    # The next planned push in words: which block and which way.
    def self.push_label(pl)
      n = next_push(pl)
      return nil unless n
      what = n[1][0] == pl[1] ? :rbf_mirage_control : :rbf_mirage_twin
      PokeAccess::I18n.t(:rbrc_mirage_push, :what => PokeAccess::I18n.t(what), :dir => PokeAccess::I18n.t(DIR_WORD[n[1][1]]))
    end

    # With the assist, the planned pen's step for the info key: its number, the push and where from; or the way back.
    def self.push_line(pl)
      i18n = PokeAccess::I18n
      return i18n.t(:rbrc_mirage_off) if off_plan?(pl)
      n = next_push(pl)
      return nil unless n
      at = n[1][2]
      where = PokeAccess::Locator.dir_phrase(at[0] - $game_player.x, at[1] - $game_player.y)
      i18n.t(:rbrc_mirage_step, :n => n[0] + 1, :total => pl[7].length, :what => push_label(pl), :where => where)
    end
  end
end

PokeAccess::Game.define("reborn") do
  mt = PokeAccess::RebornMirageTwins
  mt::FLOORS.each do |map, f|
    control, light, twin, twin_light, done = f
    track = { :event => control, :label => :rbf_mirage_control, :goal => mt.box(light), :goal_label => :rbf_mirage_light,
              :with => { twin => mt.box(twin_light) } }
    mechanic(:state, map, :part => :twin_blocks) do
      auto
      name control, :rbf_mirage_control
      name twin, :rbf_mirage_twin
      spot :at => light, :label => :rbf_mirage_light
      spot :at => twin_light, :label => :rbf_mirage_light
      arrival_hint :rbf_mirage_rule, :once => true
      phase lambda { $game_variables[377].to_i < done }, :quiet => true, :track => track, :hint => :rbf_mirage_hint
      solved(nil, :quiet => true) { $game_variables[377].to_i >= done }
    end
  end
  mt::PENS.each do |part, control, light, twin, twin_light, room, done|
    track = { :event => control, :label => :rbf_mirage_control, :goal => mt.box(light), :goal_label => :rbf_mirage_light,
              :with => { twin => mt.box(twin_light) } }
    mechanic(:state, mt::TOWER, :part => part) do
      auto
      name control, :rbf_mirage_control
      name twin, :rbf_mirage_twin
      spot :at => light, :label => :rbf_mirage_light, :when => lambda { mt.open?(done) }
      spot :at => twin_light, :label => :rbf_mirage_light, :when => lambda { mt.open?(done) }
      arrival_hint :rbf_mirage_rule, :once => true
      phase lambda { mt.open?(done) && mt.inside?(room) }, :track => track,
            :hint => :rbf_mirage_hint
      solved(nil, :quiet => true) { !mt.open?(done) }
    end
  end
  mt::PLANNED.each do |pl|
    part, control, twin, lights, room, done = pl
    mechanic(:state, mt::TOWER, :part => part) do
      auto
      name control, :rbf_mirage_control
      name twin, :rbf_mirage_twin
      lights.each do |light|
        spot :at => lambda { mt.light_at(light) }, :label => :rbf_mirage_light, :when => lambda { mt.open?(done) }
      end
      spot :at => lambda { mt.push_at(pl) }, :label => lambda { mt.push_label(pl) }, :assist => true, :onto => true
      arrival_hint lights.any? { |l| l.is_a?(Integer) } ? :rb3_mirage_circles_rule : :rbf_mirage_rule, :once => true
      phase lambda { mt.open?(done) && mt.inside?(room) },
            :track => { :event => control, :label => :rbf_mirage_control }, :hint => lambda { mt.push_line(pl) }
      solved(nil, :quiet => true) { !mt.open?(done) }
    end
  end
end
