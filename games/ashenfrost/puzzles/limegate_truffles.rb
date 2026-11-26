# Truffles Smelling in Limegate Park (map 138): the boy (EV34) has the player play as Truffles (switch 71); three smells
# (EV38 to EV40) each add one to variable 44 when first sniffed (self switch A), then the boy's own (EV41) ends the
# search (44 at 4, switch 71 off). The smells wear the name "HiddenItem", so they are named; the assist counts them.
module PokeAccess
  module AshenTruffles
    MAP = 138
    TRUFFLES = 71
    FOUND = 44
    SMELLS = [38, 39, 40, 41]
    NEEDED = 3

    # Whether the player is playing as Truffles and the search is still on.
    def self.searching?
      $game_switches[TRUFFLES] && $game_variables[FOUND].to_i <= NEEDED ? true : false
    end

    # A smell's name: one sniffed already says so.
    def self.smell_label(ev)
      $game_self_switches[[MAP, ev.id, "A"]] ? :aff_smell_done : :aff_smell
    end

    # How many of the three first smells have been sniffed, at most the three.
    def self.sniffed
      [$game_variables[FOUND].to_i, NEEDED].min
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  truffles = PokeAccess::AshenTruffles
  mechanic(:state, truffles::MAP, :part => :aff_truffles) do
    auto
    name truffles::SMELLS, lambda { |ev| truffles.smell_label(ev) }, :when => lambda { |_ev| truffles.searching? }
    count :aff_smells, :value => lambda { truffles.sniffed }, :of => truffles::NEEDED, :assist => true, :reset => false
    hint :aff_smell_hint
    active { truffles.searching? }
    solved(nil, :quiet => true) { $game_variables[truffles::FOUND].to_i > truffles::NEEDED }
  end
end
