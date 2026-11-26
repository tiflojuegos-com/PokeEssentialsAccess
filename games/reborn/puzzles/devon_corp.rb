# Devon Corp: the shock floors ("Buzzy" events) of the old building (maps 623, 624, 626) and the sub-puzzles (629 to
# 631), each with three pages by variable 342, the pattern the radio cycles; a page calling pbFieldDamage shocks (an
# eighth of the party's HP). Switches 1562 to 1564 power the new floors down; spinners (629 to 631) turn variable 343.
module PokeAccess
  module RebornDevon
    PANEL_MAPS = [623, 624, 626, 629, 630, 631]
    SPIN_MAPS = [629, 630, 631]
    STEP = { 1 => [0, 1], 2 => [-1, 0], 3 => [1, 0], 4 => [0, -1], 5 => [-1, 1], 6 => [1, 1], 7 => [-1, -1], 8 => [1, -1] }
    SPINNERS = { 630 => [[4, 6], [8, 6], [12, 6]], 629 => [[4, 16], [16, 20], [22, 25], [22, 11]], 631 => [[22, 24]] }
    POWER = { 629 => 1563, 630 => 1562, 631 => 1564 }
    SPIN_BACK = [:rbb_devon630_d, :rbb_devon629_a, :rbb_devon629_b, :rbb_devon629_c]
    STEPS631 = { :rbb_devon631_a => :a, :rbb_devon631_b => :b, :rb1_devon631_off => :off, :rbb_devon631_c => :c,
                 :rbb_devon631_d => :d, :rbb_devon631_e => :e, :rbb_devon631_f => :f, :rbb_devon631_g => :g }
    SET_SWITCHES631 = [761] + (769..775).to_a
    DIRS = { 8 => :dir_n, 2 => :dir_s, 4 => :dir_o, 6 => :dir_e }
    DELTA = { 8 => [0, -1], 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0] }
    # The walkable areas of map 631, tiles as x * 100 + y.
    AREAS631 = [
      [611, 612, 711, 712, 811, 812, 911, 912, 1011, 1012, 1013, 1014, 1110, 1111, 1112, 1210, 1211, 1212, 1309, 1310,
       1311, 1312, 1408, 1409, 1410, 1411, 1412, 1508, 1509, 1510, 1511, 1512, 1513, 1514, 1609, 1610, 1611, 1612, 1613,
       1710, 1711, 1712, 1810, 1811, 1812, 1911, 1912],
      [920, 921, 922, 923, 924, 925, 926, 1021, 1022, 1023, 1024, 1025, 1026, 1120, 1121, 1122, 1221, 1321, 1421, 1520,
       1521],
      [1317, 1318, 1416, 1417],
      [1716, 1717, 1719, 1720, 1721, 1722, 1723, 1724, 1816, 1817, 1818, 1819, 1820, 1821, 1822, 1823, 1824, 1914, 1915,
       1916, 1917, 1919, 1920, 1921, 1922, 1923, 1924, 2021, 2024],
      [1905, 2005, 2104, 2105, 2204, 2205, 2304, 2305, 2403, 2404, 2405, 2503, 2504, 2505, 2506, 2507, 2603, 2604, 2605,
       2704, 2705, 2804, 2805, 2806],
      [2110, 2210, 2310, 2410, 2411],
      [2326, 2425, 2426, 2525, 2526, 2625, 2725, 2825, 2925, 3025],
      [2609, 2610, 2611, 2709, 2710, 2711, 2809, 2810, 2811, 2911, 3011],
      [2913, 2915, 3013, 3014, 3015],
      [2917, 3017],
      [2919, 2920, 2921, 3021],
      [2923, 3023],
      [1116],
      [1314],
      [1518],
      [2019],
      [2122],
      [2226],
      [2512],
      [2916],
      [2924],
      [3012],
      [3015],
    ]
    # Per entry: [steps, spinner switches or :any, index into AREAS631, the first move of a fewest-moves way to the
    # step's goal as [from x, from y, :walk or :act, direction, lands x, lands y]].
    RECOVERY631 = [
      [[:a, :b, :off, :c], :any, 0, [15, 14, :walk, 2, 15, 18]],
      [[:a, :b, :off, :c], :any, 1, [11, 20, :walk, 8, 11, 16]],
      [[:a], :any, 2, [14, 16, :act, 8, 14, 16]],
      [[:a, :b, :off, :c], :any, 12, [11, 16, :walk, 8, 10, 14]],
      [[:a, :b, :off, :c], :any, 13, [13, 14, :walk, 4, 10, 14]],
      [[:a], :any, 14, [15, 18, :walk, 4, 13, 18]],
      [[:b], :any, 2, [14, 16, :walk, 6, 15, 18]],
      [[:b], [[769], [769, 770]], 3, [20, 24, :walk, 6, 21, 22]],
      [[:b], [[], [761], [761, 770], [770]], 3, [20, 24, :walk, 6, 22, 26]],
      [[:b], [[761], [761, 769], [761, 769, 770], [761, 770]], 6, [29, 25, :walk, 8, 29, 24]],
      [[:b], [[], [769], [769, 770], [770]], 6, [30, 25, :act, 8, 30, 25]],
      [[:b], :any, 10, [30, 21, :act, 2, 30, 21]],
      [[:b], :any, 11, [30, 23, :act, 8, 30, 23]],
      [[:b, :off, :c], :any, 14, [15, 18, :walk, 6, 18, 18]],
      [[:b, :off, :c], :any, 15, [20, 19, :walk, 2, 19, 20]],
      [[:b], :any, 16, [21, 22, :walk, 4, 19, 22]],
      [[:b, :off], [[761, 769], [761, 769, 770]], 17, [24, 25, :walk, 8, 29, 24]],
      [[:b], [[], [769], [769, 770], [770]], 17, [30, 25, :act, 8, 30, 25]],
      [[:b, :off], [[761], [761, 770]], 17, [22, 26, :walk, 8, 29, 24]],
      [[:b], :any, 20, [30, 23, :act, 8, 30, 23]],
      [[:off, :c], :any, 3, [20, 24, :walk, 6, 22, 26]],
      [[:off], :any, 6, [30, 25, :act, 8, 30, 25]],
      [[:off], :any, 11, [30, 23, :act, 2, 30, 23]],
      [[:off], :any, 20, [29, 24, :act, 6, 29, 24]],
      [[:c], [[770]], 6, [29, 25, :walk, 8, 29, 20]],
      [[:c], [[], [769], [769, 770]], 6, [29, 25, :walk, 8, 22, 26]],
      [[:c], :any, 10, [29, 20, :act, 6, 29, 20]],
      [[:c], [[770]], 11, [29, 23, :walk, 2, 29, 20]],
      [[:c], [[], [769], [769, 770]], 11, [29, 23, :walk, 2, 22, 26]],
      [[:c], [[], [769], [769, 770]], 17, [24, 25, :walk, 8, 22, 26]],
      [[:c], [[770]], 17, [24, 25, :walk, 8, 29, 20]],
      [[:c], [[770]], 20, [29, 24, :walk, 4, 29, 20]],
      [[:c], [[], [769], [769, 770]], 20, [29, 24, :walk, 4, 22, 26]],
      [[:d], [[770]], 6, [24, 25, :walk, 8, 22, 26]],
      [[:d], [[770, 772]], 6, [24, 25, :walk, 8, 29, 16]],
      [[:d], :any, 9, [30, 17, :act, 8, 30, 17]],
      [[:d, :e], :any, 10, [29, 20, :walk, 4, 22, 26]],
      [[:d], [[770, 772]], 17, [24, 25, :walk, 8, 29, 16]],
      [[:d], [[770]], 17, [24, 25, :walk, 8, 22, 26]],
      [[:d], :any, 19, [29, 16, :act, 6, 29, 16]],
      [[:d], [[769, 771, 773], [769, 771, 773, 775]], 22, [30, 15, :act, 2, 30, 15]],
      [[:e], :any, 5, [24, 10, :act, 8, 24, 10]],
      [[:e], [[770], [770, 772]], 6, [24, 25, :walk, 8, 22, 26]],
      [[:e], [[770, 772, 774], [770, 772, 774, 775]], 6, [24, 25, :walk, 8, 25, 12]],
      [[:e], :any, 9, [29, 17, :walk, 8, 29, 16]],
      [[:e], [[770], [770, 772]], 17, [24, 25, :walk, 8, 22, 26]],
      [[:e], [[770, 772, 774], [770, 772, 774, 775]], 17, [24, 25, :walk, 8, 25, 12]],
      [[:e], [[769, 771, 773, 775]], 18, [25, 12, :walk, 4, 22, 10]],
      [[:e], [[769, 771, 773]], 18, [25, 12, :walk, 4, 22, 26]],
      [[:e], :any, 19, [29, 16, :walk, 4, 22, 26]],
      [[:f], :any, 5, [24, 10, :walk, 6, 25, 12]],
      [[:f], :any, 6, [24, 25, :walk, 8, 30, 12]],
      [[:f], :any, 7, [26, 9, :act, 8, 26, 9]],
      [[:f, :g], :any, 8, [30, 13, :walk, 8, 30, 12]],
      [[:f], :any, 17, [24, 25, :walk, 8, 30, 12]],
      [[:f], :any, 18, [25, 12, :walk, 6, 30, 12]],
      [[:f], :any, 21, [26, 9, :act, 8, 26, 9]],
      [[:g], :any, 4, [25, 3, :walk, 8, 25, 3]],
      [[:g], :any, 7, [26, 9, :walk, 4, 25, 7]],
      [[:g], :any, 21, [26, 11, :walk, 4, 25, 7]],
    ]

    # The current map's id, or 0 before one is loaded.
    def self.map_id
      ($game_map.map_id rescue 0)
    end

    # An event's live page commands, or none.
    def self.list_of(ev)
      list = PokeAccess.ivar(ev, :@list)
      list.is_a?(Array) ? list : []
    end

    # True for a shock floor whose live page shocks.
    def self.shocks?(ev)
      return false unless ev.name.to_s == "Buzzy"
      list_of(ev).any? { |c| (c.code == 355 || c.code == 655) && c.parameters[0].to_s =~ /pbFieldDamage/ }
    end

    # The carry a spinner's edge gives as it stands: the sum of the steps its page moves the player.
    def self.spinner_carry(ev)
      return nil unless SPIN_MAPS.include?(map_id)
      list = list_of(ev)
      return nil unless list.any? { |c| c.code == 122 && c.parameters[0] == 343 }
      mv = list.find { |c| c.code == 209 && c.parameters[0] == -1 }
      return nil unless mv
      dx = 0
      dy = 0
      mv.parameters[1].list.each do |m|
        d = STEP[m.code]
        next unless d
        dx += d[0]
        dy += d[1]
      end
      dx == 0 && dy == 0 ? nil : [:carry, dx, dy, false, nil, nil]
    end

    # The tiles that shock now, kept per map, pattern and power.
    def self.shock_tiles
      key = [map_id, $game_variables[342].to_i, POWER.values.map { |s| $game_switches[s] ? 1 : 0 }]
      return @shock[1] if @shock && @shock[0] == key
      tiles = {}
      ($game_map.events || {}).each_value { |ev| tiles[[ev.x, ev.y]] = true if shocks?(ev) }
      @shock = [key, tiles]
      tiles
    end

    # Map631's next move from the player's tile, [from x, from y, :walk or :act, direction, lands x, lands y], or nil
    # when the state is not one the plan's computers allow; kept per step, switches and tile.
    def self.recovery_move
      step = STEPS631[step_key]
      return nil unless step
      set = SET_SWITCHES631.select { |s| $game_switches[s] }
      tile = $game_player.x * 100 + $game_player.y
      key = [step, set, tile]
      return @move[1] if @move && @move[0] == key
      row = RECOVERY631.find do |steps, sets, area, _m|
        steps.include?(step) && (sets == :any || sets.include?(set)) && AREAS631[area].include?(tile)
      end
      @move = [key, row && row[3]]
      @move[1]
    end

    # The tile Map631's next move starts from, or nil.
    def self.recovery_from
      m = map_id == 631 && recovery_move
      m ? m[0, 2] : nil
    end

    # Map631's next move told: a computer to use, a step that rides to where it says, or the step out; nil off the table.
    def self.recovery_hint
      m = recovery_move
      return nil unless m
      fx, fy, kind, d, lx, ly = m
      dir = PokeAccess::I18n.t(DIRS[d])
      if kind == :act
        dx, dy = DELTA[d]
        return [:rbrj_devon_use, { :x => fx, :y => fy, :cx => fx + dx, :cy => fy + dy, :dir => dir }]
      end
      return [:rbrj_devon_exit, { :x => fx, :y => fy, :dir => dir }] if lx == fx && ly == fy
      [:rbrj_devon_ride, { :x => fx, :y => fy, :dir => dir, :lx => lx, :ly => ly }]
    end

    # The assisted step of a sub-puzzle; one that enters spinners each entry turns round says how to undo a wrong turn.
    # In 631, the next move from where the player stands, or the step's whole way when the state is off the table.
    def self.hint
      key = step_key
      return(recovery_hint || key) if map_id == 631
      return key unless SPIN_BACK.include?(key)
      PokeAccess.sentences([PokeAccess::I18n.t(key), PokeAccess::I18n.t(:rb1_devon_spin_back)])
    end

    # The step of a sub-puzzle, read from its belt switches; a computer left on that the next belt needs off comes first.
    def self.step_key
      sw = lambda { |id| $game_switches[id] }
      case map_id
      when 630
        return :rbb_devon630_a unless sw.call(747)
        return :rb1_devon630_off if sw.call(746) && !sw.call(749)
        return :rbb_devon630_b unless sw.call(749)
        return :rbb_devon630_c unless sw.call(748)
        :rbb_devon630_d
      when 629
        return :rbb_devon629_a unless sw.call(753)
        return :rbb_devon629_b unless sw.call(755)
        return :rbb_devon629_c unless sw.call(754)
        return :rbb_devon629_d unless sw.call(756)
        :rbb_devon629_e
      when 631
        return :rbb_devon631_a unless sw.call(764)
        return :rbb_devon631_b unless sw.call(762)
        return :rb1_devon631_off if sw.call(761)
        return :rbb_devon631_c unless sw.call(763)
        return :rbb_devon631_d unless sw.call(765)
        return :rbb_devon631_e unless sw.call(766)
        return :rbb_devon631_f unless sw.call(767)
        :rbb_devon631_g
      else
        :rbb_devon_panels_assist
      end
    end
  end
