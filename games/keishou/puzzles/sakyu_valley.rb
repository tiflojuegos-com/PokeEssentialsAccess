# Sakyu Valley's ruins: parallel "Boulder position checks" read where the rocks lie, add to a count when one rests on its
# socket and switch a ladder or gate on when the count is full: Kuukan Ruins (map 136, var 55 to 3), Jikan Ruins (139, var 62
# to 2), Hankoshi Ruins (140, var 63 to 2) and Sakyu Temple (143, var 65 to 4). The sockets have no graphic of their own: the
# self switch A of each sensor is on once its rock is home, and the sensors of the first three ruins are listed here with the
# socket they watch, as [sensor, x, y]; the temple's sensors read tiles of either world.
#
# The game moves rocks and the player by itself too. Dark pads send a rock elsewhere: Kuukan's silver plate (event 28) takes
# the rock on (19, 7) to (9, 13), and a sensor takes the one left on (5, 21) to (14, 20) and the temple's on (30, 22) to
# (30, 31). Sensors throw a rock over a ledge from (5, 14) to (7, 14) in Jikan and from (11, 9) to (11, 7) in the temple. A
# temporal tile sends the player back a step after a spin, and Hankoshi's and the temple's exits cross to a twin world 30 or
# 40 tiles to the right, carrying the rocks over. With the assist, each socket of Jikan, Hankoshi and the temple has its
# way by stages, read from where its rock lies in the world the player stands in; in the temple, of the corner under way
# or else of the nearest one.
module PokeAccess
  module KeishouRuins
    @seen = {}
    @landed = {}

    # True while event id of the current map rests on to, where the game put it from from in a single frame.
    def self.landed?(id, from, to)
      ev = ($game_map.events[id] rescue nil)
      return false unless ev
      key = [$game_map.map_id, id, to]
      now = [ev.x, ev.y]
      was = @seen[key]
      @seen[key] = now
      @landed[key] = (was == from) if now == to && was != now
      @landed[key] = false unless now == to
      @landed[key] ? true : false
    end

    # True while event id of the current map stands within the box [x0, x1, y0, y1].
    def self.within?(id, box)
      ev = ($game_map.events[id] rescue nil)
      ev ? ev.x >= box[0] && ev.x <= box[1] && ev.y >= box[2] && ev.y <= box[3] : false
    end

    # The world the player is in, on a map whose twin world starts at column split.
    def self.world(split)
      twin?(split) ? :ks_o_world_distortion : :ks_o_world_normal
    end

    # True while the player stands in the twin world of a map whose twin starts at column split.
    def self.twin?(split)
      $game_player.x >= split
    end

    # Where a rock lies in the world the player stands in, as a tile of the normal world: event normal there, or its twin
    # event less split in the twin world.
    def self.rock_at(normal, twin, split)
      ev = ($game_map.events[twin?(split) ? twin : normal] rescue nil)
      return nil unless ev
      twin?(split) ? [ev.x - split, ev.y] : [ev.x, ev.y]
    end

    # True while the rock of normal and twin lies within the box [x0, x1, y0, y1] of normal world tiles.
    def self.rock_within?(normal, twin, split, box)
      inside?(rock_at(normal, twin, split), box)
    end

    # True while the player stands within the box [x0, x1, y0, y1].
    def self.player_within?(box)
      inside?([$game_player.x, $game_player.y], box)
    end

    # True while the blue gems keep a timestamp on this map within the box [x0, x1, y0, y1] (S71, V59 to V61).
    def self.saved_within?(box)
      return false unless $game_switches[71] && $game_variables[61] == $game_map.map_id
      inside?([$game_variables[59], $game_variables[60]], box)
    end

    # True while tile lies within the box [x0, x1, y0, y1].
    def self.inside?(tile, box)
      tile ? tile[0] >= box[0] && tile[0] <= box[1] && tile[1] >= box[2] && tile[1] <= box[3] : false
    end

    # Sakyu Temple's corners (map 143), as [corner, sensor whose self switch A marks it done, socket, normal rock, twin
    # rock, the rock's first tile]; the north-west and south-west ones take the rocks of POOL.
    CORNERS = [[:ne, 35, [30, 7], 9, 13, [20, 16]], [:nw, 14, [6, 7], 17, 18, [5, 14]],
               [:sw, 30, [6, 29], 24, 25, [8, 21]], [:se, 10, [30, 29], 33, 2, [26, 22]]]

    # The rocks the game takes for the north-west and south-west sockets, as [normal event, twin event]: EV14 and EV30 read
    # either twin rock, and EV21, EV5 and EV12 throw or send either. EV30 also takes the twin of the rock of 21, 30.
    POOL = [[17, 18], [24, 25]]

    # The box of normal world tiles the rock of 21, 30 runs through to the south-west socket: the room of 18, 29, where it
    # goes pushed left from 22, 30, and the twin world's way from there to 46, 29.
    DOOR_WAY = [3, 20, 26, 32]

    # The boxes of normal world tiles the ways of those two corners run through: their own steps, never the tiles where
    # the south-east's way leaves the rock of 8, 21.
    WAYS = { :nw => [[7, 11, 7, 7], [11, 11, 9, 19], [6, 10, 14, 14]],
             :sw => [[8, 13, 19, 20], [6, 8, 29, 29], [5, 8, 15, 17], [8, 8, 18, 18]] }

    # The temple corner the assist speaks of: of those not done, the nearest to the player among the ones under way, else
    # the nearest of all, measured on normal world tiles; nil once all four are done. Inside a map frame, worked out once
    # for every phase that asks, as Control.reason is.
    def self.temple_corner
      frame = PokeAccess::Frame
      return temple_corner_now unless frame.running?
      key = [frame.serial, frame.pulses]
      return @corner[1] if @corner && @corner[0] == key
      @corner = [key, temple_corner_now]
      @corner[1]
    end

    def self.temple_corner_now
      left = CORNERS.reject { |c| $game_self_switches[[143, c[1], "A"]] }
      return nil if left.empty?
      busy = left.select { |c| corner_started?(c) }
      x = $game_player.x % 40
      y = $game_player.y
      (busy.empty? ? left : busy).min_by { |c| (c[2][0] - x).abs + (c[2][1] - y).abs }[0]
    end

    # True while corner c is under way: for the north-west and south-west, a rock of POOL on its way (or, for the
    # south-west, the rock of 21, 30 on DOOR_WAY); for the others its rock off its first tile, and for the south-east also
    # the rock of 21, 30 on its own way out of the door or the timestamp by the gem of 30, 19, unless that rock is on the
    # south-west's way.
    def self.corner_started?(c)
      return on_way?(c[0]) if WAYS[c[0]]
      at = rock_at(c[3], c[4], 40)
      return false unless at
      return true if at != c[5]
      return false unless c[0] == :se && !door_on_way?
      rock_within?(34, 1, 40, [22, 25, 22, 32]) || saved_within?([29, 31, 18, 20])
    end

    # True while a rock the game takes for corner lies on one of its WAYS.
    def self.on_way?(corner)
      hit = POOL.any? { |n, t| WAYS[corner].any? { |box| rock_within?(n, t, 40, box) } }
      hit || (corner == :sw && door_on_way?)
    end

    # True while the south-west socket is open and the rock of 21, 30 lies on DOOR_WAY.
    def self.door_on_way?
      !$game_self_switches[[143, 30, "A"]] && rock_within?(34, 1, 40, DOOR_WAY)
    end

    # True while the rock of normal and twin rests on its first tile, in the world the player stands in.
    def self.rock_home?(normal, twin, first)
      rock_at(normal, twin, 40) == first
    end
  end
