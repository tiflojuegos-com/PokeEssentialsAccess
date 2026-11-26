# Ashen Frost's six chess pieces of Shadebloom Woods (maps 664 to 668, Case Sixteen): variable 242 counts them and each
# sets a switch that draws it on the board by the entrance (map 664), where the sixth opens the way north (242 at 7).
# Lucile's, the first, says five are left, so the count is the info key's; the assist names the pieces still missing.
module PokeAccess
  module AshenChess
    MAPS = [664, 665, 666, 667, 668]
    FOUND = 242
    TOTAL = 6
    LUCILE = [664, 77, "A"]
    # Each piece: the switch it sets, the key of its name and the map it is found on.
    PIECES = [[269, :afe_chess_lucile, 664], [271, :afe_chess_henry, 665], [270, :afe_chess_lue, 666],
              [274, :afe_chess_eloise, 667], [273, :afe_chess_hart, 667], [272, :afe_chess_mordecai, 668]]

    # How many pieces are found, never past the six.
    def self.found
      [$game_variables[FOUND].to_i, TOTAL].min
    end

    # Whether the hunt is on: Lucile's statue waits, or some piece is found, and not all.
    def self.hunting?
      ($game_self_switches[LUCILE] || found > 0) && found < TOTAL ? true : false
    end

    # The assist's hint: each missing piece and the map it is on, by the game's name for it.
    def self.hint
      missing = PIECES.reject { |switch, _label, _map| $game_switches[switch] }
      list = missing.map do |_switch, label, map|
        PokeAccess::I18n.t(:afe_chess_where, :piece => PokeAccess::I18n.t(label), :map => PokeAccess::Locator.map_name(map))
      end
      [:afe_chess_hint, { :list => list.join("; ") }]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  chess = PokeAccess::AshenChess
  mechanic(:state, chess::MAPS, :part => :afe_chess) do
    auto
    active { chess.hunting? }
    solved(nil, :quiet => true) { chess.found >= chess::TOTAL }
    count :afe_chess_pieces, :value => lambda { chess.found }, :of => chess::TOTAL, :announce => false, :reset => false
    phase lambda { chess.hunting? }, :hint => lambda { chess.hint }
  end
end
