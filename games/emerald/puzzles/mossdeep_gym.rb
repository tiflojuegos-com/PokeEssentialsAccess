# Mossdeep Gym (map 452): floor switches turn their statues one step round a square with each step onto them, four
# steps to a full turn. The way to Tate and Liza needs the statues of the switch at (16,34) (events 48 to 50) two steps
# on, those of the switch at (8,5) (events 40 to 44) three, and those of the hidden switch at (1,10) (events 17 and 34
# to 36) anywhere but one step on; the switch at (2,18) does not matter. Checked by a search over every layout of the
# four groups. LAYOUTS holds each group's four layouts in turn, from the one the map draws. The gym's door starts the
# turns of 51 and 45 over, but leaves var 62 of the hidden switch as it was, so its statues may turn out of step after
# a visit: the assist replays its pages (HIDDEN_PAGES) from the live flags to tell how many steps reopen the way, or
# that leaving by the door, which puts every statue back, does.
module PokeAccess
  module EmMossdeep
    MAP = 452
    BEATEN = 10
    STATUES = [17, 23, 24, 34, 35, 36, 40, 41, 42, 43, 44, 48, 49, 50]
    SWITCHES = { 51 => [16, 34], 45 => [8, 5], 25 => [2, 18] }
    HIDDEN = 38
    HIDDEN_AT = [1, 10]
    LAYOUTS = {
      51 => [{ 48 => [13, 33], 49 => [13, 34], 50 => [12, 34] }, { 48 => [12, 33], 49 => [13, 33], 50 => [13, 34] },
             { 48 => [12, 34], 49 => [12, 33], 50 => [13, 33] }, { 48 => [13, 34], 49 => [12, 34], 50 => [12, 33] }],
      45 => [{ 40 => [7, 4], 41 => [6, 4], 42 => [6, 5], 43 => [11, 4], 44 => [12, 4] },
             { 40 => [6, 4], 41 => [6, 5], 42 => [7, 5], 43 => [11, 5], 44 => [11, 4] },
             { 40 => [6, 5], 41 => [7, 5], 42 => [7, 4], 43 => [12, 5], 44 => [11, 5] },
             { 40 => [7, 5], 41 => [7, 4], 42 => [6, 4], 43 => [12, 4], 44 => [12, 5] }],
      38 => [{ 34 => [4, 8], 17 => [5, 8], 35 => [9, 7], 36 => [11, 8] },
             { 34 => [5, 8], 17 => [5, 7], 35 => [9, 8], 36 => [10, 8] },
             { 34 => [5, 7], 17 => [4, 7], 35 => [10, 8], 36 => [10, 9] },
             { 34 => [4, 7], 17 => [4, 8], 35 => [10, 7], 36 => [11, 9] }]
    }
    OPEN = { 51 => [2], 45 => [3], 38 => [0, 2, 3] }
    HIDDEN_PAGES = [
      [1, [62, 0], false, { 34 => [1, 0], 17 => [0, -1], 35 => [0, 1], 36 => [-1, 0] }, [62, :add, 1], true],
      [1, [62, 1], true, { 34 => [0, -1], 17 => [-1, 0], 35 => [1, 0], 36 => [0, 1] }, [62, :add, 1], true],
      [1, [62, 2], true, { 34 => [-1, 0], 17 => [0, 1], 35 => [0, -1], 36 => [1, 0] }, [62, :add, 1], true],
      [1, [62, 3], true, { 34 => [0, 1], 17 => [1, 0], 35 => [-1, 0], 36 => [0, -1] }, [62, :add, 1], true],
      [3, [62, 4], true, {}, [62, :sub, 4], false]
    ]

    # The index of the layout group's statues stand in now, or nil when they match none.
    def self.layout(group)
      PokeAccess::EmPuzzles.layout_index(LAYOUTS[group])
    end

    # Whether group's statues leave the way open.
    def self.open?(group)
      OPEN[group].include?(layout(group))
    end

    # The assist's line for group 51 or 45: how many more steps onto its switch, and where it is; or the way to start
    # over.
    def self.press_hint(group)
      now = layout(group)
      return :em_mossdeep_reset_hint unless now
      x, y = SWITCHES[group]
      [:em_mossdeep_press_hint, { :n => (OPEN[group][0] - now) % 4, :place => PokeAccess::EmPuzzles.place(x, y) }]
    end

    # The steps onto the hidden switch that reopen the way, replayed from its live flags, or nil when none do.
    def self.hidden_steps
      futures = PokeAccess::EmPuzzles.replay(MAP, HIDDEN, HIDDEN_PAGES, 4)
      k = futures.index { |lay| OPEN[38].include?(LAYOUTS[38].index(lay)) }
      k ? k + 1 : nil
    end

    # The assist's line while the hidden switch's statues shut the way: the steps onto it that reopen it, or leaving by
    # the gym's door and coming back without stepping on it.
    def self.hidden_hint
      n = hidden_steps
      place = PokeAccess::EmPuzzles.place(HIDDEN_AT[0], HIDDEN_AT[1])
      n ? [:em_mossdeep_press_hint, { :n => n, :place => place }] : [:em_mossdeep_hidden_reset, { :place => place }]
    end

    # The hidden switch's name with the assist: a switch to step on while that reopens the way, a trap otherwise.
    def self.hidden_label
      !open?(38) && hidden_steps ? :em_statue_switch : :em_mossdeep_hidden
    end
  end
end

PokeAccess::Game.define("emerald") do
  gym = PokeAccess::EmMossdeep
  mechanic(:state, gym::MAP) do
    auto
    name gym::STATUES, :em_statue
    name gym::SWITCHES.keys, :em_statue_switch
    name gym::HIDDEN, lambda { |_ev| gym.hidden_label }, :assist => true
    avoid gym::HIDDEN, :assist => true
    on_use gym::SWITCHES.keys + [gym::HIDDEN], :em_statues_turned
    phase lambda { PokeAccess::Puzzles.assist? && !gym.open?(51) }, :quiet => true,
          :hint => lambda { gym.press_hint(51) }
    phase lambda { PokeAccess::Puzzles.assist? && !gym.open?(45) }, :quiet => true,
          :hint => lambda { gym.press_hint(45) }
    phase lambda { PokeAccess::Puzzles.assist? && !gym.open?(38) }, :quiet => true, :hint => lambda { gym.hidden_hint }
    phase lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => :em_mossdeep_open_hint
    arrival_hint :em_mossdeep_rule, :once => true
    solved { $game_switches[gym::BEATEN] }
  end
end
