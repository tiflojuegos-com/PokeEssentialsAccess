# Rococo Retreat (map 493, Case Eleven): as Truffles (switch 71), four smell spots (events 15 to 18, HiddenItem) wear a
# smell of their colour; each dug adds one to variable 142, which the cook (map 495) sets to 1; at 5 Trainer Smell
# (event 14) makes the stew, setting 6. Spots are named by colour, a dug one by its hole; the assist counts them.
module PokeAccess
  module AshenRococo
    MAP = 493
    TRAINER = 14
    FOOD = 142
    SPOTS = { 15 => :afc_smell_red, 16 => :afc_smell_red, 17 => :afc_smell_green, 18 => :afc_smell_black }

    # Whether a smell spot is dug: its self switch A.
    def self.dug?(id)
      $game_self_switches[[MAP, id, "A"]] ? true : false
    end

    # How many smell spots are dug.
    def self.dug
      SPOTS.keys.select { |id| dug?(id) }.length
    end

    # A smell spot's name: its colour, or its hole once dug.
    def self.label(ev)
      dug?(ev.id) ? :afc_smell_dug : SPOTS[ev.id]
    end

    # Whether the food is being gathered: from the cook's word to the stew.
    def self.gathering?
      $game_variables[FOOD].to_i.between?(1, 5)
    end

    # Whether every smell is dug and the stew is still to make.
    def self.stew_due?
      $game_variables[FOOD].to_i == 5
    end
  end
end

PokeAccess::Game.define("ashenfrost") do
  rococo = PokeAccess::AshenRococo
  mechanic(:state, rococo::MAP, :part => :food) do
    auto
    name rococo::SPOTS.keys, lambda { |ev| PokeAccess::AshenRococo.label(ev) },
         :when => lambda { |ev| !PokeAccess::AshenRococo.dug?(ev.id) }
    name rococo::TRAINER, :afc_smell_trainer, :when => lambda { |_ev| PokeAccess::AshenRococo.gathering? }
    count :afc_smell_count, :value => lambda { PokeAccess::AshenRococo.dug }, :of => 4, :assist => true
    phase lambda { PokeAccess::Puzzles.assist? && PokeAccess::AshenRococo.stew_due? },
          :hint => :afc_smell_back
    solved(nil, :quiet => true) { $game_variables[PokeAccess::AshenRococo::FOOD].to_i >= 6 }
  end
end
