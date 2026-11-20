# Facility Lab (map 362): after Caitlin's scene (event 13, S92) each of the five enclosures (events 17, 19, 20, 21 and 22)
# shows the next of its five Pokémon at each press of its switch, counting in V142 to V146 and back to 0 after the fifth.
# The panel before Caitlin (event 18, stepped on) checks them: only V142 = 4, V143 = 2, V144 = 3, V145 = 4 and V146 = 1,
# a Raticate in every enclosure, sets S218, which lowers the two barriers (events 2 and 3), and S93.
module PokeAccess
  module SS2FacilityLab
    PENS = [[17, 142, [:ARON, :BALTOY, :CARNIVINE, :DARUMAKA, :RATICATE]],
            [19, 143, [:AZURILL, :AIPOM, :RATICATE, :FEAROW, :GOLBAT]],
            [20, 144, [:HONCHKROW, :IVYSAUR, :JOLTIK, :RATICATE, :KOFFING]],
            [21, 145, [:LEDIAN, :MAGNETON, :NOSEPASS, :OCTILLERY, :RATICATE]],
            [22, 146, [:PATRAT, :RATICATE, :SEAKING, :TENTACRUEL, :URSARING]]]

    # A species' name as the game spells it, or its id when the game does not know it.
    def self.species(sym)
      PokeAccess::Data.species_name(sym) || PokeAccess::Util.capitalized(sym)
    end

    # The Pokémon an enclosure shows now, by its variable.
    def self.shown(pen)
      list = pen[2]
      list[$game_variables[pen[1]] % list.length]
    end

    # An enclosure's name: its number and the Pokémon in it.
    def self.label(ev)
      i = PENS.index { |p| p[0] == ev.id }
      return nil unless i
      [:ss2_pz_lab_pen, { :n => i + 1, :mon => species(shown(PENS[i])) }]
    end

    # The presses each enclosure still needs to show its Raticate, then the panel; with all set, the panel alone.
    def self.hint
      t = PokeAccess::I18n
      left = PENS.each_with_index.map do |p, i|
        presses = (p[2].index(:RATICATE) - $game_variables[p[1]]) % p[2].length
        presses > 0 ? t.t(:ss2_pz_lab_h_pen, :n => i + 1, :presses => presses) : nil
      end.compact
      return t.t(:ss2_pz_lab_h_panel) if left.empty?
      PokeAccess.sentences([t.t(:ss2_pz_lab_h_all), left.join(", ")])
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  mechanic(:state, 362) do
    name PokeAccess::SS2FacilityLab::PENS.map { |p| p[0] }, lambda { |ev| PokeAccess::SS2FacilityLab.label(ev) },
         :when => lambda { |_ev| $game_switches[92] && !$game_switches[93] }
    name 18, :ss2_pz_lab_panel, :when => lambda { |_ev| $game_switches[92] && !$game_switches[93] }
    name [23, 24, 25, 26], :ss2_pz_lab_terminal
    obstacle(/lazer/i, :label => :ss2_pz_lab_barrier)
    PokeAccess::SS2FacilityLab::PENS.each_with_index do |p, i|
      words = {}
      p[2].each_with_index { |sym, v| words[v] = lambda { PokeAccess::SS2FacilityLab.species(sym) } }
      watch :var => p[1], :label => [:ss2_pz_lab_pen_n, { :n => i + 1 }], :words => words
    end
    active { $game_switches[92] && !$game_switches[93] }
    solved { $game_switches[93] }
    hint lambda { PokeAccess::SS2FacilityLab.hint }
  end
end
