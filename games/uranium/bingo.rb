module PokeAccess
  # Uranium's Winotingo, the bingo of the Angelure resort (map 226, played by its Bingo Handler event with no input):
  # a card of five columns, T, I, N, G and O, of five numbers each with the centre free, and a bonus grid of three
  # columns of the T, I and N numbers the card lacks, its centre free too. Each ball marks its number in its letter's
  # column of both grids (a zero in $bingo and $winotingernum) and BingoUpdate repaints them as event graphics, the
  # bonus grid last; the game only stops at a win. Said: the card as it is dealt, how it stands at each win, and both
  # grids on the info key while the game is on.
  module UraniumBingo
    MAP = 226
    LETTERS = %w[T I N G O]

    # After BingoUpdate repaints the bonus grid, the end of a deal or of a ball: a grid not seen before is a new card,
    # said with the rules after the game's next line; else how the card stands, promised for the next line in place
    # of the last ball's, since the game shows a line only at a win or at its end.
    def self.updated(grid, column)
      return unless column == 5 && grid.is_a?(Array) && grid.length == 9 && card
      if grid.equal?(@bonus)
        PokeAccess.after_next_line(standing)
      else
        @bonus = grid
        @events = ($game_map.events rescue nil)
        PokeAccess.after_next_line(PokeAccess.sentences([PokeAccess::I18n.t(:ura_bingo_rules), grids]))
      end
    rescue StandardError => e
      PokeAccess.swallowed(e)
    end

    # The card's five columns as the game keeps them, or nil.
    def self.card
      c = $bingo
      return nil unless c.is_a?(Array) && c.length == 5
      c.all? { |col| col.is_a?(Array) && col.length == 5 } ? c : nil
    end

    # A column's numbers from top to bottom, the free space (index free) said as free.
    def self.column_text(letter, cells, free)
      words = []
      cells.each_with_index { |v, i| words.push(i == free ? PokeAccess::I18n.t(:ura_bingo_free) : cell_word(v)) }
      PokeAccess::I18n.t(:ura_bingo_col, :letter => letter, :cells => words.join(", "))
    end

    # A space's number, or marked once its ball is out (the game keeps it as 0).
    def self.cell_word(v)
      v.to_i == 0 ? PokeAccess::I18n.t(:ura_bingo_marked_cell) : v.to_s
    end

    # The card and the bonus grid, column by column, as they stand.
    def self.grids
      c = card
      cols = (0...5).map { |i| column_text(LETTERS[i], c[i], i == 2 ? 2 : nil) }
      bonus = (0...3).map { |i| column_text(LETTERS[i], @bonus[i * 3, 3], i == 1 ? 1 : nil) }
      PokeAccess.sentences([PokeAccess::I18n.t(:ura_bingo_card, :cols => cols.join("; ")),
                            PokeAccess::I18n.t(:ura_bingo_bonus, :cols => bonus.join("; "))])
    end

    # The card's twelve lines, each [kind, index, cells]: the columns, the rows from the top and the two diagonals,
    # from the top left and from the top right.
    def self.lines(c)
      out = (0...5).map { |i| [:column, i, c[i]] }
      (0...5).each { |r| out.push([:row, r, c.map { |col| col[r] }]) }
      out.push([:diag, 0, (0...5).map { |i| c[i][i] }])
      out.push([:diag, 1, (0...5).map { |i| c[4 - i][i] }])
      out
    end

    # A line's name as said.
    def self.line_name(kind, index)
      case kind
      when :column then PokeAccess::I18n.t(:ura_bingo_column, :letter => LETTERS[index])
      when :row then PokeAccess::I18n.t(:ura_bingo_row, :n => index + 1)
      else PokeAccess::I18n.t(index == 0 ? :ura_bingo_diag_left : :ura_bingo_diag_right)
      end
    end

    # How the card stands: the lines it completes, else the spaces marked out of 24, the fewest numbers a line
    # still lacks and the bonus spaces marked out of 8.
    def self.standing
      c = card
      lacks = lines(c).map { |kind, index, cells| [kind, index, cells.select { |v| v.to_i != 0 }.length] }
      done = lacks.select { |l| l[2] == 0 }
      unless done.empty?
        return PokeAccess::I18n.t(:ura_bingo_done, :lines => done.map { |l| line_name(l[0], l[1]) }.join(", "))
      end
      PokeAccess.sentences([PokeAccess::I18n.t(:ura_bingo_marked, :n => c.flatten.select { |v| v.to_i == 0 }.length - 1),
                            PokeAccess::I18n.t(:ura_bingo_need, :n => lacks.map { |l| l[2] }.min),
                            PokeAccess::I18n.t(:ura_bingo_bonus_marked, :n => @bonus.select { |v| v.to_i == 0 }.length - 1)])
    end

    # The info key on the bingo's map while its card is on: both grids and how the card stands; nil before a deal
    # and once the map is left, which builds a new events table.
    def self.info
      return nil unless @bonus && card && $game_map && $game_map.map_id == MAP && $game_map.events.equal?(@events)
      PokeAccess.sentences([grids, standing])
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

PokeAccess::Game.define("uranium") do
  kernel("BingoUpdate", :after) { |args, _r| PokeAccess::UraniumBingo.updated(args[0], args[1]) }
  PokeAccess::Info.map_owner(:uranium_bingo) { PokeAccess::UraniumBingo.info }
end
