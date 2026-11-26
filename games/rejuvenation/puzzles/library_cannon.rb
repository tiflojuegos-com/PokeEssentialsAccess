# The Hidden Library 3 (map 418), Karen's corridor (variable 265, 7 to 9): Gigalith (event 101, x 98 to 103) follows the
# player's column in round one, Archeops (x 81 to 113) in round two; event 100 drops a rock in its column that knocks
# the player down to row 60. Round three: Diancie (event 62) and a dark energy (120) give chase; 265 goes to 10.
module PokeAccess
  module RejuvLibraryCannon
    MAP = 418
    BOX = [80, 115, 15, 60]
    SHOOTER = 101
    HINTS = { 7 => :rjf_hl_round1_hint, 8 => :rjf_hl_round2_hint, 9 => :rjf_hl_round3_hint }

    # The quest's step, variable 265.
    def self.round; $game_variables[265].to_i; end

    # While a round runs and the player is in the corridor.
    def self.live?
      x = $game_player.x
      y = $game_player.y
      HINTS.key?(round) && x >= BOX[0] && x <= BOX[1] && y >= BOX[2] && y <= BOX[3]
    end

    # How many columns the shooter stands from the player, east positive, or nil with no shooter.
    def self.offset
      return nil unless round == 7 || round == 8
      ev = $game_map.events[SHOOTER]
      ev ? ev.x - $game_player.x : nil
    end

    # Whether the shooter is in the player's column.
    def self.in_line?; live? && offset == 0; end

    # The info line: where the shooter stands, as seen from below.
    def self.info_line
      off = offset
      return nil if off.nil?
      return :rjf_hl_shooter_above if off.zero?
      key = off < 0 ? :rjf_hl_shooter_west : :rjf_hl_shooter_east
      n = off.abs
      [key, { :cols => n == 1 ? PokeAccess::I18n.t(:rjf_hl_one_col) : PokeAccess::I18n.t(:rjf_hl_cols, :n => n) }]
    end
  end
end

PokeAccess::Game.define("rejuvenation") do
  hl = PokeAccess::RejuvLibraryCannon
  mechanic(:state, hl::MAP, :part => :cannon) do
    auto
    name 61, :rjf_hl_goal, :when => lambda { |_ev| hl.live? }
    name 120, :rjf_hl_energy
    phase lambda { hl.in_line? }, :title => :rjf_hl_in_line, :hint => lambda { hl::HINTS[hl.round] }
    phase lambda { hl.live? }, :quiet => true, :title => lambda { hl.info_line }, :hint => lambda { hl::HINTS[hl.round] }
    active { hl.live? }
    solved(nil, :quiet => true) { hl.round >= 10 }
  end
end
