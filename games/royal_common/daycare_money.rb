# Royal's daycare level-up (guarderia_subir_niveles_equipo, Scripts del Royal/000_Scripts menores.rb), which a map
# event runs once the party screen picks the Pokemon: it builds its own "Dinero:" window, not pbDisplayGoldWindow,
# and repaints it after the purchase; the window is watched while the function runs.
PokeAccess::Game.define("royal_common") do
  kernel("guarderia_subir_niveles_equipo", :around) { |_args, nxt| PokeAccess::MoneyWindow.watch { nxt.call } }
end
