# Smuggling Tunnels (map 405, Case Seven): wall switches with no graphic lower or raise the spikes of their colour from
# a menu, coupled as the entrance sign says (red down puts green up, blue up puts red down, black ones their own spikes,
# the master all back up). Stairs run only with their spikes lowered; the way out (EV70) opens beside or below Francis.
module PokeAccess
  module AshenSmugglingTunnels
    MAP = 405
    RED = 142
    BLUE = 143
    GREEN = 144
    FRANCIS = 71
    EXIT = 70
    CODES = "abcdefghijklmnopqrstuvwxyz"
    # Switch event => [colour, its number among those of its colour].
    SWITCHES = { 3 => [:red, 1], 5 => [:red, 2], 32 => [:red, 3], 9 => [:blue, 1], 17 => [:blue, 2], 7 => [:blue, 3],
                 10 => [:blue, 4], 15 => [:green, 1], 16 => [:green, 2], 20 => [:black, 1], 22 => [:black, 2],
                 24 => [:black, 3], 27 => [:master, 0] }
    # Spikes event => [colour, the black switch that moves it].
    SPIKES = { 4 => [:red], 8 => [:red], 28 => [:red], 29 => [:red], 6 => [:blue], 12 => [:blue], 13 => [:blue],
               14 => [:blue], 26 => [:blue], 11 => [:green], 18 => [:green], 19 => [:green], 21 => [:black, 1],
               23 => [:black, 2], 25 => [:black, 3] }
    # The spikes each black switch lowers through its self switch A.
    BLACK = { 1 => 21, 2 => 23, 3 => 25 }
    SWITCH_LABELS = { :red => :afb_switch_red, :blue => :afb_switch_blue, :green => :afb_switch_green,
                      :black => :afb_switch_black }
    SPIKE_LABELS = { :red => :afb_spikes_red, :blue => :afb_spikes_blue, :green => :afb_spikes_green,
                     :black => :afb_spikes_black }
    ACTION_LABELS = { :lower => :afb_action_lower, :raise => :afb_action_raise, :restart => :afb_action_restart }
    # The branch of each colour's menu, as right_choice reads it: what the option sets.
    CHOICES = { [:red, :lower] => { :switch => RED, :to => true }, [:red, :raise] => { :switch => RED, :to => false },
                [:blue, :lower] => { :switch => BLUE, :to => false }, [:blue, :raise] => { :switch => BLUE, :to => true },
                [:green, :lower] => { :switch => GREEN, :to => true }, [:green, :raise] => { :switch => GREEN, :to => false },
                [:master, :restart] => { :switch => RED, :to => false } }
    # The part of the map each tile belongs to, one letter of CODES per tile (the walls part it with every spike up).
    AREAS = %w[
      .......................................................
      .......................................................
      .......................................................
      .......................................................
      .......................................................
      .......................................................
      .....aa...........aaa.aa.aaa......aa......a.aaaaa......
      .....aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa.aaaaaaaaa......
      ......aaaaaaaaaaa....aaaaaaaaaaa....aaaaaaaaaaaaa......
      ......aaaaaa...aa....aaaaaaaaaaa....aaaaaaaaa..aa......
      ......aaaa..........................b..................
      ....................................b..................
      ....................................b..................
      ......................ccccc.........b..................
      ......................ccccc.........b..................
      ...............d.......ccc.........bb....ee............
      ..........dddd.d......ccccc.f.......b..eeeee...........
      ......dddddddddd....f......ff.......b..eeeee...........
      .....ddddddd.ddd....ff.....ff.......b..eeeee...........
      .....dddddddddd.....fffffffff.......b..eeeee.eee.......
      ............dddd....fffffffff.......b..ee.eeeeeee......
      .............ddd....f.ff.ffff.......b...e.eeee.ee......
      .............dd.....fffff...f.......b..eee......e......
      ........gg..gggg............g....hh.b..h..h............
      ........gggggggggg.g........g.hhhhhhbhhhhhhhhhh........
      .....ggggggggggggggggggggggggghhhhhhhhhhhhhhhhhh.......
      .....ggggggggggggggggggggggggghhhhhhhhhhhhhhhhhh.......
      .....gg...g...gg....ggggggggg....hh....hhhhhhhhhh......
      ......gg....................................hhhhh......
      ......gg....................................hhhhh......
      ......ggg.....................................h.h......
      ......gggg............i.iii............................
      .....gggg.............iiiii.................jjj.j......
      .....gg...............iii.i...................jjj......
      .....gggg.kkkkk.....iiiiiiiii.................jjj......
      .....gggggk..kk......iiiiiii................jjjjj......
      ......g.ggkkkk......iiiiiiiii...............jjj........
      ........ggkkkkk.............................jjj........
      ......ggg.kkkkkk............................jjj........
      .....gggggkkk.kk.......kk....................jjj.......
      ...........kkkkk.....kkkkkk.................jjjjj......
      ..........kkkkkk.....kkkkkkkk..........lllll...........
      ..........kkkkkkk..kkkkkkkkkkk..llllllllllll...........
      ..........kkkkkkkkkkkkkkkkkkkkkkklllllllllll...........
      ..........k.k.kkkkkkkkkkkkkkkkkkkll..lllllll...........
      ..........kkkkkkk....................lllllll...........
      .......kkkkkkkk.k......................lllll...........
      .....kkkkkkkkk.....................ll..lllll.lll.......
      .....kkk.kkkkk.........kkkkkkk.....lll.lllll.lll.......
      .....kkkkkkkkk.......kkkkkkkkkk....lllllllllllll.......
      ......kkkkk.........kkkkkkkkkkkk.........ll............
      ........k.k.........kkkkkkkkkkkk........llll...........
      ........kkkkkk......kkkkkkkkkkk.........llll...........
      ........kkkkkkkkkkkkkkk.......kk........llll...........
      ...........kkkkkkkkkkkk.......k.........llll...........
      ...........kkk......kkkkkkkmkkk.........llll...........
      ...........k...........kkkkkkkk.......llllllllll.......
      ..........kk..........................lll.ll...........
      ......................................llll.............
      .......................................................
      .......................................................
      .......................................................
      .......................................................
      .......................................................
      .......................................................
    ]
    # ACTIONS: the presses as [switch event, verb]. POLICY: per switch state, one character per part of AREAS: "-" the
    # state cannot reach it, "0" the way is open, else the place in ACTIONS of the first press, in base 36 from 1.
    ACTIONS = [[3, :lower], [5, :raise], [22, :lower], [9, :lower], [15, :lower], [5, :lower], [7, :lower], [17, :lower], [27, :restart], [10, :lower], [20, :lower], [3, :raise]]
    POLICY = %w[
      1-2--5------- 2-2--3------- -----5------- 9-4--5-------
      1-31-3------- 3-33-3------- 9-39-3------- 9-49-3-------
      1-2-15------- 2-2-23------- -----5------- 9-4-85-------
      1-3113------- 3-3333------- 9-3993------- 9-4983-------
      --6--50-0-00- 000--5000000- -----5------- cc4--5007a0a-
      1161-6010-000 0000-00000000 bb4b-40---0-0 bb4b-4007a0a0
      116-15010-00- 000-05000000- -----5------- 884-85007a0a-
      116116010-000 0000000000000 8848840---0-0 884884007a0a0
      --2--3------- 2-2--3------- -----3------- 9-4--3-------
      1-31-3------- 3-33-3------- 9-39-3------- 9-49-3-------
      1-2-13------- 2-2-23------- -----3------- 9-4-83-------
      1-3113------- 3-3333------- 9-3993------- 9-4983-------
      --6--50-0-00- 000--5000000- -----5------- cc4--5000a0a-
      1161-6010-000 0000-00000000 bb4b-40-0-0-0 bb4b-4000a0a0
      116-15010-00- 000-05000000- -----5------- 884-85000a0a-
      116116010-000 0000000000000 8848840-0-0-0 884884000a0a0
    ]

    # By [x, y, d], a press toward d onto the stairs: the landing tiles (Francis' once beaten, raised spikes included)
    # and, by state as in POLICY, "-" for no ride else the landing's place from 1. A ride fires no stair it passes.
    STAIR_HOPS = {
      [7, 10, 2] => [[[7, 17]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [7, 17, 8] => [[[7, 10]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [7, 39, 2] => [[[7, 46]], "1111111111111111111111111111111111111111111111111111111111111111"],
      [7, 46, 8] => [[[7, 39]], "1111111111111111111111111111111111111111111111111111111111111111"],
      [24, 9, 2] => [[[24, 13]], "-1---1---1---1---1---1---1---1---1---1---1---1---1---1---1---1--"],
      [24, 13, 8] => [[[24, 9]], "-1---1---1---1---1---1---1---1---1---1---1---1---1---1---1---1--"],
      [24, 16, 2] => [[[24, 19]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [24, 19, 8] => [[[24, 16]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [24, 27, 2] => [[[24, 31]], "11--11--11--11--11--11--11--11--11--11--11--11--11--11--11--11--"],
      [24, 31, 8] => [[[24, 27]], "11--11--11--11--11--11--11--11--11--11--11--11--11--11--11--11--"],
      [24, 36, 2] => [[[24, 39]], "--------------------------------11111111111111111111111111111111"],
      [24, 39, 8] => [[[24, 36]], "--------------------------------11111111111111111111111111111111"],
      [27, 52, 2] => [[[27, 55]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [27, 55, 8] => [[[27, 52]], "----1111----1111----1111----1111----1111----1111----1111----1111"],
      [41, 9, 2] => [[[41, 15]], "1111111111111111111111111111111111111111111111111111111111111111"],
      [41, 15, 8] => [[[41, 9]], "1111111111111111111111111111111111111111111111111111111111111111"],
      [46, 40, 2] => [[[46, 47]], "-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1"],
      [46, 47, 8] => [[[46, 40]], "-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1-1"]
    }
    STAIR_TILES = STAIR_HOPS.keys.map { |x, y, _d| [x, y] }.uniq

    # True on a tile a staircase is taken from.
    def self.stair_from?(x, y)
      STAIR_TILES.include?([x, y])
    end

    # Where a press toward d from (x,y) lands on the stairs in the switches' state now; nil with no ride that way.
    def self.stair_hop(x, y, d)
      lands, codes = STAIR_HOPS[[x, y, d]]
      return nil unless lands
      code = codes[state, 1]
      code == "-" ? nil : lands[code.to_i(36) - 1]
    end

    # Whether a self switch of this map's event is on.
    def self.self_on?(ev, letter = "A")
      $game_self_switches[[MAP, ev, letter]] ? true : false
    end

    # The switches' state as the plan numbers it: red lowered 1, blue raised 2, green lowered 4, black I, II and III
    # lowered 8, 16 and 32.
    def self.state
      s = 0
      s |= 1 if $game_switches[RED]
      s |= 2 if $game_switches[BLUE]
      s |= 4 if $game_switches[GREEN]
      BLACK.each { |n, ev| s |= 4 << n if self_on?(ev) }
      s
    end

    # Whether the spikes event stands lowered now.
    def self.lowered?(ev)
      colour, n = SPIKES[ev]
      case colour
      when :red then $game_switches[RED] ? true : false
      when :blue then !$game_switches[BLUE]
      when :green then $game_switches[GREEN] ? true : false
      else self_on?(BLACK[n])
      end
    end

    # The first press of the way from where the player stands: [event, verb], :open when the way needs none, nil off the
    # plan.
    def self.next_press
      row = AREAS[$game_player.y]
      part = row && CODES.index(row[$game_player.x, 1].to_s)
      return nil unless part
      code = POLICY[state][part, 1]
      return nil if code.nil? || code == "-"
      code == "0" ? :open : ACTIONS[code.to_i(36) - 1]
    end

    # Whether Francis has been beaten.
    def self.francis_beaten?; self_on?(FRANCIS); end

    # Whether the tunnels are still to cross: the way out to the well not yet taken.
    def self.live?
      $game_map.map_id == MAP && !self_on?(EXIT)
    end

    # A switch's name: its colour and number, or the master switch.
    def self.switch_label(ev)
      colour, n = SWITCHES[ev]
      return :afb_switch_master if colour == :master
      [SWITCH_LABELS[colour], { :n => n }]
    end

    # A spikes event's name: its colour (and black switch) and whether it stands up or down.
    def self.spikes_label(ev)
      colour, n = SPIKES[ev]
      t = PokeAccess::I18n
      [:afb_spikes_named, { :spikes => t.t(SPIKE_LABELS[colour], :n => n), :state => t.t(lowered?(ev) ? :afb_spikes_down : :afb_spikes_up) }]
    end

    # The assist's line for a press: the switch and what to do with it.
    def self.press_hint(press)
      t = PokeAccess::I18n
      [:afb_tunnels_next, { :switch => PokeAccess::Puzzles.label_of(switch_label(press[0])), :action => t.t(ACTION_LABELS[press[1]]) }]
    end

    # The menu option a switch's next press takes, for right_choice; nil when it is not the switch to press.
    def self.choice(ev)
      press = next_press
      return nil unless press.is_a?(Array) && press[0] == ev
      CHOICES[[SWITCHES[ev][0], press[1]]]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  tunnels = PokeAccess::AshenSmugglingTunnels
  terrain_exit(:maps => tunnels::MAP, :tiles => lambda { |x, y| tunnels.stair_from?(x, y) }) do |x, y, dir|
    tunnels.stair_hop(x, y, dir[2])
  end
  mechanic(:state, tunnels::MAP) do
    auto
    not_control tunnels::SWITCHES.keys
    tunnels::SWITCHES.each_key do |ev|
      name ev, lambda { |e| tunnels.switch_label(e.id) }
      right_choice ev, :takes => lambda { tunnels.choice(ev) }
    end
    name tunnels::SPIKES.keys, lambda { |e| tunnels.spikes_label(e.id) }, :when => false
    watch :switch => tunnels::RED, :label => :afb_spikes_red, :on => :afb_spikes_down, :off => :afb_spikes_up
    watch :switch => tunnels::BLUE, :label => :afb_spikes_blue, :on => :afb_spikes_up, :off => :afb_spikes_down
    watch :switch => tunnels::GREEN, :label => :afb_spikes_green, :on => :afb_spikes_down, :off => :afb_spikes_up
    tunnels::BLACK.each do |n, ev|
      watch :self => [ev, "A"], :label => [:afb_spikes_black, { :n => n }], :on => :afb_spikes_down, :off => :afb_spikes_up
    end
    arrival_hint :afb_tunnels_rule
    solved(nil, :quiet => true) { tunnels.francis_beaten? }
    tunnels::ACTIONS.uniq.each do |press|
      phase lambda { PokeAccess::Puzzles.assist? && tunnels.live? && tunnels.next_press == press },
            :hint => lambda { tunnels.press_hint(press) }, :hidden => right_way(press[0])
    end
    phase lambda { PokeAccess::Puzzles.assist? && tunnels.live? && !tunnels.francis_beaten? && tunnels.next_press == :open },
          :hint => :afb_tunnels_to_francis, :hidden => right_way(tunnels::FRANCIS)
    phase lambda { PokeAccess::Puzzles.assist? && tunnels.live? && tunnels.francis_beaten? && tunnels.next_press == :open },
          :hint => :afb_tunnels_to_exit, :hidden => right_way(tunnels::EXIT)
  end
end
