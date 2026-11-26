# 1R253 Scrapyard. Map 663: nine engines (variables 363 to 371) run their track when their cab is touched and stop at
# what is in the way; Rock Smash rocks close five tracks. The north line's engine (event 100) goes to map 692 once three
# wagons are off its line (369 at 2, 366 and 368 at 1). Map 692: two trains clear the last engine's column.
module PokeAccess
  module RebornScrapyard
    EAST = [[91, 110, 65, 78], [106, 110, 61, 64], [107, 110, 58, 60], [96, 99, 63, 64]]
    BEHIND = [[34, 40, 32, 38], [29, 37, 39, 41], [29, 33, 42, 46]]
    WEST = [[0, 40, 31, 41], [0, 33, 42, 49], [0, 38, 50, 51], [0, 39, 52, 63], [0, 41, 64, 68], [0, 42, 69, 73]]
    YARD_CABS = { 22 => :dir_n, 35 => :dir_n, 64 => :dir_n, 75 => :dir_o, 102 => :dir_e, 113 => :dir_e,
                  146 => :dir_o, 150 => :dir_o, 154 => :dir_s, 94 => :dir_n, 100 => :dir_n }
    YARD_WRECKS = [31, 38, 70, 87, 109, 127, 140, 156]
    LINE_CABS = { 70 => :dir_o, 71 => :dir_o, 89 => :dir_s, 90 => :dir_s, 91 => :dir_s }
    LINE_WRECKS = [19, 59, 69, 84]
    TRAIN10 = { 0 => 91, 1 => 90, 2 => 89 }

    def self.v(id)
      $game_variables[id].to_i
    end

    def self.s(id)
      $game_switches[id] ? true : false
    end

    # A cab's name, by the way its engine points.
    def self.cab(table, ev)
      [:rbb_sy_cab, { :dir => PokeAccess::I18n.t(table[ev.id]) }]
    end

    def self.inside?(boxes)
      x = $game_player.x
      y = $game_player.y
      boxes.any? { |b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
    end

    # The part of map 663 the player is in while no engine has joined it to the main yard.
    def self.area
      return :east if v(369) == 0 && inside?(EAST)
      return :main if v(368) >= 1
      return :behind if inside?(BEHIND)
      return :west if inside?(WEST)
      :main
    end

    # The main yard's next step toward clearing the north line: the rock in the way of an engine, then that engine to
    # ride, in the order the wagons come off; nil once its wagons are off (366 at 1, 369 at 2).
    def self.main_step
      return :rbb_sy_rock3 if v(366) == 0 && v(365) == 0 && !s(833)
      return :rbb_sy_ride3 if v(366) == 0 && v(365) == 0
      return :rbb_sy_rock4 if v(366) == 0 && !s(831)
      return :rbb_sy_ride4 if v(366) == 0
      return :rbb_sy_ride1 if v(369) < 2 && v(363) == 0
      return :rbb_sy_rock7 if v(369) == 0 && !s(834)
      return :rbb_sy_go_east if v(369) == 0
      return :rbb_sy_ride7_rest if v(369) == 1
      nil
    end

    # The next step in the west part or behind it (where): the rock behind the building and the way back, the way in
    # from the desert, then the west's two engines; nil once they have joined it to the main yard and run.
    def self.west_step(where)
      return(s(830) ? :rbb_sy_back : :rbb_sy_rock6) if where == :behind
      joined = v(368) >= 1
      return nil if joined && v(371) >= 1
      return :rbb_sy_go_west unless joined || where == :west
      return :rbb_sy_ride5 if v(371) == 0
      s(830) ? :rbb_sy_ride6 : :rbb_sy_behind
    end

    # With the assist, map 663's next step as things stand where the player is.
    def self.yard_hint
      where = area
      return(s(834) ? :rbb_sy_ride7 : :rbb_sy_east_rock) if where == :east
      step = where == :main ? nil : west_step(where)
      step ||= main_step || west_step(:main)
      return step if step
      ev = $game_map.events[100]
      ev ? [:rbb_sy_ride9, { :x => ev.x, :y => ev.y, :fx => ev.x + 1 }] : nil
    end

    # With the assist, map 692's next step.
    def self.line_hint
      return :rbb_sy_ride_small1 if v(372) == 0
      return :rbb_sy_ride_small3 if v(373) == 0
      ev = $game_map.events[TRAIN10[v(374)].to_i]
      ev ? [:rbb_sy_ride10, { :x => ev.x, :y => ev.y, :fx => ev.x - 1 }] : nil
    end

    def self.door_pocket?
      $game_player.x >= 51 && $game_player.y >= 42 && $game_player.y <= 46
    end
  end
end

PokeAccess::Game.define("reborn") do
  sy = PokeAccess::RebornScrapyard
  mechanic(:state, 663, :part => :yard) do
    auto
    name sy::YARD_CABS.keys, lambda { |ev| sy.cab(sy::YARD_CABS, ev) }, :when => lambda { |ev| ev.id != 94 || sy.v(371) == 0 }
    name sy::YARD_WRECKS, :rbb_sy_wreck
    name(/\AJunkTrain/, :rbb_sy_junk)
    name(/\ABustARock/, :rbb_sy_track_rocks, :grouped => true)
    name(/\APinball Cars/, :rbb_sy_parked, :grouped => true)
    hide(/Block|\AImpass|\ATrain\d+(-\d+)?\z|\ATrain\d+Stop\z/)
    hide 94, :when => lambda { |_ev| sy.v(371) >= 1 }
    arrival_hint :rbb_sy_rule, :once => true
    hint lambda { sy.yard_hint }
    active { sy.v(371) < 2 }
    solved(nil, :quiet => true) { sy.v(371) >= 2 }
  end
  mechanic(:state, 692, :part => :line) do
    auto
    name sy::LINE_CABS.keys, lambda { |ev| sy.cab(sy::LINE_CABS, ev) }
    name sy::LINE_WRECKS, :rbb_sy_wreck
    name(/\AScoot(Train\d|[13][L0A-E](-2)?)\z/, :rbb_sy_small_wagons, :grouped => true)
    name(/\APinball/, :rbb_sy_parked, :grouped => true)
    name(/\ABustARock/, :rbb_sy_track_rocks, :grouped => true)
    hide(/Block|\AImpasse|\ATrain10(-\d)?\z|\ATrain10Stop\z|\ACruuush\z/)
    hint lambda { sy.line_hint }
    active { sy.v(374) < 3 && !sy.door_pocket? }
    solved(:rbb_sy_line_done) { sy.v(374) >= 3 }
  end
end
