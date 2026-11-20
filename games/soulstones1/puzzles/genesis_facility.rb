# Genesis Science Facility (map 391): the sprite-less "Door" (event 13) asks for a four-digit code and opens with variable
# 277 at 5; four lead scientists say one digit each once beaten (their self switch A): Cassandra (event 35) the first,
# Lucas (42) the second, Julia (40) the third and Tony (37) the fourth. The core says the code with the assist, read off
# the door's own comparison.
module PokeAccess
  module SoulstonesGenesis
    # [event, digit place, digit] of the scientists who give one.
    DIGITS = [[35, 1, 1], [42, 2, 7], [40, 3, 8], [37, 4, 9]]

    # The digits heard so far, in place order, as [[place, digit], ...].
    def self.heard
      DIGITS.select { |ev, _p, _d| $game_self_switches[[391, ev, "A"]] }.map { |_ev, place, digit| [place, digit] }
    end

    # The digits heard so far as the info key's line, or nil before any.
    def self.info
      return nil if heard.empty?
      parts = heard.map { |place, digit| PokeAccess::I18n.t(:ss1_genesis_digit, :n => place, :d => digit) }
      PokeAccess::I18n.t(:ss1_genesis_heard, :list => PokeAccess::Routes::Text.and_list(parts))
    end
  end
end

PokeAccess::Game.define("soulstones1") do
  mechanic(:state, 391) do
    auto
    name 13, :ss1_genesis_door, :when => lambda { |_ev| $game_variables[277].to_i < 5 }
    info { PokeAccess::SoulstonesGenesis.info }
    hint :ss1_genesis_hint
    solved { $game_variables[277].to_i >= 5 }
  end
end
