# Mt. Aoraki, chamber 1 (map 360, the floor below is 363): 99 cracked ice tiles in five zones, each counted in its own
# variable (68 to 72) by its first step. A second step on any cracked tile drops the player to map 363, and each arrival
# on 360 sets the tiles and counts back; a zone's ice block breaks once all its tiles are stepped on and stays broken.
# Behind the last block, the four tiles with no count drop the player beside Frigometri (map 363, 15, 23), who ends the
# chamber (switch 144). Every fall lands at x 16 to 35 of map 363; the ladder's landing (36, 21) is none. With the
# assist, a walk that steps on each tile once is searched at each step off the walk. The tiles are drawn as tiles, which
# the lists leave out, so the free camera names them.
module PokeAccess
  module HeroLegacyIceChamber
    MAP = 360
    # Each zone: its first and last tile, its variable, its ice block and how many tiles it counts.
    ZONES = [[18, 21, 68, 6, 4], [22, 42, 69, 10, 21], [43, 63, 70, 8, 21], [64, 81, 71, 7, 18], [82, 116, 72, 5, 35]]
    # The tiles behind the last block, over Frigometri's landing.
    GOAL = [117, 118, 119, 120]
    # The most tiles a search tries before it gives up.
    CAP = 4000
    # From each counted tile, and from the entrance (0), the tiles reached by walking and sliding over plain floor and
    # ice without stepping on another: [tile, the zones whose block it needs broken as a mask, presses], from the map.
    LEGS = { 0 => [[18, 0, 3]], 18 => [[19, 0, 1]], 19 => [[18, 0, 1], [20, 0, 1]], 20 => [[19, 0, 1], [21, 0, 1]],
      21 => [[20, 0, 1], [22, 1, 4], [64, 5, 5], [63, 5, 6]],
      22 => [[23, 0, 1], [25, 0, 1], [34, 0, 1], [64, 4, 3], [21, 1, 4], [63, 4, 4]],
      23 => [[22, 0, 1], [24, 0, 1], [35, 0, 1]], 24 => [[23, 0, 1], [25, 0, 1]],
      25 => [[22, 0, 1], [24, 0, 1], [26, 0, 1], [30, 0, 1]], 26 => [[25, 0, 1], [27, 0, 1], [29, 0, 1]],
      27 => [[26, 0, 1], [28, 0, 1]], 28 => [[27, 0, 1], [29, 0, 1]], 29 => [[26, 0, 1], [28, 0, 1], [30, 0, 1]],
      30 => [[25, 0, 1], [29, 0, 1], [31, 0, 1], [33, 0, 1]], 31 => [[30, 0, 1], [32, 0, 1]],
      32 => [[31, 0, 1], [33, 0, 1]], 33 => [[30, 0, 1], [32, 0, 1], [34, 0, 1]],
      34 => [[22, 0, 1], [33, 0, 1], [35, 0, 1], [38, 0, 1]], 35 => [[23, 0, 1], [34, 0, 1], [36, 0, 1]],
      36 => [[35, 0, 1], [37, 0, 1], [34, 0, 2], [38, 0, 2]], 37 => [[36, 0, 1], [38, 0, 1], [41, 0, 1]],
      38 => [[34, 0, 1], [37, 0, 1], [39, 0, 1]], 39 => [[38, 0, 1], [40, 0, 1], [37, 0, 2], [41, 0, 2]],
      40 => [[39, 0, 1], [41, 0, 1]], 41 => [[37, 0, 1], [40, 0, 1], [42, 0, 1]], 42 => [[41, 0, 1], [43, 2, 3]],
      43 => [[44, 0, 1], [42, 2, 3]], 44 => [[43, 0, 1], [45, 0, 1]], 45 => [[44, 0, 1], [46, 0, 1], [52, 0, 1]],
      46 => [[45, 0, 1], [47, 0, 1], [49, 0, 1], [51, 0, 1]], 47 => [[46, 0, 1], [48, 0, 1], [60, 0, 1]],
      48 => [[47, 0, 1], [49, 0, 1]], 49 => [[46, 0, 1], [48, 0, 1], [50, 0, 1]],
      50 => [[49, 0, 1], [51, 0, 1], [110, 0, 2], [111, 0, 2]],
      51 => [[46, 0, 1], [50, 0, 1], [52, 0, 1], [53, 0, 4]], 52 => [[45, 0, 1], [51, 0, 1], [53, 0, 1]],
      53 => [[52, 0, 1], [54, 0, 1], [51, 0, 4]], 54 => [[53, 0, 1], [55, 0, 1]],
      55 => [[54, 0, 1], [56, 0, 1], [59, 0, 1]], 56 => [[55, 0, 1], [57, 0, 1]],
      57 => [[56, 0, 1], [58, 0, 1], [61, 0, 2], [62, 0, 2]],
      58 => [[57, 0, 1], [59, 0, 1], [61, 0, 1], [55, 0, 2], [56, 0, 2]], 59 => [[55, 0, 1], [58, 0, 1], [60, 0, 1]],
      60 => [[47, 0, 1], [59, 0, 1], [61, 0, 1]], 61 => [[58, 0, 1], [60, 0, 1], [62, 0, 1]],
      62 => [[61, 0, 1], [63, 0, 1]], 63 => [[62, 0, 1], [22, 0, 3], [64, 4, 3], [21, 1, 6]],
      64 => [[65, 0, 1], [22, 4, 3], [63, 4, 3], [21, 5, 5]], 65 => [[64, 0, 1], [66, 0, 1], [72, 0, 1], [74, 0, 1]],
      66 => [[65, 0, 1], [67, 0, 1], [71, 0, 1]], 67 => [[66, 0, 1], [68, 0, 1]],
      68 => [[67, 0, 1], [69, 0, 1], [71, 0, 1]], 69 => [[68, 0, 1], [70, 0, 1]],
      70 => [[69, 0, 1], [71, 0, 1], [81, 0, 1]], 71 => [[66, 0, 1], [68, 0, 1], [70, 0, 1], [72, 0, 1]],
      72 => [[65, 0, 1], [71, 0, 1], [73, 0, 1], [81, 0, 1]], 73 => [[72, 0, 1], [74, 0, 1], [80, 0, 1]],
      74 => [[65, 0, 1], [73, 0, 1], [75, 0, 1]], 75 => [[74, 0, 1], [76, 0, 1]], 76 => [[75, 0, 1], [77, 0, 1]],
      77 => [[76, 0, 1], [78, 0, 1]], 78 => [[77, 0, 1], [79, 0, 1]], 79 => [[78, 0, 1], [80, 0, 1]],
      80 => [[73, 0, 1], [79, 0, 1], [81, 0, 1]], 81 => [[70, 0, 1], [72, 0, 1], [80, 0, 1], [82, 8, 3]],
      82 => [[83, 0, 1], [81, 8, 3]], 83 => [[82, 0, 1], [84, 0, 1]], 84 => [[83, 0, 1], [85, 0, 1]],
      85 => [[84, 0, 1], [86, 0, 1]], 86 => [[85, 0, 1], [87, 0, 1], [89, 0, 1]], 87 => [[86, 0, 1], [88, 0, 1]],
      88 => [[87, 0, 1], [89, 0, 1], [96, 0, 2], [95, 0, 4]], 89 => [[86, 0, 1], [88, 0, 1], [90, 0, 1]],
      90 => [[89, 0, 1], [91, 0, 1], [95, 0, 1], [88, 0, 2], [96, 0, 3]], 91 => [[90, 0, 1], [92, 0, 1], [94, 0, 1]],
      92 => [[91, 0, 1], [93, 0, 1]], 93 => [[92, 0, 1], [94, 0, 1]], 94 => [[91, 0, 1], [93, 0, 1], [95, 0, 1]],
      95 => [[90, 0, 1], [94, 0, 1], [96, 0, 1]], 96 => [[95, 0, 1], [97, 0, 1]],
      97 => [[96, 0, 1], [98, 0, 1], [99, 0, 2], [100, 0, 2]], 98 => [[97, 0, 1], [99, 0, 1]],
      99 => [[98, 0, 1], [100, 0, 1]], 100 => [[99, 0, 1], [101, 0, 1], [104, 0, 1]],
      101 => [[100, 0, 1], [102, 0, 1]], 102 => [[101, 0, 1], [103, 0, 1], [100, 0, 2], [104, 0, 2]],
      103 => [[102, 0, 1], [104, 0, 1], [105, 0, 1]], 104 => [[100, 0, 1], [103, 0, 1]],
      105 => [[103, 0, 1], [106, 0, 1], [104, 0, 2]], 106 => [[105, 0, 1], [107, 0, 1]],
      107 => [[106, 0, 1], [108, 0, 1], [110, 0, 2], [104, 0, 3]],
      108 => [[107, 0, 1], [109, 0, 1], [110, 0, 2], [104, 0, 3]], 109 => [[108, 0, 1], [110, 0, 1]],
      110 => [[109, 0, 1], [111, 0, 1], [104, 0, 2]], 111 => [[110, 0, 1], [112, 0, 1]],
      112 => [[111, 0, 1], [113, 0, 1]], 113 => [[112, 0, 1], [114, 0, 1]],
      114 => [[113, 0, 1], [115, 0, 1], [112, 0, 3]], 115 => [[114, 0, 1], [116, 0, 1]],
      116 => [[115, 0, 1], [117, 16, 3]] }

    # The next tile of the walk, or nil while there is none or the chamber is done.
    def self.next_tile
      return nil if $game_switches[144]
      refresh
      @plan && @plan.first
    end

    # True while the assist has no walk to give for the tiles left: the player has to fall and start over.
    def self.stuck?
      return false if $game_switches[144]
      refresh
      @plan.nil?
    end

    # A cracked tile's name, by whether it has taken its one step.
    def self.tile_label(ev)
      stepped?(ev.id) ? :hl_ice_broken : :hl_ice_cracked
    end

    # The label of the walk's next tile: a counted one, or the drop, stepped on twice or, once used, once more.
    def self.spot_label(id, name)
      return :hl_ice_next unless GOAL.include?(id)
      [stepped?(id) ? :hl_ice_drop_once : :hl_ice_drop, { :name => name }]
    end

    def self.stepped?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # What the free camera says of a cracked tile at (x, y): its name by its step and, with the assist, the drop over
    # Frigometri on the tiles behind the last block; nil off the ice.
    def self.camera_line(x, y, name)
      ev = PokeAccess::World::Events.at(x, y).map { |rec| rec.ev }.find { |e| e.name.to_s == "Cracked ice" }
      return nil unless ev
      return PokeAccess::I18n.t(tile_label(ev)) unless PokeAccess::Puzzles.assist? && GOAL.include?(ev.id)
      label, vars = spot_label(ev.id, name)
      PokeAccess::I18n.t(label, vars)
    end

    # The zones whose ice block is broken, as a mask.
    def self.open_mask
      mask = 0
      ZONES.each_with_index { |z, i| mask |= 1 << i if $game_self_switches[[MAP, z[3], "A"]] }
      mask
    end

    # The counted tiles stepped on, as bits by event id.
    def self.stepped_bits
      bits = 0
      (ZONES[0][0]..ZONES[-1][1]).each { |id| bits |= 1 << id if stepped?(id) }
      bits
    end

    def self.zone_of(id)
      ZONES.each_with_index { |z, i| return i if id >= z[0] && id <= z[1] }
      nil
    end

    # Keeps the walk in step with the room, cheaply while the counts and blocks stand: a step onto the walk's next
    # tile drops it, any other step searches a new walk from the tile stepped on.
    def self.refresh
      sig = ZONES.map { |z| $game_variables[z[2]].to_i } << open_mask
      return if sig == @sig
      stepped = stepped_bits
      unless stepped == @stepped
        rest = followed(stepped)
        @plan = rest || plan_from(last_tile(stepped), stepped)
      end
      @sig = sig
      @stepped = stepped
    end

    # The walk left once the tiles stepped on since the last look are its first ones, or nil.
    def self.followed(stepped)
      return nil unless @plan && @stepped && stepped & @stepped == @stepped
      fresh = stepped & ~@stepped
      plan = @plan
      while fresh != 0
        head = plan.first
        return nil unless head && fresh[head] == 1
        fresh &= ~(1 << head)
        plan = plan[1..-1]
      end
      plan
    end

    # Where a new walk starts: the entrance with nothing stepped on, else the tile just stepped on, the one under the
    # player when several were.
    def self.last_tile(stepped)
      return 0 if stepped == 0
      fresh = @stepped && stepped & @stepped == @stepped ? stepped & ~@stepped : stepped
      ids = (ZONES[0][0]..ZONES[-1][1]).select { |id| fresh[id] == 1 }
      px, py = $game_player.x, $game_player.y
      ids.min_by do |id|
        ev = $game_map.events[id]
        ev ? (ev.x - px).abs + (ev.y - py).abs : 999
      end
    end

    # A walk from a tile over the tiles not stepped on that reaches the drop, or nil when none is found within CAP.
    def self.plan_from(at, stepped)
      return nil unless at
      @budget = CAP
      @failed = {}
      walk(at, stepped, ZONES.map { |z| $game_variables[z[2]].to_i }, open_mask)
    end

    def self.walk(at, seen, counts, mask)
      return nil if @budget <= 0
      @budget -= 1
      return nil if @failed[[at, seen]]
      legs = (LEGS[at] || []).select { |_to, need, _n| need & mask == need }
      goal = legs.find { |to, _need, _n| GOAL.include?(to) }
      return [goal[0]] if goal
      legs.each do |to, _need, _n|
        next if seen[to] == 1
        z = zone_of(to)
        c = counts.dup
        c[z] += 1
        rest = walk(to, seen | (1 << to), c, c[z] == ZONES[z][4] ? mask | (1 << z) : mask)
        return [to] + rest if rest
      end
      @failed[[at, seen]] = true
      nil
    end
  end
