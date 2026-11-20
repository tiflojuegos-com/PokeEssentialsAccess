# Larkspur's lab (map 75), the cell escape of Garlikid's mission: variable 117 stays at 2 from the capture (the team and the
# bag taken) until the two bundles (events 30 and 31) are picked up. The bed (11) gives a note and turns switch 120 on, the
# wall behind it (12, self switch A once thumped) opens to the console room, and the console (20, self switch A once the
# door is released) frees the cage.
module PokeAccess
  module UraniumCell
    # Whether the player is still in the escape, between the capture and the pick-up of the bundles.
    def self.captive?
      $game_variables[117].to_i == 2
    end

    # Whether a self switch A of an event of the lab is on.
    def self.on?(id)
      $game_self_switches[[75, id, "A"]] ? true : false
    end
  end
end

PokeAccess::Game.define("uranium") do
  mechanic(:state, 75) do
    auto
    name 11, :ura_po_cell_bed
    name 12, :ura_po_cell_wall
    name 20, :ura_po_cell_console
    name [30, 31], :ura_po_cell_stuff
    arrival_hint lambda { PokeAccess::UraniumCell.captive? ? :ura_po_cell_rule : nil }
    phase lambda { PokeAccess::UraniumCell.captive? && !$game_switches[120] }, :quiet => true, :hint => :ura_po_cell_hint_bed
    phase lambda { PokeAccess::UraniumCell.captive? && !PokeAccess::UraniumCell.on?(12) }, :quiet => true,
          :hint => :ura_po_cell_hint_wall
    phase lambda { PokeAccess::UraniumCell.captive? && !PokeAccess::UraniumCell.on?(20) }, :quiet => true,
          :hint => :ura_po_cell_hint_console
    phase lambda { PokeAccess::UraniumCell.captive? }, :quiet => true, :hint => :ura_po_cell_hint_stuff
  end
end
