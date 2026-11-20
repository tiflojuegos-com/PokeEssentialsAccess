# Perseida's Eye of Truth (0228_Eye of truth) is the Dark Gem's power, which no item works: Q on the map (0060_Scene_Map,
# common event 65) and the clock's Joya Oscura (0213_Menu_Reloj, openEye) raise and lower it once JOYA_OSCURA, switch 128,
# says the gem was given. Its copy also marks events by hideEvent and showEvent comments, and Scene_Map lowers it as soon
# as an event runs, unless the menu is disabled or switch 127 holds it up for the gem's own lesson on Route 7.
PokeAccess::Game.define("perseida") do
  PokeAccess::World::Lens.declare(:name => :edas_lens_name, :usable => lambda { $game_switches[JOYA_OSCURA] ? true : false },
                                  :comments => true,
                                  :ends_on_events => lambda { !($game_system.menu_disabled rescue false) && !$game_switches[127] })
end
