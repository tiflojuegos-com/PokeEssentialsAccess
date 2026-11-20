# Chrono Island's Rocket Warehouse (map 625): the switch on the wall (event 8, no graphic, switch 415) opens the two doors
# drawn in it (events 4 and 7), which lead to the small room of map 643 with a wild Klinklang.
PokeAccess::Game.define("infinitefusion") do
  mechanic(:state, 625) do
    auto
    name 8, :ifq_wh_switch
    name [4, 7], :ifq_wh_door
    watch :switch => 415, :label => :ifq_wh_doors, :on => :ifq_wh_open, :off => :ifq_wh_closed
    hint :ifq_wh_hint
  end
end