end

PokeAccess::Game.define("keishou") do
  ruins = {
    136 => [55, 3, [[20, 11, 13], [21, 17, 13], [24, 14, 16]]],
    139 => [62, 2, [[8, 14, 16], [20, 14, 10]]],
    140 => [63, 2, [[9, 18, 13], [20, 10, 13]]],
    143 => [65, 4, [[14, 46, 7], [30, 46, 29], [35, 30, 7], [10, 30, 29]]]
  }
  twins = { 140 => 30, 143 => 40 }
  twin_tiles = { 140 => [5, 8, 10, 11, 12, 13] }
  rk = PokeAccess::KeishouRuins
  home = lambda { |map, sensor| $game_self_switches[[map, sensor, "A"]] }
  ruins.each do |map, (var, total, sockets)|
    mechanic(:state, map) do
      auto
      count :ks_ruin_rocks, :var => var, :of => total
      sockets.each do |sensor, x, y|
        spot :at => [x, y], :label => :ks_ruin_socket, :onto => true, :when => lambda { !home.call(map, sensor) }
      end
      split = twins[map]
      name twin_tiles[map], :ks_o_distortion_tile if twin_tiles[map]
      if split
        info { PokeAccess::KeishouRuins.world(split) }
        sent_back :ks_o_world_to_distortion, :from => [0, split - 1, 0, 99], :to => [split, 2 * split - 1, 0, 99]
        sent_back :ks_o_world_to_normal, :from => [split, 2 * split - 1, 0, 99], :to => [0, split - 1, 0, 99]
      end
    end
  end

  warped = lambda { |x, y| [:ks_o_rock_warped, { :x => x, :y => y }] }
  jumped = lambda { |x, y| [:ks_o_rock_jumped, { :x => x, :y => y }] }

  mechanic(:state, 136, :part => :pads) do
    auto
    spot :at => [19, 7], :label => :ks_o_dark_pad, :onto => true, :when => lambda { !home.call(136, 20) }
    spot :at => [5, 21], :label => :ks_o_dark_pad, :onto => true, :when => lambda { !home.call(136, 24) }
    name 28, :ks_o_silver_plate
    phase lambda { rk.landed?(1, [19, 7], [9, 13]) }, :title => warped.call(9, 13)
    phase lambda { rk.landed?(2, [5, 21], [14, 20]) }, :title => warped.call(14, 20)
    active { false }
  end

  mechanic(:state, 136, :part => :carry) do
    auto
    phase lambda { PokeAccess::Puzzles.assist? && !home.call(136, 20) && rk.within?(1, [9, 11, 13, 13]) }, :quiet => true,
          :track => { :event => 1, :label => :ks_o_ruin_rock, :goal => [11, 13, 11, 13], :goal_label => :ks_ruin_socket }
    phase lambda { PokeAccess::Puzzles.assist? && !home.call(136, 24) && rk.within?(2, [14, 14, 16, 20]) }, :quiet => true,
          :track => { :event => 2, :label => :ks_o_ruin_rock, :goal => [14, 16, 14, 16], :goal_label => :ks_ruin_socket }
    phase lambda { PokeAccess::Puzzles.assist? && !home.call(136, 20) }, :quiet => true, :hint => :ks_o_kuukan_plate_hint,
          :track => { :event => 1, :label => :ks_o_ruin_rock, :goal => [19, 7, 19, 7], :goal_label => :ks_o_dark_pad }
    phase lambda { PokeAccess::Puzzles.assist? && !home.call(136, 24) }, :quiet => true, :hint => :ks_o_kuukan_pad_hint,
          :track => { :event => 2, :label => :ks_o_ruin_rock, :goal => [5, 21, 5, 21], :goal_label => :ks_o_dark_pad }
  end

  mechanic(:state, 139, :part => :pads) do
    auto
    name 4, :ks_o_temporal_tile
    name 12, :ks_o_cyan_gem
    name [13, 14], :ks_o_blue_gem
    spot :at => [5, 14], :label => :ks_o_brown_pad, :onto => true, :when => lambda { !home.call(139, 20) }
    sent_back :ks_o_temporal_back, :to => [9, 16], :events => [4]
    phase lambda { rk.landed?(1, [5, 14], [7, 14]) }, :title => jumped.call(7, 14)
    active { false }
  end

  rock = :ks_o_ruin_rock
  carry = lambda { |id, goal, label| { :event => id, :label => rock, :goal => goal, :goal_label => label } }
  aid = lambda { |test| lambda { PokeAccess::Puzzles.assist? && test.call } }

  mechanic(:state, 139, :part => :carry) do
    auto
    a_open = lambda { !home.call(139, 20) }
    b_open = lambda { !home.call(139, 8) }
    chamber = [18, 24, 13, 18]
    shut = lambda { rk.within?(7, [21, 21, 19, 19]) }
    saved_in = lambda { rk.saved_within?(chamber) }
    phase aid.call(lambda { b_open.call && rk.within?(7, [12, 24, 20, 22]) }), :quiet => true,
          :track => carry.call(7, [14, 16, 14, 16], :ks_ruin_socket)
    phase aid.call(lambda { b_open.call && shut.call && rk.player_within?(chamber) }), :quiet => true,
          :hint => :ks_o_jikan_out_hint, :track => carry.call(7, [14, 16, 14, 16], :ks_ruin_socket)
    phase aid.call(lambda { b_open.call && shut.call && saved_in.call }), :quiet => true, :hint => :ks_o_jikan_revert_hint
    phase aid.call(lambda { b_open.call && saved_in.call }), :quiet => true, :hint => :ks_o_jikan_cyan_hint
    phase aid.call(lambda { b_open.call && rk.within?(7, [21, 21, 16, 18]) }), :quiet => true, :hint => :ks_o_jikan_chamber_hint,
          :track => carry.call(7, [21, 16, 21, 16], :ks_o_boulder_goal)
    phase aid.call(lambda { a_open.call && rk.within?(1, [7, 14, 5, 14]) }), :quiet => true, :hint => :ks_o_jikan_socket_hint,
          :track => carry.call(1, [14, 10, 14, 10], :ks_ruin_socket)
    phase aid.call(a_open), :quiet => true, :hint => :ks_o_jikan_pocket_hint,
          :track => carry.call(1, [5, 14, 5, 14], :ks_o_brown_pad)
    phase aid.call(b_open), :quiet => true, :hint => :ks_o_jikan_chamber_hint,
          :track => carry.call(7, [21, 16, 21, 16], :ks_o_boulder_goal)
  end

  mechanic(:state, 140, :part => :carry) do
    auto
    a_open = lambda { !home.call(140, 9) }
    b_open = lambda { !home.call(140, 20) }
    a_in = lambda { |box| a_open.call && rk.rock_within?(1, 7, 30, box) }
    b_in = lambda { |box| b_open.call && rk.rock_within?(2, 6, 30, box) }
    twin = lambda { rk.twin?(30) }
    normal = lambda { !rk.twin?(30) }
    phase aid.call(lambda { a_in.call([18, 18, 13, 17]) && twin.call }), :quiet => true, :hint => :ks_o_hankoshi_a4_hint,
          :track => carry.call(7, [48, 13, 48, 13], :ks_ruin_socket)
    phase aid.call(lambda { a_in.call([18, 18, 13, 17]) }), :quiet => true, :hint => :ks_o_hankoshi_a4_hint
    phase aid.call(lambda { a_in.call([15, 17, 17, 17]) && normal.call }), :quiet => true, :hint => :ks_o_hankoshi_a3_hint,
          :track => carry.call(1, [18, 17, 18, 17], :ks_o_boulder_goal)
    phase aid.call(lambda { a_in.call([15, 17, 17, 17]) }), :quiet => true, :hint => :ks_o_hankoshi_a3_hint
    phase aid.call(lambda { (a_in.call([23, 23, 10, 21]) || a_in.call([15, 22, 21, 21]) || a_in.call([15, 15, 18, 20])) && twin.call }),
          :quiet => true, :hint => :ks_o_hankoshi_a2_hint, :track => carry.call(7, [45, 17, 45, 17], :ks_o_boulder_goal)
    phase aid.call(lambda { a_in.call([23, 23, 10, 21]) || a_in.call([15, 22, 21, 21]) || a_in.call([15, 15, 18, 20]) }),
          :quiet => true, :hint => :ks_o_hankoshi_a2_hint
    phase aid.call(lambda { b_in.call([6, 9, 13, 13]) && normal.call }), :quiet => true, :hint => :ks_o_hankoshi_b3_hint,
          :track => carry.call(2, [10, 13, 10, 13], :ks_ruin_socket)
    phase aid.call(lambda { b_in.call([6, 9, 13, 13]) }), :quiet => true, :hint => :ks_o_hankoshi_b3_hint
    phase aid.call(lambda { (b_in.call([6, 6, 14, 19]) || b_in.call([7, 8, 19, 19])) && twin.call }), :quiet => true,
          :hint => :ks_o_hankoshi_b2_hint, :track => carry.call(6, [36, 13, 36, 13], :ks_o_boulder_goal)
    phase aid.call(lambda { b_in.call([6, 6, 14, 19]) || b_in.call([7, 8, 19, 19]) }), :quiet => true, :hint => :ks_o_hankoshi_b2_hint
    phase aid.call(a_open), :quiet => true, :hint => :ks_o_hankoshi_a1_hint
    phase aid.call(b_open), :quiet => true, :hint => :ks_o_hankoshi_b1_hint
  end

  mechanic(:state, 143, :part => :pads) do
    auto
    name [4, 19], :ks_o_temporal_tile
    name 23, :ks_o_cyan_gem
    name [15, 31, 32], :ks_o_blue_gem
    name [5, 12], :ks_o_silver_plate
    sent_back :ks_o_temporal_back, :to => [19, 12], :events => [4]
    sent_back :ks_o_temporal_back, :to => [16, 12], :events => [19]
    spot :at => [30, 22], :label => :ks_o_dark_pad, :onto => true, :when => lambda { !home.call(143, 10) }
    [[13, 20], [53, 20]].each do |tile|
      spot :at => tile, :label => :ks_o_dark_pad, :onto => true, :when => lambda { !home.call(143, 30) }
    end
    spot :at => [11, 9], :label => :ks_o_brown_pad, :onto => true, :when => lambda { !home.call(143, 14) }
    phase lambda { rk.landed?(33, [30, 22], [30, 31]) }, :title => warped.call(30, 31)
    phase lambda { [17, 24].map { |id| rk.landed?(id, [11, 9], [11, 7]) }.any? }, :title => jumped.call(11, 7)
    active { false }
  end

  mechanic(:state, 143, :part => :carry) do
    auto
    on = lambda { |corner| rk.temple_corner == corner }
    at_c = lambda { |box| on.call(:ne) && rk.rock_within?(9, 13, 40, box) }
    twin = lambda { rk.twin?(40) }
    normal = lambda { !rk.twin?(40) }
    east_gem = lambda { rk.saved_within?([29, 31, 18, 20]) }
    phase aid.call(lambda { at_c.call([31, 33, 7, 7]) && normal.call }), :quiet => true, :hint => :ks_o_temple_ne3_hint,
          :track => carry.call(9, [30, 7, 30, 7], :ks_ruin_socket)
    phase aid.call(lambda { at_c.call([31, 33, 7, 7]) }), :quiet => true, :hint => :ks_o_temple_ne3_hint
    phase aid.call(lambda { on.call(:ne) && normal.call && rk.rock_within?(9, 13, 40, [20, 20, 12, 12]) }), :quiet => true,
          :hint => :ks_o_temple_ne1b_hint
    phase aid.call(lambda { on.call(:ne) && normal.call && rk.rock_within?(9, 13, 40, [21, 25, 12, 12]) }), :quiet => true,
          :hint => :ks_o_temple_ne2b_hint
    phase aid.call(lambda { on.call(:ne) && (twin.call || !rk.rock_within?(9, 13, 40, [16, 20, 9, 24])) }), :quiet => true,
          :hint => :ks_o_temple_ne2_hint
    rk::POOL.each do |n, t|
      at = lambda { |corner, box| on.call(corner) && rk.rock_within?(n, t, 40, box) }
      phase aid.call(lambda { at.call(:nw, [7, 11, 7, 7]) && twin.call }), :quiet => true, :hint => :ks_o_temple_nw3_hint,
            :track => carry.call(t, [46, 7, 46, 7], :ks_ruin_socket)
      phase aid.call(lambda { at.call(:nw, [7, 11, 7, 7]) }), :quiet => true, :hint => :ks_o_temple_nw3_hint
      phase aid.call(lambda { at.call(:nw, [11, 11, 9, 19]) && normal.call }), :quiet => true,
            :hint => :ks_o_temple_nw2_hint, :track => carry.call(n, [11, 9, 11, 9], :ks_o_brown_pad)
      phase aid.call(lambda { at.call(:nw, [11, 11, 9, 19]) || at.call(:nw, [6, 10, 14, 14]) }), :quiet => true,
            :hint => :ks_o_temple_nw1_hint
      phase aid.call(lambda { at.call(:sw, [6, 8, 29, 29]) && twin.call }), :quiet => true, :hint => :ks_o_temple_sw3_hint,
            :track => carry.call(t, [46, 29, 46, 29], :ks_ruin_socket)
      phase aid.call(lambda { at.call(:sw, [6, 8, 29, 29]) || at.call(:sw, [13, 13, 20, 20]) }), :quiet => true,
            :hint => :ks_o_temple_sw3_hint
      phase aid.call(lambda { at.call(:sw, [8, 12, 19, 20]) && normal.call }), :quiet => true,
            :hint => :ks_o_temple_sw2_hint, :track => carry.call(n, [13, 20, 13, 20], :ks_o_dark_pad)
      phase aid.call(lambda { at.call(:sw, [8, 12, 19, 20]) }), :quiet => true, :hint => :ks_o_temple_sw2_hint
      phase aid.call(lambda { at.call(:sw, [5, 8, 15, 17]) || at.call(:sw, [8, 8, 18, 18]) }), :quiet => true,
            :hint => :ks_o_temple_sw1b_hint
    end
    phase aid.call(lambda { on.call(:sw) && rk.door_on_way? && twin.call }), :quiet => true,
          :hint => :ks_o_temple_sw4_hint, :track => carry.call(1, [46, 29, 46, 29], :ks_ruin_socket)
    phase aid.call(lambda { on.call(:sw) && rk.door_on_way? }), :quiet => true, :hint => :ks_o_temple_sw4_hint
    phase aid.call(lambda { on.call(:se) && rk.within?(33, [30, 30, 30, 31]) }), :quiet => true, :hint => :ks_o_temple_se3_hint,
          :track => carry.call(33, [30, 29, 30, 29], :ks_ruin_socket)
    phase aid.call(lambda { on.call(:se) && east_gem.call && rk.within?(34, [21, 21, 30, 30]) }), :quiet => true,
          :hint => :ks_o_temple_se3_hint, :track => carry.call(33, [30, 22, 30, 22], :ks_o_dark_pad)
    phase aid.call(lambda { on.call(:se) && east_gem.call }), :quiet => true, :hint => :ks_o_temple_se2_hint
    phase aid.call(lambda { on.call(:ne) }), :quiet => true, :hint => :ks_o_temple_ne1_hint
    a_home = lambda { rk.rock_home?(17, 18, [5, 14]) }
    b_home = lambda { rk.rock_home?(24, 25, [8, 21]) }
    phase aid.call(lambda { on.call(:nw) && a_home.call }), :quiet => true, :hint => :ks_o_temple_nw1_hint
    sw_done = lambda { home.call(143, 30) }
    phase aid.call(lambda { on.call(:nw) && b_home.call && sw_done.call }), :quiet => true, :hint => :ks_o_temple_nw1b_hint
    phase aid.call(lambda { on.call(:sw) && b_home.call }), :quiet => true, :hint => :ks_o_temple_sw1_hint
    phase aid.call(lambda { on.call(:sw) && a_home.call }), :quiet => true, :hint => :ks_o_temple_sw1b_hint
    phase aid.call(lambda { on.call(:nw) && b_home.call }), :quiet => true, :hint => :ks_o_temple_reset3_hint
    corner_open = lambda { on.call(:nw) || on.call(:sw) }
    phase aid.call(lambda { corner_open.call && rk.rock_within?(24, 25, 40, [8, 8, 22, 22]) }), :quiet => true,
          :hint => :ks_o_temple_reset2_hint
    phase aid.call(corner_open), :quiet => true, :hint => :ks_o_temple_reset_hint
    phase aid.call(lambda { on.call(:se) }), :quiet => true, :hint => :ks_o_temple_se1_hint
  end
end
