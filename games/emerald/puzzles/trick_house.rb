# The Trick House off Route 110: each room ends at a door that opens once its scroll is read. Room 2 (map 222) needs
# its four floor pads in turn, (13,13), (2,5), (16,6) and (9,12), before the scroll at (16,15); room 6 (map 313) the
# switches at (17,23), (15,6) and (6,15) before the scroll at (6,12), and the one at (6,4) before the door; room 7 (map
# 314) four floor triggers that each turn a statue or a trainer one step round, pressed 7, 5, 5, 9 and 11 for the
# scroll and then 11, 9 and 11 for the door. Leaving room 7 puts its statues back but not its triggers' self switches
# nor vars 180 to 183, so a trigger left halfway turns its statues out of step on the next visit: the assist replays
# each trigger's pages (PAGES7) from the live flags, and while one is out of step says to finish the half turns and come
# back in. All checked by searches over each room; rooms 1, 3 and 5 are mazes the
# routes walk with their field moves, and 4 and 8 a boulder room and an ice room the routes push and slide through.
module PokeAccess
  module EmTrickHouse
    SCROLLS = { 168 => 19, 222 => 13, 275 => 7, 202 => 2, 313 => 12, 314 => 14 }
    STEPS = {
      222 => [[172, 4, [13, 13]], [173, 7, [2, 5]], [174, 10, [16, 6]], [179, 15, [9, 12]], [175, 13, [16, 15]],
              [177, 1, [15, 2]]],
      313 => [[1137, 7, [17, 23]], [1139, 9, [15, 6]], [1140, 1, [6, 15]], [1142, 12, [6, 12]], [1141, 11, [6, 4]],
              [1143, 13, [19, 3]]]
    }
    SWITCHES = { 222 => [4, 7, 10, 15], 313 => [1, 6, 7, 9, 11] }
    ROOM7 = 314
    SCROLL7 = 1147
    TRIGGERS7 = [7, 5, 9, 11]
    AT7 = { 7 => [16, 21], 5 => [8, 16], 9 => [17, 9], 11 => [14, 8], :scroll => [14, 19], :door => [21, 3] }
    LAYOUTS7 = {
      7 => [{ 4 => [16, 19], 3 => [17, 22] }, { 4 => [16, 20], 3 => [16, 22] }, { 4 => [17, 20], 3 => [16, 23] },
            { 4 => [17, 19], 3 => [17, 23] }],
      5 => [{ 6 => [12, 19] }, { 6 => [11, 19] }, { 6 => [11, 20] }, { 6 => [12, 20] }],
      9 => [{ 8 => [18, 4] }, { 8 => [18, 5] }, { 8 => [19, 5] }, { 8 => [19, 4] }],
      11 => [{ 10 => [12, 8] }, { 10 => [11, 8] }, { 10 => [11, 9] }, { 10 => [12, 9] }]
    }
    PLANS7 = [[[0, 0, 0, 0], [7, 5, 5, 9, 11]], [[1, 2, 1, 1], [11, 9, 11]]]
    VARS7 = { 7 => 180, 5 => 181, 9 => 182, 11 => 183 }
    PAGES7 = {}
    { 7 => [{ 4 => [0, 1], 3 => [-1, 0] }, { 4 => [1, 0], 3 => [0, 1] }, { 4 => [0, -1], 3 => [1, 0] },
            { 4 => [-1, 0], 3 => [0, -1] }],
      5 => [{ 6 => [-1, 0] }, { 6 => [0, 1] }, { 6 => [1, 0] }, { 6 => [0, -1] }],
      9 => [{ 8 => [0, 1] }, { 8 => [1, 0] }, { 8 => [0, -1] }, { 8 => [-1, 0] }],
      11 => [{ 10 => [-1, 0] }, { 10 => [0, 1] }, { 10 => [1, 0] }, { 10 => [0, -1] }] }.each do |t, moves|
      var = VARS7[t]
      PAGES7[t] = [[1, nil, false, moves[0], [var, :set, 0], true]] +
                  (1..3).map { |i| [1, [var, i - 1], true, moves[i], [var, :set, i], true] } +
                  [[3, [var, 3], true, {}, [var, :sub, 4], false]]
    end

    # The next step of a room of switches: [switch, event, [x, y]] of the first not on yet, or nil.
    def self.next_step(map)
      STEPS[map].find { |sw, _, _| !$game_switches[sw] }
    end

    # The assist's line in a room of switches: the next control, the scroll or the door, and where it lies.
    def self.hint(map)
      step = next_step(map)
      return nil unless step
      sw, id, (x, y) = step
      key = if id == SCROLLS[map] then :em_trick_scroll_hint
            elsif sw == STEPS[map].last[0] then :em_trick_door_hint
            else :em_trick_next
            end
      [key, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end

    # The layout index of each trigger's statues in room 7, in TRIGGERS7's order; nil where one matches none.
    def self.layouts7
      TRIGGERS7.map { |t| PokeAccess::EmPuzzles.layout_index(LAYOUTS7[t]) }
    end

    # The next trigger of room 7's plan from its statues now: the plan's own while they stand on it, else the first
    # whose statues differ from the plan's last layout; :done once that layout stands, nil when a statue matches none.
    def self.next7
      now = layouts7
      return nil if now.include?(nil)
      start, plan = PLANS7[$game_switches[SCROLL7] ? 1 : 0]
      vec = start.dup
      plan.each do |t|
        return t if vec == now
        i = TRIGGERS7.index(t)
        vec[i] = (vec[i] + 1) % 4
      end
      return :done if vec == now
      plan.find { |t| now[TRIGGERS7.index(t)] != vec[TRIGGERS7.index(t)] }
    end

    # Whether trigger t's statues stand in one of their layouts and its next four steps turn them through the rest.
    def self.in_step7?(t)
      i = PokeAccess::EmPuzzles.layout_index(LAYOUTS7[t])
      return false unless i
      PokeAccess::EmPuzzles.replay(ROOM7, t, PAGES7[t], 4) == (1..4).map { |k| LAYOUTS7[t][(i + k) % 4] }
    end

    # The assist's line while a trigger turns out of step: the steps that finish a half turn left over, the first
    # first, or, with none left, leaving the room and coming back in; nil while every trigger is in step.
    def self.recover7
      return nil if TRIGGERS7.all? { |t| in_step7?(t) }
      half = TRIGGERS7.find { |t| $game_self_switches[[ROOM7, t, "A"]] }
      return :em_trick7_reenter unless half
      x, y = AT7[half]
      [:em_trick7_finish, { :n => [3 - $game_variables[VARS7[half]].to_i, 1].max, :place => PokeAccess::EmPuzzles.place(x, y) }]
    end

    # The assist's line in room 7: how to set the triggers back in step, or the trigger to step on next, the scroll or
    # the door.
    def self.hint7
      fix = recover7
      return fix if fix
      step = next7
      return :em_trick7_reenter unless step
      if step == :done
        x, y = AT7[$game_switches[SCROLL7] ? :door : :scroll]
        return [$game_switches[SCROLL7] ? :em_trick_door_hint : :em_trick_scroll_hint, { :place => PokeAccess::EmPuzzles.place(x, y) }]
      end
      x, y = AT7[step]
      [:em_trick_next, { :place => PokeAccess::EmPuzzles.place(x, y) }]
    end
  end
end

PokeAccess::Game.define("emerald") do
  trick = PokeAccess::EmTrickHouse
  trick::SCROLLS.each do |map, id|
    mechanic(:state, map, :part => :scroll) do
      auto
      name id, :em_trick_scroll
    end
  end

  trick::STEPS.each do |map, steps|
    mechanic(:state, map) do
      auto
      steps.each { |sw, _, _| watch :switch => sw, :quiet => true }
      controls
      name trick::SWITCHES[map], :em_trick_switch
      phase lambda { PokeAccess::Puzzles.assist? && trick.next_step(map) }, :quiet => true, :hint => lambda { trick.hint(map) }
      solved(nil, :quiet => true) { !trick.next_step(map) }
    end
  end

  mechanic(:state, trick::ROOM7) do
    auto
    name [3, 6, 10], :em_statue
    name trick::TRIGGERS7, :em_statue_switch, :assist => true
    on_use trick::TRIGGERS7, :em_statues_turned
    phase lambda { PokeAccess::Puzzles.assist? }, :quiet => true, :hint => lambda { trick.hint7 }
  end
end
