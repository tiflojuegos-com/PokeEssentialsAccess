# Opalo's Área 151, maps 441 and 449 to 457 (map 448 is a scene with no control): lasers of three colours (graphics
# rayosR, rayosV and rayosA) that go out while a colour panel has their colour on (switches 798, 797 and 799, one at a
# time), and magnetic doors (tile 1106, under a lintel of tile 1098 that is walked under) that open with the blue card
# (switch 800) or the red one (801); both cards' doors are drawn alike. Lasers are named by their colour, and the panels
# and the doors are named. Variable 249 carries the story: Genista's battle on map 452 sets it to 3; coming into map 455
# below 3 replays Apolo's scene and sends the player back to map 441, at 3 starts the scenes that end on map 454 with it
# at 25, and Apolo's floor on map 455 sets 30 and opens the way to the roof (map 456). With the assist, a phase for each
# step says the next step of a shortest way to the roof that never takes that scene back, by the region and the
# switches, also on the way back after a defeat by Apolo; it is quiet while an event runs on a map just come into, on the
# roof once Apolo's scene there has begun (variable 251), and once he is beaten (switch 847).
# STEPS, AREAS and RULES are generated: export.rb, in auditoria/puzzles-2026-11/_pulido/sim/opalo_3 outside the
# repository, learns them from the simulation of the area (story_sim.rb) and writes plan_data.rb, pasted here over the
# three constants (their headers kept); verify_profile.rb there checks this file against every state. Both read
# graph.bin, the simulated graph, which story_sim.rb rebuilds by itself in some minutes when it is missing.
module PokeAccess
  module OpaloArea151
    MAPS = [441, 449, 450, 451, 452, 453, 454, 455, 456, 457]
    STORY = 249
    ROOF_SCENE = 251
    ROOF = 456
    APOLO_BEATEN = 847
    COLOURS = [797, 798, 799]
    RED = 798
    KEYS = { :pad => :op_a151_next_pad, :exit => :op_a151_next_exit, :lift => :op_a151_next_lift,
             :panel => :op_a151_next_panel, :door => :op_a151_next_door, :card => :op_a151_next_item,
             :genista => :op_a151_next_genista, :apolo => :op_a151_next_apolo }
    # Each step: [kind, map, its events (the one nearest the player is told), the menu option to choose or the item].
    STEPS = [
      [:pad, 441, [14], nil], [:exit, 441, [10], nil], [:exit, 441, [9], nil], [:pad, 441, [13], nil],
      [:lift, 441, [17, 18], 0], [:exit, 441, [19, 20], nil], [:lift, 441, [17, 18], 1], [:pad, 441, [16], nil],
      [:pad, 441, [15], nil], [:panel, 441, [29, 32], 1], [:exit, 441, [49, 50], nil], [:exit, 441, [8], nil],
      [:lift, 449, [14, 15], 0], [:lift, 449, [14, 15], 1], [:exit, 449, [2, 3, 4], nil],
      [:door, 449, [29, 30, 31, 32], nil], [:pad, 449, [9], nil], [:pad, 449, [10], nil], [:pad, 449, [13], nil],
      [:exit, 449, [8], nil], [:pad, 449, [11], nil], [:door, 449, [37, 38], nil], [:panel, 449, [16, 17, 18], 2],
      [:exit, 450, [2], nil], [:exit, 450, [1], nil], [:lift, 450, [6, 7], 0], [:lift, 450, [6, 7], 1],
      [:door, 450, [25, 26, 27, 28], nil], [:card, 450, [20], :TARAZUL], [:pad, 450, [3], nil], [:pad, 450, [5], nil],
      [:panel, 450, [12, 13, 17], 2], [:panel, 450, [8, 9, 12, 13, 17], 1], [:pad, 450, [4], nil],
      [:pad, 450, [19], nil], [:door, 450, [37, 38, 39, 40], nil], [:exit, 451, [3], nil], [:exit, 451, [2], nil],
      [:exit, 451, [7, 8, 9], nil], [:exit, 452, [4], nil], [:exit, 452, [3], nil], [:genista, 452, [11, 12, 13], nil],
      [:exit, 453, [2, 3], nil], [:door, 453, [22, 23, 24, 25], nil], [:exit, 453, [4, 5], nil], [:pad, 453, [13], nil],
      [:exit, 454, [33, 34, 35], nil], [:exit, 454, [37, 38, 39], nil], [:exit, 454, [1], nil], [:pad, 454, [16], nil],
      [:exit, 454, [3], nil], [:pad, 454, [25], nil], [:card, 454, [26], :TARROJA], [:pad, 454, [13], nil],
      [:pad, 454, [15], nil], [:exit, 454, [19, 20, 21], nil], [:pad, 454, [5], nil], [:pad, 454, [6], nil],
      [:pad, 454, [9], nil], [:pad, 454, [10], nil], [:pad, 454, [17], nil], [:pad, 454, [8], nil],
      [:exit, 455, [7, 8], nil], [:apolo, 455, [25, 27, 28, 29], nil], [:apolo, 456, [5], nil]
    ]
    # Each map's rectangles [x0, x1, y0, y1, region], tried in order: the first holding the player tells the region.
    AREAS = {
      441 => [
        [2, 27, 6, 27, 2], [73, 84, 8, 24, 3], [19, 27, 32, 38, 4], [2, 27, 36, 57, 1], [74, 76, 33, 39, 5],
        [38, 77, 13, 57, 0]
      ],
      449 => [
        [2, 30, 23, 57, 1], [38, 61, 44, 56, 3], [5, 21, 6, 15, 4], [8, 57, 11, 43, 0], [63, 76, 16, 36, 2],
        [70, 72, 15, 15, 2], [65, 73, 5, 15, 5]
      ],
      450 => [
        [14, 35, 18, 31, 1], [2, 60, 1, 45, 0], [69, 83, 33, 41, 2], [70, 83, 13, 20, 3], [70, 75, 7, 12, 4]
      ],
      451 => [
        [10, 43, 7, 34, 0], [48, 50, 11, 26, 1]
      ],
      452 => [
        [3, 31, 2, 32, 0], [3, 31, 38, 42, 1], [22, 27, 33, 37, 0], [7, 12, 33, 37, 0], [3, 31, 35, 37, 1],
        [13, 21, 33, 33, 0], [3, 31, 33, 33, 1], [22, 31, 34, 34, 1], [15, 18, 34, 34, 1], [13, 21, 34, 34, 0],
        [3, 5, 34, 34, 1]
      ],
      453 => [
        [73, 85, 44, 55, 1], [2, 78, 3, 60, 0]
      ],
      454 => [
        [69, 93, 10, 54, 0], [36, 46, 3, 21, 2], [2, 16, 33, 44, 1], [46, 62, 49, 57, 3], [2, 19, 14, 22, 4],
        [16, 30, 49, 57, 5], [48, 61, 33, 39, 6], [21, 25, 33, 39, 7], [39, 43, 33, 39, 8], [30, 34, 33, 39, 9]
      ],
      455 => [
        [33, 72, 35, 53, 0]
      ],
      456 => [[0, 39, 0, 34, 0]]
    }
    # Each region's rules, tried in order, the first whose conditions all hold giving the step: a condition is the story
    # stage (:early below 3, :mid below 25, :scene below 30, :end) or a switch on (n) or off (-n).
    RULES = {
      441 => [
        [[[799], 0], [[797, 804], 0], [[:mid, 798], 0], [[:mid], 1], [[:scene, 798], 0], [[:end, 798], 2],
         [[:scene], 1], [[:end], 0], [[798, 800], 0], [[797], 1], [[], 3]],
        [[[:mid, -799], 4], [[:end], 5], [[799, 800], 6], [[800], 4], [[798], 6], [[], 4]],
        [[[-797, 800], 7], [[805], 7], [[804], 7], [[:mid], 8], [[:scene], 8], [[:end], 7], [[-798], 8], [[], 9]],
        [[[], 10]],
        [[[-798], 11], [[:mid], 4], [[:scene], 4], [[:end], 5], [[800], 4], [[], 6]],
        [[[-797], 1], [[804], 0], [[:mid], 1], [[:scene], 1], [[:end], 0], [[], 1]],
      ],
      449 => [
        [[[:end], 12], [[799, 800], 13], [[804], 14], [[800], 15], [[-799], 16], [[], 17]],
        [[[:mid, -799], 14], [[:scene, -799], 14], [[801, -804], 15], [[:end], 12], [[799, 804], 13], [[-799], 14],
         [[800], 15], [[], 14]],
        [[[:mid, -799], 18], [[:scene, -799], 18], [[:mid, 805], 19], [[:end, 797], 19], [[:end, 799], 20],
         [[800, -805], 21], [[801], 19], [[-799, 800], 18], [[800], 19], [[-797], 18], [[], 19]],
        [[[-799], 22], [[:mid], 13], [[:scene], 13], [[:end], 12], [[800], 13], [[], 17]],
        [[[-799], 17], [[:mid], 13], [[:scene], 13], [[:end], 12], [[800], 13], [[], 17]],
        [[[799, 806], 19], [[:mid, 797], 18], [[:end, -799], 19], [[-799, 805], 18], [[-799, 800], 21], [[807], 19],
         [[:mid], 19], [[:scene], 19], [[:end, 805], 20], [[], 19]],
      ],
      450 => [
        [[[:mid, 799], 23], [[:mid, 805], 24], [[:end, 806], 25], [[:mid, 806], 26], [[:scene, 799], 23],
         [[:scene, 805], 24], [[:end, 807], 25], [[801, 807], 26], [[:end], 27], [[801, -806], 24], [[:scene], 26],
         [[-799, 805], 24], [[799], 23], [[807], 26], [[800, -806], 24], [[800], 26], [[], 28]],
        [[[:end], 25], [[-799, 804], 26], [[799, 806], 23], [[806], 24], [[800, -807], 27], [[799, 800], 23],
         [[800], 24], [[-798], 26], [[], 29]],
        [[[799, 800], 30], [[:mid], 31], [[:scene], 31], [[:end, 805], 30], [[798, 800], 31], [[:end], 30],
         [[800], 31], [[-797], 32], [[], 30]],
        [[[:mid, -799], 33], [[799, 808], 34], [[805, -808], 33], [[:scene, -799], 33], [[801, -808], 35],
         [[:end], 34], [[-799], 33], [[800], 35], [[], 33]],
        [[[-808], 34], [[799], 34], [[:mid], 33], [[:scene], 33], [[:end], 34], [[], 33]],
      ],
      451 => [
        [[[-804], 36], [[:mid], 36], [[:scene], 36], [[:end], 37], [[], 36]],
        [[[], 38]],
      ],
      452 => [
        [[[:mid], 39], [[-799], 39], [[:scene], 39], [[:end], 40], [[], 41]],
        [[[-799], 40], [[:mid], 39], [[:scene], 39], [[:end], 40], [[], 41]],
      ],
      453 => [
        [[[810], 42], [[801], 43], [[], 44]],
        [[[], 45]],
      ],
      454 => [
        [[[:end], 46], [[:mid], 47], [[], 46]],
        [[[801], 48], [[], 49]],
        [[[], 50]],
        [[[801], 51], [[], 52]],
        [[[], 53]],
        [[[], 54]],
        [[[], 55]],
        [[[801], 56], [[], 57]],
        [[[801], 58], [[], 59]],
        [[[801], 60], [[], 61]],
      ],
      455 => [
        [[[:end], 62], [[], 63]],
      ],
      456 => [[[[], 64]]]
    }

    # The story stage, by variable 249.
    def self.stage
      v = $game_variables[STORY].to_i
      return :early if v < 3
      return :mid if v < 25
      v < 30 ? :scene : :end
    end

    # Whether switch s is on; with no colour lit yet, red counts as lit, as the floor of the way in lights it.
    def self.on?(s)
      return true if $game_switches[s]
      s == RED && COLOURS.none? { |c| $game_switches[c] }
    end

    # Whether every condition of a rule holds.
    def self.holds?(conds)
      conds.all? { |c| c.is_a?(Symbol) ? stage == c : on?(c.abs) == (c > 0) }
    end

    # The step for the player at (x, y) of map: the first rule of their region that holds; nil off the plan, on the roof
    # once Apolo's scene there has begun, and once he is beaten.
    def self.next_step(map, x, y)
      return nil if $game_switches[APOLO_BEATEN] || !AREAS[map]
      return nil if map == ROOF && $game_variables[ROOF_SCENE].to_i > 0
      box = AREAS[map].find { |b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
      return nil unless box
      rule = (RULES[map][box[4]] || []).find { |conds, _s| holds?(conds) }
      rule && rule[1]
    end

    # next_step for the player now, worked out once a frame and tile: every phase of the map asks it.
    def self.current
      key = [PokeAccess::World::Epoch.frame, $game_map.map_id, $game_player.x, $game_player.y]
      @memo = [key, next_step(key[1], key[2], key[3])] unless @memo && @memo[0] == key
      @memo[1]
    end

    # The step the phases follow: held while an event runs, so a ride or a scene does not go through the steps it crosses,
    # and none while one runs on a map just come into, such as a chain of scenes.
    def self.step
      return @step if ($game_system.map_interpreter.running? rescue false)
      @step = current
    end

    # Drops the held step and the frame's answer, on a new map.
    def self.forget
      @step = nil
      @memo = nil
    end

    # The steps taken on map, by their place in STEPS.
    def self.steps_on(map)
      (0...STEPS.size).select { |i| STEPS[i][1] == map }
    end

    # The step's event nearest the player.
    def self.nearest(ids)
      px = $game_player.x
      py = $game_player.y
      ids.map { |id| $game_map.events[id] }.compact.min_by { |ev| (ev.x - px) ** 2 + (ev.y - py) ** 2 }
    end

    # Where (x, y) lies from the player.
    def self.from_player(x, y)
      at = PokeAccess::Puzzles.offset_phrase(x - $game_player.x, y - $game_player.y)
      at.empty? ? PokeAccess::I18n.t(:loc_here) : at
    end

    # The words of option i of the menu the event asks, as the game gives them.
    def self.option(ev, i)
      menu = (PokeAccess.ivar(ev, :@list) || []).find { |c| c.code == 102 }
      word = menu && menu.parameters[0][i]
      word ? word.to_s : (i + 1).to_s
    end

    # The item's name as the game gives it.
    def self.item_name(sym)
      name = PokeAccess::Data.item_id(sym)[1].to_s
      name.empty? ? PokeAccess::I18n.t(:op_a151_card) : name
    rescue StandardError => e
      PokeAccess.swallowed(e)
      PokeAccess::I18n.t(:op_a151_card)
    end

    # The assist's line for the current step: what to use, where it lies and, for a lift or a panel, the option.
    def self.hint
      s = step
      return nil unless s
      kind, _map, ids, extra = STEPS[s]
      ev = nearest(ids)
      return nil unless ev
      vars = { :at => from_player(ev.x, ev.y) }
      vars[:choice] = option(ev, extra) if kind == :lift || kind == :panel
      vars[:item] = item_name(extra) if kind == :card
      [KEYS[kind], vars]
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::OpaloArea151.forget }

PokeAccess::Game.define("opalo") do
  area = PokeAccess::OpaloArea151
  mechanic(:state, area::MAPS) do
    auto
    obstacle(/\ArayosR\z/, :label => :op_laser_red)
    obstacle(/\ArayosV\z/, :label => :op_laser_green)
    obstacle(/\ArayosA\z/, :label => :op_laser_yellow)
    obstacle({ :tile => 1106 }, :label => :op_a151_door)
  end

  [[441, [29, 32]], [449, [16, 17, 18]], [450, [8, 9, 12, 13, 17]]].each do |map, panels|
    mechanic(:state, map, :part => :panel) do
      auto
      name panels, :op_color_panel, :grouped => true
    end
  end

  area::MAPS.each do |map|
    steps = area.steps_on(map)
    next if steps.empty?
    mechanic(:state, map, :part => :way) do
      auto
      steps.each do |s|
        phase lambda { PokeAccess::Puzzles.assist? && area.step == s }, :hint => lambda { area.hint }
      end
    end
  end
end
