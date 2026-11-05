# The water gym of Quartz City (map 116). Levers of four colours switch on the jets and the jump tiles of their colour
# (switches 171 red, 172 yellow, 173 green, 174 lilac; all the levers of a colour share its switch), and variable 64
# counts the colours on, two at most. Bumping into a lit jump tile throws the player two tiles over it, so two of a colour
# in a row are a bridge between parts of the gym. REGIONS, LEVERS and BRIDGES are those parts, the levers in them and the
# bridges between them, read from the map data; the assist plans over them, from the part the player stands in and the
# colours on, the way with the fewest levers to the leader's room. The leader's medal (switch 6, set by her event in the
# next map) ends it: no rule on arriving, nothing on the info key.
module PokeAccess
  module RealideaQuartz
    MAP = 116
    SWITCHES = [171, 172, 173, 174]
    BEATEN = 6
    # Per colour switch: its word, its water jets and its jump tiles (events).
    COLOURS = {
      171 => { :word => :rea_colour_red, :jets => [3, 8], :tiles => [4, 7, 9] },
      172 => { :word => :rea_colour_yellow, :jets => [17, 24], :tiles => [10, 18, 25, 26] },
      173 => { :word => :rea_colour_green, :jets => [2], :tiles => [13, 14] },
      174 => { :word => :rea_colour_lilac, :jets => [21, 27], :tiles => [22, 23, 28, 29] }
    }
    # The floor of each part, as boxes [x0, x1, y0, y1].
    REGIONS = {
      :start => [[29, 33, 23, 27], [28, 28, 28, 28], [31, 31, 28, 29], [27, 28, 29, 29], [27, 33, 30, 30], [19, 33, 31, 31],
                 [17, 28, 32, 32], [30, 33, 32, 32], [17, 33, 33, 33], [17, 21, 34, 34], [23, 32, 34, 34], [19, 22, 35, 35],
                 [17, 23, 36, 36], [17, 21, 37, 37]],
      :east => [[29, 31, 16, 16], [29, 32, 17, 17], [29, 33, 18, 18], [29, 32, 19, 19]],
      :north_east => [[23, 24, 7, 7], [26, 28, 7, 7], [30, 30, 7, 7], [33, 33, 7, 7], [23, 33, 8, 10], [24, 24, 11, 11],
                      [29, 33, 11, 11], [23, 26, 12, 13], [30, 33, 12, 12], [23, 25, 14, 14]],
      :centre => [[16, 20, 16, 16], [22, 23, 16, 16], [16, 25, 17, 18], [16, 16, 19, 19], [18, 25, 19, 19], [23, 23, 20, 20],
                  [22, 25, 21, 22], [22, 24, 23, 23]],
      :west => [[7, 10, 16, 16], [7, 12, 17, 19], [7, 10, 20, 23], [8, 10, 24, 24], [7, 10, 25, 29], [7, 9, 30, 30],
                [11, 13, 30, 32], [8, 8, 31, 32], [7, 13, 33, 34], [7, 9, 35, 35], [11, 12, 35, 35]],
      :north_west => [[7, 7, 7, 7], [9, 10, 7, 7], [13, 13, 7, 7], [7, 13, 8, 9], [7, 10, 10, 10], [12, 12, 10, 10],
                      [7, 13, 11, 12], [11, 12, 13, 13]],
      :leader => [[16, 20, 7, 8], [17, 19, 9, 9], [16, 20, 10, 10]]
    }
    # The levers: event => its colour switch, the part it is in and its tile.
    LEVERS = {
      1 => { :switch => 173, :region => :east, :at => [33, 19] },
      5 => { :switch => 171, :region => :north_west, :at => [13, 13] },
      6 => { :switch => 171, :region => :start, :at => [27, 28] },
      11 => { :switch => 171, :region => :east, :at => [33, 17] },
      12 => { :switch => 174, :region => :north_east, :at => [26, 14] },
      15 => { :switch => 172, :region => :centre, :at => [25, 23] },
      16 => { :switch => 172, :region => :west, :at => [13, 35] },
      19 => { :switch => 174, :region => :west, :at => [11, 29] }
    }
    # The bridges of jump tiles from part :a to part :b: the colours they need, their tiles in order from :a and the way
    # to face from :a to cross (8 up, 2 down, 4 left, 6 right).
    BRIDGES = [
      { :a => :start, :b => :east, :colours => [171], :stones => [7, 4], :dir => 8 },
      { :a => :east, :b => :north_east, :colours => [173], :stones => [13, 14], :dir => 8 },
      { :a => :east, :b => :centre, :colours => [174], :stones => [22, 23], :dir => 4 },
      { :a => :centre, :b => :west, :colours => [172], :stones => [25, 26], :dir => 4 },
      { :a => :centre, :b => :leader, :colours => [171, 172], :stones => [9, 10, 18], :dir => 8 },
      { :a => :west, :b => :north_west, :colours => [174], :stones => [28, 29], :dir => 8 }
    ]
    # The water tiles a bridge lands on between its jump tiles.
    GAPS = [[8, 14], [14, 18], [18, 12], [18, 14], [27, 18], [31, 14], [31, 21]]
    # The jump tiles that throw to the sides; the rest throw up or down.
    SIDEWAYS = [22, 23, 25, 26]
    FACES = { 8 => :face_north, 2 => :face_south, 4 => :face_west, 6 => :face_east }
    BACK = { 8 => 2, 2 => 8, 4 => 6, 6 => 4 }
    # What a lever and a bridge cost in a plan: the levers are what is counted.
    PULL = 10
    CROSS = 1

    # A name that follows the switch of its colour: on_key while it is on, off_key while it is off, with the colour word.
    def self.label(switch, on_key, off_key)
      word = COLOURS[switch][:word]
      lambda { |_ev| [$game_switches[switch] ? on_key : off_key, { :colour => PokeAccess::I18n.t(word) }] }
    end

    # The name of a jump tile, which follows its colour like a jet's and says the way it throws: up or down, or sideways.
    def self.tile_label(switch)
      word = COLOURS[switch][:word]
      lambda do |ev|
        way = SIDEWAYS.include?(ev.id) ? :rea_quartz_way_sideways : :rea_quartz_way_vertical
        [$game_switches[switch] ? :rea_quartz_tile_on : :rea_quartz_tile_off,
         { :colour => PokeAccess::I18n.t(word), :way => PokeAccess::I18n.t(way) }]
      end
    end

    # The colours on, as switch ids.
    def self.active
      SWITCHES.select { |s| $game_switches[s] }
    end

    # The part of the gym a tile is in, or nil.
    def self.region_of(x, y)
      REGIONS.each do |name, boxes|
        return name if boxes.any? { |b| x >= b[0] && x <= b[1] && y >= b[2] && y <= b[3] }
      end
      nil
    end

    # What can be done from a part with some colours on, as [part after, colours after, step, cost]: a lever pulled, or a
    # bridge crossed with the colours it needs on. A step is [:pull, switch, turned on] or [:cross, bridge, back].
    def self.moves(region, on)
      out = []
      LEVERS.each_value do |lever|
        next unless lever[:region] == region
        switch = lever[:switch]
        if on.include?(switch)
          out.push([region, (on - [switch]).sort, [:pull, switch, false], PULL])
        elsif on.length < 2
          out.push([region, (on + [switch]).sort, [:pull, switch, true], PULL])
        end
      end
      BRIDGES.each_with_index do |bridge, i|
        next unless (bridge[:colours] - on).empty?
        out.push([bridge[:b], on, [:cross, i, false], CROSS]) if bridge[:a] == region
        out.push([bridge[:a], on, [:cross, i, true], CROSS]) if bridge[:b] == region
      end
      out
    end

    # The first step of the way with the fewest levers from a part with some colours on to the leader's room: :done
    # there, nil with no way.
    def self.plan(region, on)
      start = [region, on.sort]
      best = { start => 0 }
      first = {}
      queue = [start]
      until queue.empty?
        queue.sort! { |a, b| best[a] <=> best[b] }
        node = queue.shift
        return(first[node] || :done) if node[0] == :leader
        moves(node[0], node[1]).each do |region_after, set, step, cost|
          key = [region_after, set]
          total = best[node] + cost
          next if best[key] && best[key] <= total
          best[key] = total
          first[key] = first[node] || step
          queue.push(key) unless queue.include?(key)
        end
      end
      nil
    end

    # How far a tile is from the player, as the step guide says it.
    def self.offset(at, pos)
      PokeAccess::Puzzles.offset_phrase(at[0] - pos[0], at[1] - pos[1])
    end

    # The line for a lever step: the colour to turn on or off and the nearest lever of it in the part the player is in.
    def self.pull_text(region, step, pos)
      near = LEVERS.values.select { |l| l[:region] == region && l[:switch] == step[1] }
      lever = near.min_by { |l| (l[:at][0] - pos[0]).abs + (l[:at][1] - pos[1]).abs }
      PokeAccess::I18n.t(step[2] ? :rea_quartz_step_on : :rea_quartz_step_off,
                         :colour => PokeAccess::I18n.t(COLOURS[step[1]][:word]), :where => offset(lever[:at], pos))
    end

    # The line for a bridge step: its colours, the way across and where its first jump tile is from the player.
    def self.cross_text(step, pos)
      bridge = BRIDGES[step[1]]
      stones = step[2] ? bridge[:stones].reverse : bridge[:stones]
      first = $game_map.events[stones[0]]
      colours = bridge[:colours].map { |s| PokeAccess::I18n.t(COLOURS[s][:word]) }.join(", ")
      dir = PokeAccess::I18n.t(FACES[step[2] ? BACK[bridge[:dir]] : bridge[:dir]])
      PokeAccess::I18n.t(:rea_quartz_step_cross, :colours => colours, :dir => dir, :where => offset([first.x, first.y], pos))
    end

    # With the assist: the next step from where the player stands and the colours on; half way over a bridge, to go on; the
    # column of the leader's door when no way is known.
    def self.hint
      pos = [$game_player.x, $game_player.y]
      return PokeAccess::I18n.t(:rea_quartz_transit) if GAPS.include?(pos)
      region = region_of(pos[0], pos[1])
      step = region && plan(region, active)
      return "" if step == :done
      return PokeAccess::I18n.t(:rea_quartz_hint) unless step
      step[0] == :pull ? pull_text(region, step, pos) : cross_text(step, pos)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      PokeAccess::I18n.t(:rea_quartz_hint)
    end
  end
end

PokeAccess::Game.define("realidea") do
  quartz = PokeAccess::RealideaQuartz
  mechanic(:state, quartz::MAP) do
    auto
    quartz::COLOURS.each do |switch, colour|
      name colour[:jets], quartz.label(switch, :rea_quartz_jet_on, :rea_quartz_jet_off)
      name colour[:tiles], quartz.tile_label(switch)
    end
    count :rea_quartz_colours, :var => 64, :of => 2, :reset => false
    arrival_hint :rea_quartz_rule
    solved { $game_switches[quartz::BEATEN] }
    hint lambda { quartz.hint }
  end
end