end

PokeAccess::Game.define("herolegacy") do
  chamber = PokeAccess::HeroLegacyIceChamber
  frigometri = lambda { PokeAccess::Data.species_name(:CRYOGONAL).to_s }
  assisted = lambda { PokeAccess::Puzzles.assist? }
  mechanic(:state, chamber::MAP) do
    auto
    name(/\ACracked ice\z/, lambda { |ev| chamber.tile_label(ev) }, :when => false)
    name(/\AEisblock/, :hl_ice_block)
    avoid(/\ACracked ice\z/)
    not_control(/\ACracked ice\z/)
    (chamber::ZONES[0][0]..chamber::GOAL[-1]).each do |id|
      spot :event => id, :label => lambda { chamber.spot_label(id, frigometri.call) }, :assist => true, :onto => true,
           :when => lambda { chamber.next_tile == id }
    end
    arrival_hint :hl_ice_rule, :once => true
    phase lambda { assisted.call && chamber.stuck? }, :title => :hl_ice_stuck
    phase lambda { !$game_switches[144] }, :quiet => true,
          :hint => lambda { [:hl_ice_hint, { :name => frigometri.call }] }
    solved { $game_switches[144] }
  end
  camera_tile(:maps => [chamber::MAP]) { |x, y| chamber.camera_line(x, y, frigometri.call) }

  mechanic(:state, 363) do
    auto
    sent_back :hl_ice_fell, :maps => chamber::MAP, :to => [17, 35, 0, 39]
    sent_back :hl_ice_fell, :maps => chamber::MAP, :to => [16, 16, 0, 22]
  end
end
