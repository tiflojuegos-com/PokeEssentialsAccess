# Realidea's two Jade screens (games/realidea/jade_screens.rb): the theatre's choreography sheet, four
# columns painted through drawTextEx, and the gym's cry helper, three species with the chosen one marked
# by colour alone. The readers' pure halves are pinned here; the hooks bind to classes only that game has.
require File.expand_path("../../../games/realidea/jade_screens", File.dirname(__FILE__))

Suite.define("realidea: the choreography sheet reads as one line per Oricorio, and the cry helper names its species") do
  rj = PokeAccess::ReaJade

  eq "each column becomes its header and its steps in order",
     rj.sheet_text(["Oricorio 1\nArriba\nSalto\nDerecha", "Oricorio 2\nAbajo\nIzquierda"]),
     "Oricorio 1: Arriba, Salto, Derecha. Oricorio 2: Abajo, Izquierda"
  eq "a blank capture says nothing", rj.sheet_text([]), ""
  eq "a column of one line is said as it is", rj.sheet_text(["Sin pasos"]), "Sin pasos"

  eq "the cursor's species and its position among the three",
     rj.cry_text(2, 1), "#{PokeAccess::Data.species_name(35)}, 2 de 3"
  eq "the third group's last member", rj.cry_text(3, 3), "#{PokeAccess::Data.species_name(755)}, 3 de 3"
  eq "off the table there is nothing to say", rj.cry_text(0, 1), nil
  eq "and an unknown group neither", rj.cry_text(1, 9), nil
end
