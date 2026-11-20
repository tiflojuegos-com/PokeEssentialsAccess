# Caves of Jenola L3B (map 98): seven buttons on the floor (events 12 to 24, even ids), stepped on, set some of the seven
# rocks (events 13 to 25, odd ids, gone while their self switch A is on) away or back, and flip their own self switch A,
# which turns what the next press does; the pad beside the guide (event 28) puts everything back. The assist's next press
# comes from the rocks and buttons as they stand: a search over the regions the rocks split the floor into, read off the
# map, toward the fossil's room (the Baron, event 30). The south teleporter (event 27) also reaches the fossil.
module PokeAccess
  module SoulstonesJenola
    BUTTONS = [12, 14, 16, 18, 20, 22, 24]
    ROCKS = [13, 15, 17, 19, 21, 23, 25]
    # Button => what its press does with its own switch off, then on: {rock => gone}.
    EFFECTS = [[{ 0 => true, 6 => true }, { 0 => false, 6 => false }],
               [{ 2 => true, 6 => false }, { 2 => false, 6 => true }],
               [{ 3 => false, 4 => true, 2 => false }, { 3 => true, 4 => false, 2 => true }],
               [{ 3 => true, 1 => true, 0 => false }, { 3 => false, 1 => false, 0 => true }],
               [{ 0 => false, 6 => true, 2 => false }, { 0 => true, 6 => false, 2 => true }],
               [{ 2 => true, 5 => true, 6 => false }, { 2 => false, 5 => false, 6 => true }],
               [{ 5 => false, 6 => true }, { 5 => true, 6 => false }]]
    # The regions each rock joins once gone, each button and the pad touch, and the one before the fossil.
    ROCK_LINKS = [[2, 12], [13, 12], [15, 12], [12, 10], [12, 8], [14, 12], [14, 7]]
    BUTTON_LINKS = [[2], [12], [13], [15], [10], [8], [14]]
    PAD_LINKS = [2]
    FOSSIL_LINKS = [7]
    START = 2
    BUTTON_AT = [[12, 26], [27, 22], [24, 24], [15, 26], [23, 18], [23, 15], [33, 24]]
    ROCK_AT = [[16, 23], [22, 23], [17, 24], [24, 21], [21, 21], [26, 23], [31, 23]]
    PAD = 28
    PAD_AT = [9, 20]
    FOSSIL = 30
    # Region => {row => x ranges}, near the puzzle; the corridor north of it is region 2.
    REGIONS = { 2 => { 12 => [9..12], 13 => [9..12], 14 => [9..12], 15 => [9..12], 16 => [9..12], 17 => [9..12],
                       18 => [9..12], 19 => [9..12], 20 => [10..12], 21 => [10..13], 22 => [9..14], 23 => [9..15],
                       24 => [10..11], 25 => [9..12] },
                7 => { 15 => [34..34], 16 => [30..35], 17 => [31..34], 18 => [31..35], 19 => [31..34], 20 => [31..34],
                       21 => [31..33], 22 => [29..33] },
                8 => { 16 => [21..23], 17 => [21..21], 18 => [21..21], 19 => [21..21], 20 => [21..21] },
                10 => { 18 => [24..24], 19 => [24..24], 20 => [24..24] },
                12 => { 22 => [19..26], 23 => [17..19] },
                13 => { 24 => [20..23] },
                14 => { 24 => [26..32] },
                15 => { 25 => [15..18] } }

    # The rocks gone and the buttons switched now, one bit each.
    def self.state
      rocks = 0
      btns = 0
      ROCKS.each_with_index { |id, i| rocks |= 1 << i if $game_self_switches[[98, id, "A"]] }
      BUTTONS.each_with_index { |id, i| btns |= 1 << i if $game_self_switches[[98, id, "A"]] }
      [rocks, btns]
    end

    # The rocks and buttons after pressing button i.
    def self.press(rocks, btns, i)
      EFFECTS[i][(btns >> i) & 1].each { |bit, gone| rocks = gone ? rocks | (1 << bit) : rocks & ~(1 << bit) }
      [rocks, btns ^ (1 << i)]
    end

    # Each region's group with the rocks gone in rocks, as {node => root}; a gone rock is node -(bit + 1).
    def self.roots(rocks)
      @roots ||= {}
      @roots[rocks] ||= begin
        parent = {}
        find = lambda { |a| parent[a] = parent[a] ? (parent[a] == a ? a : find.call(parent[a])) : a }
        ROCK_LINKS.each_with_index do |links, bit|
          next if rocks & (1 << bit) == 0
          links.each { |r| parent[find.call(r)] = find.call(-(bit + 1)) }
        end
        out = {}
        (REGIONS.keys + (1..ROCKS.length).map { |b| -b }).each { |n| out[n] = find.call(n) }
        out
      end
    end

    # The nodes the player stands by: a button's or the pad's regions, or the region or gone rock under them.
    def self.anchors(pos)
      return BUTTON_LINKS[pos] if pos.is_a?(Integer) && pos >= 0
      return PAD_LINKS if pos == :pad
      pos.is_a?(Array) ? pos : [START]
    end

    # True when a thing linked to links can be reached from anchors with the rocks gone in rocks.
    def self.reaches?(rocks, anchors, links)
      r = roots(rocks)
      mine = anchors.map { |n| r[n] || n }
      links.any? { |n| mine.include?(r[n] || n) }
    end

    # The first step from a state toward the fossil, fewest presses first: [:button, i], [:pad], [:done] or nil.
    def self.plan(rocks, btns, pos)
      start = [rocks, btns, pos]
      seen = { start => true }
      queue = [[start, nil]]
      until queue.empty?
        (r, b, p), first = queue.shift
        here = anchors(p)
        return(first || [:done]) if reaches?(r, here, FOSSIL_LINKS)
        moves = []
        BUTTON_LINKS.each_with_index do |links, i|
          moves.push([[:button, i], press(r, b, i) + [i]]) if reaches?(r, here, links)
        end
        moves.push([[:pad], [0, 0, :pad]]) if reaches?(r, here, PAD_LINKS)
        moves.each do |step, nxt|
          next if seen[nxt]
          seen[nxt] = true
          queue.push([nxt, first || step])
        end
      end
      nil
    end

    # Where the player stands, as plan takes it: a button, the pad, a gone rock or a region.
    def self.position
      at = [$game_player.x, $game_player.y]
      i = BUTTON_AT.index(at)
      return i if i
      return :pad if at == PAD_AT
      rock = ROCK_AT.index(at)
      return [-(rock + 1)] if rock
      found = REGIONS.find { |_r, rows| (rows[at[1]] || []).any? { |span| span.include?(at[0]) } }
      found ? [found[0]] : [START]
    end

    # The step from the state now, kept until the rocks, the buttons or where the player stands change.
    def self.step
      key = state + [position]
      @step = [key, plan(key[0], key[1], key[2])] unless @step && @step[0] == key
      @step[1]
    end

    # The event the assist points at now.
    def self.right_event
      s = step
      return nil unless s
      case s[0]
      when :button then BUTTONS[s[1]]
      when :pad then PAD
      else FOSSIL
      end
    end

    # The assist's hint: the next button, the reset pad or the fossil.
    def self.hint
      s = step
      return :ss1_jenola_reset if s.nil? || s[0] == :pad
      s[0] == :done ? :ss1_jenola_done : [:ss1_jenola_next, { :n => s[1] + 1 }]
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  jen = PokeAccess::SoulstonesJenola

  mechanic(:state, 98) do
    auto
    name jen::BUTTONS, lambda { |ev| [:ss1_jenola_button, { :n => jen::BUTTONS.index(ev.id) + 1 }] }
    avoid jen::BUTTONS
    [jen::BUTTONS, jen::PAD, jen::FOSSIL].flatten.each do |id|
      spot(:event => id, :label => :puzzle_right_way, :assist => true, :onto => id != jen::FOSSIL,
           :when => lambda { jen.right_event == id })
    end
    name jen::PAD, :ss1_jenola_reset_pad
    hint lambda { jen.hint }
    active { PokeAccess::Puzzles.assist? && !$game_self_switches[[98, 29, "A"]] }
    solved(nil, :quiet => true) { $game_self_switches[[98, 29, "A"]] }
  end
end
