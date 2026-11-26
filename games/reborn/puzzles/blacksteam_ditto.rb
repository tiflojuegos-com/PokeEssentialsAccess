# Blacksteam Factory B1F (map 11), after the cell (variable 107 from 13) and the Day Care rescue (variable 66 from 10):
# a Ditto waits in the cage (1, 2) above cage 13. Using that cage's Pokémon unbonded makes it turn into it (variable
# 122): Lickitung gives a Rare Candy (169), Makuhita breaks its cage (170, variable 66 to 12) and joins (switch 426).
module PokeAccess
  module RebornBlacksteamDitto
    MAP = 11
    BELOW = 108
    DITTO = 6
    FREED = 19
    LICKITUNG = 2
    MAKUHITA = 4
    LOUDRED = 5

    # The Day Care's stage, variable 66: 10 with the Ditto caged, 12 once out.
    def self.stage; $game_variables[66].to_i; end

    # True while the Ditto waits in its cage.
    def self.caged?
      stage >= 10 && stage < 12 && !$game_switches[170] && !$game_switches[161]
    end

    # True while the freed Ditto waits to be taken.
    def self.freed?
      stage >= 12 && !$game_switches[426] && !$game_switches[161]
    end

    # The Pokémon cage 13 should hold next: Lickitung while its Rare Candy is still to come, then Makuhita.
    def self.wanted
      !$game_switches[169] && $game_variables[122].to_i != LICKITUNG ? LICKITUNG : MAKUHITA
    end

    # With the assist, the next step: bond with Abra, empty cage 13, teleport the one wanted into it, then use it unbonded.
    def self.hint
      cells = PokeAccess::RebornBlacksteam
      return :rbh_bf_hint_take if freed?
      return nil unless caged? && cells.stage >= 13
      want = wanted
      bonded = $game_switches[165]
      if cells.content(BELOW) == want
        return :rba_bf_hint_release if bonded
        return [:rbh_bf_hint_transform, { :name => PokeAccess::I18n.t(cells::SPECIES[want]) }]
      end
      unless bonded
        return :rba_bf_hint_abra if $game_switches[164]
        return cells.go(LOUDRED)
      end
      return cells.go(want) if cells.content(BELOW) == 0
      :rbh_bf_hint_clear
    end
  end
end

PokeAccess::Game.define("reborn") do
  dit = PokeAccess::RebornBlacksteamDitto
  mechanic(:state, dit::MAP, :part => :ditto) do
    auto
    name dit::DITTO, :rbh_bf_ditto_caged, :when => lambda { |_ev| dit.caged? }
    name dit::FREED, :rbh_bf_ditto_freed, :when => lambda { |_ev| dit.freed? }
    hint lambda { dit.hint }
    active { PokeAccess::Puzzles.assist? && !dit.hint.nil? }
    solved(nil, :quiet => true) { $game_switches[426] || $game_switches[161] }
  end
end
