# Aelita's Nightmare Realm (map 33): floor arrows (events 22 to 25, 40, 41, 47) push the player a tile the way the lit
# colour gives (yellow 1362 south, blue 1365 west, green 1363 north, magenta 1364 east), and nowhere while none is lit;
# a blocked push leaves the player on the arrow. Lavender's flight from Risa is variable 684, 62 to 66.
module PokeAccess
  module RejuvNightmareArrows
    MAP = 33
    ARROWS = [22, 23, 24, 25, 40, 41, 47]
    COLOURS = [[1362, :rjf_nm_yellow], [1363, :rjf_nm_green], [1364, :rjf_nm_magenta], [1365, :rjf_nm_blue]]
    BUTTONS = { 27 => 1363, 28 => 1364, 29 => 1362, 30 => 1363, 31 => 1363, 32 => 1365, 33 => 1365, 34 => 1365,
                35 => 1365, 36 => 1364, 39 => 1364, 48 => 1362, 52 => 1363, 104 => 1362, 105 => 1362 }
    # step of the flight (variable 684) => [the point it runs to, stood on]
    GOALS = { 62 => [19, false], 63 => [79, true], 64 => [48, true], 65 => [52, true], 66 => [84, true] }
    # The zones the plan reads, each the boxes [x0, x1, y0, y1] that cover it. Zone 8 also takes the hall's column at x
    # 43, plain floor at step 62 (its hooks, events 79, 98 and 99, wait for step 63), where zones 6 and 8 read alike.
    ZONES = {
      0 => [[1, 10, 29, 47], [11, 11, 46, 46]], 4 => [[54, 73, 38, 54]], 5 => [[11, 13, 41, 45]],
      6 => [[31, 42, 41, 51]], 7 => [[13, 21, 45, 47]], 8 => [[43, 48, 45, 47]], 9 => [[79, 85, 45, 47]],
      11 => [[11, 13, 47, 51]], 13 => [[65, 67, 56, 58]], 14 => [[4, 15, 61, 66], [11, 17, 65, 68]],
      15 => [[16, 21, 61, 64], [20, 22, 65, 67]], 16 => [[23, 30, 61, 66], [28, 30, 67, 67]],
      17 => [[40, 46, 61, 66]], 18 => [[7, 7, 67, 67]], 19 => [[22, 26, 67, 71], [23, 23, 72, 72]],
      20 => [[4, 9, 68, 72], [10, 11, 69, 70]], 23 => [[11, 17, 70, 72]],
      27 => [[5, 11, 72, 77], [18, 22, 72, 77], [4, 4, 73, 77], [12, 17, 74, 77]], 28 => [[25, 30, 72, 73]],
      29 => [[24, 24, 73, 73]], 30 => [[23, 30, 74, 77]], 31 => [[9, 14, 89, 96]], 32 => [[20, 26, 89, 91]],
      33 => [[32, 46, 89, 101]], 34 => [[7, 14, 98, 106]], 35 => [[20, 26, 99, 106]],
      36 => [[7, 48, 121, 126], [49, 52, 124, 125]], 37 => [[49, 50, 121, 122]]
    }
    # Where Risa's blow sends the player back from the first zones (15,15), and all that is walked from there with any
    # colour: no arrow leads on, the way back is the lift (event 14, used facing it from 3,14) down to 3,29, zone 0.
    LIFT_ZONE = [[1, 26, 4, 21]]
    LIFT = 14
    # The room of the crimson quartz, which the lift at 20,3 (event 67, used with the action key) leads to: its way
    # out is the floor at 38,13 (event 68), stepped on, which brings the player back by 20,4, above the arrows.
    QUARTZ_ROOM = [[35, 41, 7, 12]]
    QUARTZ_FLOOR = 68
    # North of the arrow at (66,37): the lifts' lobby and the moving floors and lifts it leads to (events 56 to 64),
    # entered only with green lit; up to step 64 nothing there leads out.
    LOOP = [[65, 67, 32, 36], [59, 73, 68, 72], [79, 84, 70, 72], [90, 95, 70, 72], [101, 103, 53, 72], [98, 106, 46, 52]]
    # The colour room (zones 14 to 30), the same at every step: zone => {colour lit => the button to press next}.
    ROOM = { 16 => { 1363 => 35, 1365 => 30 }, 18 => { 1362 => 27, 1363 => 28, 1365 => 27 }, 19 => { 1363 => 35 },
             20 => { 1363 => 28, 1364 => 29, 1365 => 28 }, 23 => { 1362 => 34, 1364 => 29 },
             27 => { 1362 => 36, 1364 => 33, 1365 => 36 }, 28 => { 1363 => 35, 1365 => 31 },
             29 => { 1364 => 33, 1365 => 31 }, 30 => { 1362 => 32, 1363 => 35, 1365 => 36 } }
    LATER = ROOM.dup.merge!(0 => { 1362 => 27, 1365 => 104 }, 5 => { 1363 => 39 },
                            11 => { 1362 => 27, 1363 => 39, 1365 => 27 }, 14 => { 1362 => 27, 1363 => 39, 1365 => 27 },
                            15 => { 1363 => 39, 1365 => 30 }, 17 => { 1363 => 39 }, 36 => { 1362 => 52 },
                            37 => { 1362 => 52 })
    HALL = { 1362 => 27, 1364 => 105 }
    PLAN = {
      62 => ROOM.dup.merge!(0 => { 1362 => 27, 1365 => 104 }, 4 => HALL, 6 => HALL, 7 => HALL, 8 => HALL, 9 => HALL,
                            11 => { 1362 => 27, 1365 => 27 }, 13 => { 1362 => 52 }, 14 => { 1362 => 27, 1365 => 27 },
                            15 => { 1365 => 30 }, 31 => { 1362 => 27, 1364 => 48 }, 32 => HALL, 33 => HALL,
                            34 => HALL, 35 => HALL, 36 => { 1362 => 52 }, 37 => { 1362 => 52 }),
      63 => LATER.dup.merge!(13 => { 1362 => 52 }),
      64 => LATER.dup.merge!(13 => { 1362 => 52 }),
      65 => LATER.dup.merge!(4 => { 1364 => 105 }, 5 => { 1363 => 39, 1364 => 105 }, 6 => { 1364 => 105 },
                             7 => { 1364 => 105 }, 8 => { 1364 => 105 }, 9 => { 1364 => 105 },
                             17 => { 1363 => 39, 1364 => 105 }, 31 => { 1364 => 48 }, 32 => { 1364 => 48 },
                             33 => { 1364 => 48 }, 34 => { 1364 => 105 }, 35 => { 1364 => 105 }, 36 => {}, 37 => {}),
      66 => LATER.dup.merge!(4 => { 1362 => 52, 1364 => 105 }, 5 => { 1363 => 39, 1364 => 105 },
                             6 => { 1362 => 52, 1364 => 105 }, 7 => { 1362 => 52, 1364 => 105 },
                             8 => { 1362 => 52, 1364 => 105 }, 9 => { 1362 => 52, 1364 => 105 }, 13 => { 1362 => 52 },
                             17 => { 1363 => 39, 1364 => 105 }, 31 => { 1362 => 52, 1364 => 48 },
                             32 => { 1362 => 52, 1364 => 48 }, 33 => { 1362 => 52, 1364 => 48 },
                             34 => { 1362 => 52, 1364 => 105 }, 35 => { 1362 => 52, 1364 => 105 })
    }

    # The switch of the colour lit now, or nil.
    def self.lit_switch
      c = COLOURS.find { |sw, _key| $game_switches[sw] }
      c && c[0]
    end

    # The colour lit now, its word's key, or nil.
    def self.lit
      c = COLOURS.find { |sw, _key| $game_switches[sw] }
      c && c[1]
    end

    # A colour's word, by its switch.
    def self.word(sw); PokeAccess::I18n.t(COLOURS.find { |s, _key| s == sw }[1]); end

    # A button's name by the colour it lights.
    def self.button(ev); [:rjf_nm_button, { :color => word(BUTTONS[ev.id]) }]; end

    # What a button shows as it is stepped on: its colour lit, unless it already is.
    def self.lights(ev)
      sw = BUTTONS[ev.id]
      $game_switches[sw] ? nil : [:rjrb_nm_lights, { :color => word(sw) }]
    end

    # The info line: the colour lit, or nil while none is.
    def self.info_line
      key = lit
      key ? [:rjf_nm_lit, { :color => PokeAccess::I18n.t(key) }] : nil
    end

    # The step of the flight, variable 684, while it runs (62 to 66), else nil.
    def self.step
      v = $game_variables[684].to_i
      GOALS.key?(v) ? v : nil
    end

    # Whether the player stands in one of these boxes, [x0, x1, y0, y1] each.
    def self.within?(boxes)
      x = $game_player.x
      y = $game_player.y
      boxes.any? { |b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
    end

    # The zone the player stands in, or nil.
    def self.zone
      hit = ZONES.find { |_k, boxes| within?(boxes) }
      hit && hit[0]
    end

    # The plan's next move, worked out once a frame: [:press, button], [:go, point], or nil off the flight.
    def self.advice
      key = [$game_map.map_id, PokeAccess::World::Epoch.frame]
      return @advice[1] if @advice && @advice[0] == key
      @advice = [key, plan_advice]
      @advice[1]
    end

    # Whether the player stands where Risa sends them back to, above the arrows.
    def self.above?; within?(LIFT_ZONE); end

    # The plan's next move from the zone and colour lit: the lift from above the arrows, the floor out of the crimson
    # quartz's room, nothing to do in the lifts' loop while it is shut, a button to press, else the step's point.
    def self.plan_advice
      s = step
      return nil unless s
      return [:lift, LIFT] if above?
      return [:floor, QUARTZ_FLOOR] if within?(QUARTZ_ROOM)
      col = lit_switch
      return nil unless col
      return [:shut, nil] if s < 66 && within?(LOOP)
      z = zone
      b = z && (PLAN[s][z] || {})[col]
      b ? [:press, b] : [:go, GOALS[s][0]]
    end

    # The assist's line for a move of the plan.
    def self.hint(move)
      return PokeAccess::I18n.t(:rjrc_nm_lift) if move[0] == :lift
      return PokeAccess::I18n.t(:rjrv3_nm_quartz_out) if move[0] == :floor
      return PokeAccess::I18n.t(:rjrv2_nm_shut) if move[0] == :shut
      return PokeAccess::I18n.t(:rjrb_nm_go, :color => word(lit_switch)) if move[0] == :go
      PokeAccess::I18n.t(:rjrb_nm_press, :color => word(BUTTONS[move[1]]))
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  nm = PokeAccess::RejuvNightmareArrows
  arrows = PokeAccess::RejuvFloorArrows
  mechanic(:state, nm::MAP, :part => :arrows) do
    auto
    name nm::ARROWS, lambda { |ev| arrows.label(ev, :rjf_nm_arrow) }
    name nm::BUTTONS.keys, lambda { |ev| nm.button(ev) }
    on_use nm::BUTTONS.keys, lambda { |ev| nm.lights(ev) }
    avoid nm::BUTTONS.keys, :assist => true
    info { PokeAccess::Puzzles.label_of(nm.info_line) }
    active { !nm.lit.nil? }
  end
  mechanic(:state, nm::MAP, :part => :flight) do
    auto
    moves = nm::BUTTONS.keys.map { |id| [:press, id] } + nm::GOALS.values.map { |id, _onto| [:go, id] }.uniq +
            [[:lift, nm::LIFT], [:floor, nm::QUARTZ_FLOOR]]
    labels = { :press => :rjrb_nm_spot_button, :go => :rjrb_nm_spot_goal, :lift => :rjrc_nm_spot_lift,
               :floor => :rjrv3_nm_spot_quartz_floor }
    moves.each do |mv|
      onto = mv[0] == :press || mv[0] == :floor || (mv[0] == :go && nm::GOALS.values.assoc(mv[1])[1])
      label = labels[mv[0]]
      phase lambda { PokeAccess::Puzzles.assist? && nm.advice == mv }, :quiet => true,
            :hint => lambda { nm.hint(mv) }, :spots => [{ :event => mv[1], :label => label, :assist => true, :onto => onto }]
    end
    shut = [:shut, nil]
    phase lambda { PokeAccess::Puzzles.assist? && nm.advice == shut }, :quiet => true, :hint => lambda { nm.hint(shut) }
    active { PokeAccess::Puzzles.assist? && !nm.advice.nil? }
  end
end
