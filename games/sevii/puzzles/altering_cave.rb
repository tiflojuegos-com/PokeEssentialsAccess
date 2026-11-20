# The Altering Cave of Outcast Island. Upstairs (map 255) a cracked floor tile (EV6) drops a walker to the floor below
# and opens into a hole when ridden over on the bicycle; with it open, a parallel event (EV24) drops the two boulders
# EV16 and EV22 that reach its tile, (8,15), adding to variable 53. Downstairs (map 256) they come back as EV10 and EV11,
# and a parallel event (EV12) drops one into the hole EV8 at (21,30) when it stands right of it with the player pressing
# left from (23,30), or above it pressed down from (21,28), and into the hole EV2 at (27,8) from (28,8), pressing left
# from (29,8). A plain push never moves a boulder onto a hole: the press against it does.
module PokeAccess
  module SeviiAlteringCave
    UPPER = 255
    LOWER = 256
    # Lower floor: each hole's event, where a boulder waits beside it and where the player presses, and the direction.
    HOLES = [[8, [[22, 30], [23, 30], :left], [[21, 29], [21, 28], :down]], [2, [[28, 8], [29, 8], :left]]]

    # True once a hole of the lower floor holds a boulder (its own switch A).
    def self.filled?(ev)
      $game_self_switches[[LOWER, ev, "A"]] ? true : false
    end

    # True once the crack upstairs is open (its own switch A).
    def self.crack_open?
      $game_self_switches[[UPPER, 6, "A"]] ? true : false
    end

    # Each boulder of the lower floor => the drops upstairs (variable 53) that bring it down.
    NEEDS = { 10 => 1, 11 => 2 }

    # True while a boulder stands on the lower floor: dropped from upstairs and not yet in a hole.
    def self.present?(id)
      $game_variables[53].to_i >= NEEDS[id] && !$game_self_switches[[LOWER, id, "A"]]
    end

    # The boulder of the lower floor standing at (x,y), or nil.
    def self.boulder_at(x, y)
      [10, 11].find do |id|
        ev = $game_map.events[id] rescue nil
        present?(id) && ev && ev.x == x && ev.y == y
      end
    end

    # True when EV12 looks at the boulder beside a hole: by the southern hole it reads EV11 only while EV10 stands off
    # columns 21 and 22.
    def self.read?(hole, id)
      return true unless hole == 8 && id == 11
      ev = $game_map.events[10] rescue nil
      !(ev && [21, 22].include?(ev.x))
    end

    # The press that drops a boulder now, as [hole event, tile to stand on, direction], or nil.
    def self.ready_press
      HOLES.each do |hole, *ways|
        next if filled?(hole)
        ways.each do |rock, stand, dir|
          id = boulder_at(rock[0], rock[1])
          return [hole, stand, dir] if id && read?(hole, id)
        end
      end
      nil
    end

    # The pushes that take each boulder from where it lands to beside its hole, as legs [start, direction, pushes]:
    # EV10 one push down to the right of the hole below, EV11 30 pushes round to the right of the northern one (simulated
    # push by push against the floor, auditoria/puzzles-2026-11/_pulido/sim/sevii/altering_sim.rb).
    PLAN = { 10 => [[[22, 29], 2, 1]],
             11 => [[[24, 28], 8, 11], [[24, 17], 6, 2], [[26, 17], 8, 2], [[26, 15], 6, 5], [[31, 15], 8, 7],
                    [[31, 8], 4, 3]] }
    # The hole each planned boulder goes into.
    PLAN_HOLE = { 10 => 8, 11 => 2 }
    # Direction => [its word, the side of the boulder to push it from].
    DIRS = { 2 => [:down, :sevii_side_above], 4 => [:left, :sevii_side_right], 6 => [:right, :sevii_side_left],
             8 => [:up, :sevii_side_below] }
    DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }

    # The next push of a boulder on its plan, as [direction, pushes left in it], or nil when it is off the plan.
    def self.next_push(id)
      ev = ($game_map.events[id] rescue nil)
      return nil unless ev
      PLAN[id].each do |leg|
        sx, sy = leg[0]
        d = leg[1]
        n = leg[2]
        dd = DELTA[d]
        n.times { |k| return [d, n - k] if ev.x == sx + dd[0] * k && ev.y == sy + dd[1] * k }
      end
      nil
    end

    # The assisted line of the lower floor: the press that drops a boulder, else the next push of the plan for a boulder
    # that is down here, else that none has come down yet, or that the first fills its hole and the second is still
    # upstairs, or that a boulder left the plan and leaving the floor puts both back.
    def self.lower_hint
      press = ready_press
      return [:sevii_altering_press, { :dir => PokeAccess::I18n.t("sevii_dir_#{press[2]}".to_sym) }] if press
      return nil if filled?(8) && filled?(2)
      fallen = $game_variables[53].to_i
      here = [10, 11].select { |id| present?(id) && !filled?(PLAN_HOLE[id]) }
      return :sevii_altering_none if here.empty? && fallen < NEEDS[10]
      return :sevii_altering_second if here.empty? && fallen < NEEDS[11]
      here.each do |id|
        push = next_push(id)
        return :sevii_altering_off_plan unless push
        word, side = DIRS[push[0]]
        return [:sevii_altering_push, { :side => PokeAccess::I18n.t(side), :dir => PokeAccess::I18n.t("sevii_dir_#{word}".to_sym),
                                        :n => push[1] }]
      end
      :sevii_altering_off_plan
    end
  end
end

PokeAccess::Game.define("sevii") do
  cave = PokeAccess::SeviiAlteringCave

  mechanic(:state, cave::UPPER) do
    auto
    name 6, lambda { |_ev| cave.crack_open? ? :sevii_altering_hole : :sevii_altering_crack }
    count :sevii_altering_fallen, :var => 53, :of => 2
    hint lambda { cave.crack_open? ? :sevii_altering_upper_push : :sevii_altering_upper_bike }
    solved(nil, :quiet => true) { $game_variables[53].to_i >= 2 }
  end

  mechanic(:state, cave::LOWER) do
    auto
    name [8, 2], lambda { |ev| cave.filled?(ev.id) ? :sevii_altering_hole_filled : :sevii_altering_hole }
    cave::HOLES.each do |hole, *ways|
      ways.each do |rock, stand, _dir|
        spot :at => stand, :label => :sevii_altering_press_here, :assist => true, :onto => true,
             :when => lambda { id = cave.boulder_at(rock[0], rock[1]); !cave.filled?(hole) && id && cave.read?(hole, id) }
      end
    end
    hint lambda { cave.lower_hint }
    solved(nil, :quiet => true) { cave.filled?(8) && cave.filled?(2) }
  end
end
