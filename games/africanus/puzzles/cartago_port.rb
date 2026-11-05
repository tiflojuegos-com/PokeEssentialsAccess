# Cartago's harbour (maps 59, 258, 259 and 260): six tests open the north door toward Hannibal (event 43 of map 59 turns
# switch 298 on): the box guided to (13, 29) (switch 293), the five boxes in order (292), the pulse against the commander
# (variable 104 at 3), the three copper conductors (variable 99 at 3), the four knots of the shipyard (variable 98 at 4)
# and the three customers of the tavern (variable 100 at 3). The boxes move one tile the way the player faces, from
# the other side; the tavern's berries pile up in variables 101 Tamate, 103 Peragu and 102 Aranja until a customer is served.
# With switch 298 on the harbour says no more of its rule on arriving, nor of its tests on the info key.
module PokeAccess
  # The harbour's six tests as the north door counts them.
  module AfricanusPort
    # Each test's name and the check of whether the game counts it done.
    def self.tests
      [[:af_test_box, lambda { $game_switches[293] }],
       [:af_test_boxes, lambda { $game_switches[292] }],
       [:af_test_pulse, lambda { $game_variables[104] == 3 }],
       [:af_test_conductors, lambda { $game_variables[99] == 3 }],
       [:af_test_knots, lambda { $game_variables[98] == 4 }],
       [:af_test_tavern, lambda { $game_variables[100] == 3 }]]
    end

    # How many of the six tests are done.
    def self.done
      tests.select { |_key, check| check.call }.length
    end

    # The tests still to do, as a label for the assist's line, or nil when none is left.
    def self.missing
      left = tests.reject { |_key, check| check.call }.map { |key, _check| PokeAccess::I18n.t(key) }
      left.empty? ? nil : [:af_tests_missing, { :list => left.join(", ") }]
    end

    # Whether the box of event, which belongs at column of the top row, is not there yet.
    def self.out_of_place?(event, column)
      box = $game_map.events[event]
      !(box && box.x == column && box.y == 5)
    end

    # Whether the assist asks for that box.
    def self.misplaced?(event, column)
      PokeAccess::Puzzles.assist? && out_of_place?(event, column)
    end
  end
end

PokeAccess::Game.define("africanus") do
  tests = proc do
    auto
    active { !$game_switches[298] }
    info { [:af_port_tests, { :n => PokeAccess::AfricanusPort.done }] }
    hint lambda { PokeAccess::AfricanusPort.missing }
  end
  mechanic(:state, [59, 258, 259, 260], :part => :tests, &tests)

  mechanic(:state, 59, :part => :box) do
    auto
    name 1, :af_box
    arrival_hint :af_port_rule, :once => true
    solved { $game_switches[298] }
    phase(lambda { !$game_switches[293] }, :title => :af_box_title, :hint => :af_box_hint,
          :track => { :event => 1, :label => :af_box, :goal => [13, 29, 13, 29], :goal_label => :af_box_goal })
  end

  mechanic(:state, 59, :part => :tavern) do
    auto
    name [30, 31], [:af_berry, { :kind => "Tamate" }]
    name [32, 33], [:af_berry, { :kind => "Peragu" }]
    name [34, 35], [:af_berry, { :kind => "Aranja" }]
    name 28, :af_barman
    hide 29
    watch :var => 101, :label => [:af_berries, { :kind => "Tamate" }], :number => true
    watch :var => 103, :label => [:af_berries, { :kind => "Peragu" }], :number => true
    watch :var => 102, :label => [:af_berries, { :kind => "Aranja" }], :number => true
    watch :switch => 295, :say => :af_beer_ready
    watch :switch => 296, :say => :af_wine_ready
    count :af_customers, :var => 100, :of => 3
    active { $game_switches[294] && !$game_switches[297] }
    solved(nil) { $game_switches[297] }
    hint :af_tavern_hint
  end

  boxes = [[5, :af_box_yellow, 3], [2, :af_box_green, 6], [6, :af_box_purple, 9], [4, :af_box_red, 12],
           [3, :af_box_blue, 15]]
  mechanic(:state, 259) do
    auto
    name 2, :af_box_green
    name 3, :af_box_blue
    name 4, :af_box_red
    name 5, :af_box_yellow
    name 6, :af_box_purple
    name 7..11, :af_symbol, :numbered => true
    name 1, :af_boxes_reset
    solved(nil) { $game_switches[292] }
    count :af_boxes_placed, :of => boxes.length, :assist => true, :reset => false, :value => lambda {
      boxes.select { |event, _label, column| !PokeAccess::AfricanusPort.out_of_place?(event, column) }.length
    }
    boxes.each do |event, label, column|
      phase(lambda { PokeAccess::AfricanusPort.misplaced?(event, column) },
            :title => :af_boxes_title, :hint => :af_boxes_hint, :quiet => true,
            :track => { :event => event, :label => label, :goal => [column, 5, column, 5], :goal_label => :af_box_goal })
    end
  end

  mechanic(:state, 258) do
    auto
    name [4, 5, 24, 25], lambda { |ev| $game_self_switches[[258, ev.id, "A"]] ? :af_knot_cut : :af_knot }
    obstacle({ :tile => 3164 }, :label => :af_posts)
    count :af_knots, :var => 98, :of => 4
    solved(nil) { $game_variables[98] == 4 }
    arrival_hint :af_knots_rule
  end

  mechanic(:state, 260) do
    auto
    name 2..4, :af_conductor
    count :af_conductors, :var => 99, :of => 3
    solved(nil) { $game_variables[99] == 3 }
    arrival_hint :af_conductors_rule
  end
end