end

PokeAccess::Routes::Effects.touch_source { |ev| PokeAccess::RebornDevon.spinner_carry(ev) }

PokeAccess::Game.define("reborn") do
  devon = PokeAccess::RebornDevon
  tile_cost(:maps => devon::PANEL_MAPS, :assist => true) { |x, y| devon.shock_tiles[[x, y]] ? 6 : 0 }
  devon::PANEL_MAPS.each do |map|
    mechanic(:state, map, :part => :devon) do
      auto
      name(/\ABuzzy\z/, lambda { |ev| devon.shocks?(ev) ? :rbb_devon_panel_on : :rbb_devon_panel_off }, :grouped => true)
      watch :var => 342, :label => :rbb_devon_pattern, :number => true
      (devon::SPINNERS[map] || []).each_with_index do |xy, i|
        spot :at => xy, :label => [:rbb_devon_spinner, { :n => i + 1 }]
      end
      if map == 631
        spot :at => lambda { devon.recovery_from }, :label => :rbrj_devon_from, :assist => true, :onto => true,
             :when => lambda { !devon.recovery_from.nil? }
      end
      arrival_hint :rbb_devon_panels_rule, :once => true
      hint lambda { devon.hint }
      solved(nil, :quiet => true) { devon::POWER[map] && $game_switches[devon::POWER[map]] }
    end
  end
end
