# The Thief's Dungeon of the Kecleon Bazaar (map 81): three rows of three gates, each a transfer whose page goes by
# variable 633 (1 to 3). A wrong gate drops the player among the Kecleon at (12,76); on the last row one gate leads to
# the treasure room (29,76) and one to a bare way out (74,42). The board on the wall shows the safe path per value.
module PokeAccess
  module RejuvThiefDungeon
    ROWS = [[47, 48, 49], [54, 55, 56], [57, 58, 59]]
    GATES = {
      47 => [:pit, :pit, :on], 48 => [:on, :on, :on], 49 => [:on, :on, :pit],
      54 => [:on, :pit, :pit], 55 => [:pit, :on, :pit], 56 => [:pit, :pit, :on],
      57 => [:treasure, :exit, :pit], 58 => [:pit, :treasure, :exit], 59 => [:exit, :pit, :treasure]
    }
    BOARD = { 1 => [1, 0, 2, 0], 2 => [2, 1, 0, 1], 3 => [0, 2, 1, 2] }
    COLUMNS = [:rj_thief_left, :rj_thief_middle, :rj_thief_right]
    KINDS = { :on => :rj_thief_gate_on, :pit => :rj_thief_gate_pit, :treasure => :rj_thief_gate_treasure,
              :exit => :rj_thief_gate_exit }

    # The board's pattern now, 1 to 3, or nil before the cell mate draws it.
    def self.pattern
      v = $game_variables[633].to_i
      v >= 1 && v <= 3 ? v : nil
    end

    # Where a gate leads under the pattern now: :on, :pit, :treasure or :exit; nil for another event.
    def self.gate(id)
      p = pattern
      GATES[id] && p ? GATES[id][p - 1] : nil
    end

    # The gate's name: its column, or with the puzzle assist where it leads.
    def self.gate_label(id)
      kind = PokeAccess::Puzzles.assist? ? gate(id) : nil
      return KINDS[kind] if kind
      col = ROWS.map { |row| row.index(id) }.compact.first
      [:rj_thief_gate, { :col => PokeAccess::I18n.t(COLUMNS[col]) }]
    end

    # What the board on the wall draws: the safe gate's column per row, from the bottom, and the yellow square's.
    def self.board
      cols = BOARD[pattern]
      return :rj_thief_board_blank unless cols
      w = cols.map { |c| PokeAccess::I18n.t(COLUMNS[c]) }
      [:rj_thief_board, { :first => w[0], :second => w[1], :third => w[2], :yellow => w[3] }]
    end

    # The way through with the assist: the safe gate of the first two rows and the treasure gate of the last.
    def self.hint
      cols = BOARD[pattern]
      return nil unless cols
      w = [cols[0], cols[1], cols[3]].map { |c| PokeAccess::I18n.t(COLUMNS[c]) }
      [:rj_thief_hint, { :first => w[0], :second => w[1], :third => w[2] }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  thief = PokeAccess::RejuvThiefDungeon
  mechanic(:state, 81) do
    auto
    thief::ROWS.flatten.each { |id| name id, lambda { |_ev| thief.gate_label(id) } }
    spot :at => [51, 16], :label => lambda { thief.board }, :when => lambda { thief.pattern }
    not_control 51
    active { PokeAccess::Puzzles.assist? && thief.pattern }
    hint lambda { thief.hint }
  end
end
