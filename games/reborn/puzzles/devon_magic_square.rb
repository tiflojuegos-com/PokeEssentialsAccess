# Devon Corp? (map 765), the Double Magic Square: two 3x3 screens, variables 451 to 459 and 460 to 468. The middle
# terminal (event 77) lays them out (switch 1029) and turns a row of both screens, the side ones (78, 79) a column of
# theirs; each move sets 1030 and the checker (event 80) wins (1028) when every line through the middle adds up to 15.
module PokeAccess
  module RebornMagicSquare
    MAP = 765
    CELLS = (451..468).to_a
    ON = 1029
    DONE = 1028
    CHECKING = 1030
    TERMINALS = { 77 => :rbh_dm_terminal_middle, 78 => :rbh_dm_terminal_left, 79 => :rbh_dm_terminal_right }
    DIRS = { :left => "Left", :right => "Right", :up => "Up", :down => "Down" }
    STARTS = [[4, 9, 6, 5, 8, 3, 2, 4, 1, 1, 2, 5, 7, 7, 9, 6, 3, 8],
              [6, 2, 9, 1, 3, 4, 5, 7, 8, 4, 7, 5, 8, 2, 9, 3, 1, 6]]
    PLANS = [[[77, 1, :left], [77, 2, :right], [79, 2, :down], [78, 3, :up]],
             [[78, 3, :up], [77, 3, :right], [77, 2, :left], [77, 2, :left], [78, 2, :up], [77, 1, :left],
              [79, 2, :up], [79, 3, :up], [77, 1, :right], [79, 2, :up]]]

    @last = nil
    @memo = nil

    # The cells a pick turns: a row of both screens for the middle terminal, else a column of its own screen.
    def self.ring(term, n)
      i = n - 1
      return [3 * i, 3 * i + 1, 3 * i + 2, 9 + 3 * i, 10 + 3 * i, 11 + 3 * i] if term == 77
      base = term == 78 ? 0 : 9
      [base + i, base + i + 3, base + i + 6]
    end

    # The numbers after a pick: each cell of its line takes the next one's (Left, Up) or the one before's (Right, Down).
    def self.apply(s, move)
      r = ring(move[0], move[1])
      step = move[2] == :left || move[2] == :up ? 1 : -1
      out = s.dup
      r.each_with_index { |c, j| out[c] = s[r[(j + step) % r.length]] }
      out
    end

    # Every pick of the three terminals.
    def self.moves
      @moves ||= [77, 78, 79].map do |t|
        dirs = t == 77 ? [:left, :right] : [:up, :down]
        [1, 2, 3].map { |n| dirs.map { |d| [t, n, d] } }
      end.flatten(2)
    end

    # The numbers now, both screens in reading order.
    def self.grid; CELLS.map { |v| $game_variables[v].to_i }; end

    # The numbers a plan passes through, from its layout to its win.
    def self.trail(k)
      @trails ||= {}
      @trails[k] ||= PLANS[k].inject([STARTS[k]]) { |acc, m| acc.push(apply(acc.last, m)) }
    end

    # The plan's pick from s, or one that leads back onto a plan in one or two picks; nil when none does.
    def self.next_move(s)
      PLANS.each_index do |k|
        i = trail(k).index(s)
        return PLANS[k][i] if i && i < PLANS[k].length
      end
      moves.each { |m| return m if on_trail?(apply(s, m)) }
      moves.each { |m| t = apply(s, m); return m if moves.any? { |m2| on_trail?(apply(t, m2)) } }
      nil
    end

    # True when a plan passes through s.
    def self.on_trail?(s)
      (0...PLANS.length).any? { |k| trail(k).include?(s) }
    end

    # A screen's numbers as its three rows.
    def self.rows(cells); [0, 3, 6].map { |i| cells[i, 3].join(" ") }.join(", "); end

    # Both screens as said.
    def self.screens(s)
      PokeAccess::I18n.t(:rbh_dm_screens, :a => rows(s[0, 9]), :b => rows(s[9, 9]))
    end

    # True while the numbers are laid out and not yet won.
    def self.live?; $game_switches[ON] && !$game_switches[DONE] ? true : false; end

    # With the assist, the next pick in the game's own option words, kept per layout of the numbers.
    def self.hint
      return nil unless live?
      s = grid
      return @memo[1] if @memo && @memo[0] == s
      m = next_move(s)
      out = m ? [:rbh_dm_hint, { :terminal => PokeAccess::I18n.t(TERMINALS[m[0]]),
                                 :line => "#{m[0] == 77 ? 'Row' : 'Column'} #{m[1]}", :dir => DIRS[m[2]] }] : :rbh_dm_hint_reset
      @memo = [s, out]
      out
    end

    # Says both screens when their numbers change on this map, once the checker is done with them, and with the assist
    # the next pick.
    def self.poll
      return unless $game_map && $game_map.map_id == MAP
      return @last = :off unless live?
      return if $game_switches[CHECKING]
      s = grid
      return if @last == s
      said = !@last.nil?
      @last = s
      return unless said
      line = screens(s)
      h = PokeAccess::Puzzles.assist? ? hint : nil
      line = "#{line} #{h.is_a?(Array) ? PokeAccess::I18n.t(h[0], h[1]) : PokeAccess::I18n.t(h)}" if h
      PokeAccess.speak(line, false)
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # Drops what was kept of the last map.
    def self.forget
      @last = nil
      @memo = nil
    end
  end
end

PokeAccess::World::Epoch.on(:map) { PokeAccess::RebornMagicSquare.forget }

PokeAccess::Game.define("reborn") do
  sq = PokeAccess::RebornMagicSquare
  poll_each_frame { sq.poll }
  mechanic(:state, sq::MAP) do
    auto
    sq::TERMINALS.each { |id, label| name id, label }
    info { sq.live? ? sq.screens(sq.grid) : nil }
    hint lambda { sq.hint }
    active { sq.live? }
    solved(nil, :quiet => true) { $game_switches[sq::DONE] }
  end
end
