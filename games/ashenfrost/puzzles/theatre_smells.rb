# Glacial Theatre in Truffles' mode (map 398, Case Seven, switch 71): four green smells (EV40 to EV43) drawn while she
# sniffs, each adding 1 to variable 403 the first time, the fourth leaving it at 5; Sylvester (EV39) ends the search
# only at 5 (switch 115). The assist leaves out the sniffed smells, counts them and gives Sylvester's option.
module PokeAccess
  module AshenTheatreSmells
    MAP = 398
    SMELLS = [40, 41, 42, 43]
    SYLVESTER = 39
    ROPE_SMELL = 7
    VAR = 403
    DONE = 115
    MODE = 71

    # Whether a smell has been sniffed already: its page sets its self switch A.
    def self.sniffed?(ev)
      $game_self_switches[[MAP, ev, "A"]] ? true : false
    end

    # The green smells sniffed, as the count says them: the fourth leaves the variable at 5.
    def self.found
      [$game_variables[VAR].to_i, SMELLS.length].min
    end

    # Whether every green smell has been sniffed and Sylvester is still to hear it.
    def self.all_found?
      $game_variables[VAR].to_i >= 5 && !$game_switches[DONE]
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  smells = PokeAccess::AshenTheatreSmells
  mechanic(:state, smells::MAP) do
    auto
    active { $game_switches[smells::MODE] ? true : false }
    name smells::SMELLS, :afb_green_smell, :when => lambda { |ev| !(PokeAccess::Puzzles.assist? && smells.sniffed?(ev.id)) }
    name smells::ROPE_SMELL, :afb_smell
    hide smells::SMELLS, :assist => true, :when => lambda { |ev| smells.sniffed?(ev.id) }
    count :afb_green_smells, :value => lambda { smells.found }, :of => smells::SMELLS.length, :assist => true
    right_choice smells::SYLVESTER, :takes => lambda { smells.all_found? ? { :switch => smells::DONE, :to => true } : nil }
    phase lambda { PokeAccess::Puzzles.assist? && smells.all_found? }, :hint => :afb_smells_done,
          :hidden => right_way(smells::SYLVESTER)
    solved(nil, :quiet => true) { $game_switches[smells::DONE] ? true : false }
  end
end
