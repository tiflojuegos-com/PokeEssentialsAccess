# Edas' Carcitoma crossroads of the fools (map 114): a different person stands in the room at each round. The signposts (events
# 2 and 8) store the town picked from their menu in variable 57 and the door to the north compares it: a right town moves
# variable 56 on to the next round, a wrong one sets it back to the first. Either way the player lands at the foot of the room,
# so the line said there tells the two apart. The game never counts the six rounds, so their total is the assist's, which also
# says on a signpost's menu the town the door wants. Beating what waits beyond the last door (switch 162) ends it while its last round
# stands; the door goes on asking, and a wrong town starts it over.
module PokeAccess
  module EdasCarcitoma
    MAP = 114
    ROUND = 56
    TOWN = 57
    DOOR = 7
    SIGNS = [2, 8]
    ROUNDS = 6
    BEATEN = 162
    FOOT = [10, 26]

    # Whether the crossroads are behind the player: what waits beyond them beaten and the last round still standing.
    def self.passed?
      $game_switches[BEATEN] && $game_variables[ROUND].to_i >= ROUNDS - 1
    end

    # The hits so far; with the assist, out of the six rounds.
    def self.progress
      hits = $game_variables[ROUND].to_i
      label = PokeAccess::I18n.t(:edas_carc_hits)
      return PokeAccess::I18n.t(:puzzle_progress, :label => label, :n => hits, :of => ROUNDS) if PokeAccess::Puzzles.assist?
      PokeAccess::I18n.t(:puzzle_value, :label => label, :v => hits)
    end

    # What landing at the foot of the room says: the miss, which leaves variable 56 at 0, or the hit and the hits so far.
    def self.back_line
      return PokeAccess::I18n.t(:edas_carc_reset) if $game_variables[ROUND].to_i == 0
      PokeAccess.sentences([PokeAccess::I18n.t(:edas_carc_right), progress])
    end
  end
end

PokeAccess::Game.define("edas") do
  carcitoma = PokeAccess::EdasCarcitoma
  mechanic(:state, carcitoma::MAP) do
    auto
    info { carcitoma.progress }
    solved { carcitoma.passed? }
    sent_back lambda { carcitoma.back_line }, :to => carcitoma::FOOT
    arrival_hint :edas_carc_rule
    right_choice carcitoma::SIGNS, :takes => { :var => carcitoma::TOWN, :compared_by => carcitoma::DOOR }
  end
end
