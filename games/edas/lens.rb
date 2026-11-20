# Edas' Eye of Truth (0192_Eye of Truth) is the Dark Gem's power, which no item works: L on the map (0058_Scene_Map) and the
# clock's Joya Oscura (0193_MenuReloj, openEye) raise and lower it once switch 231 says the gem was given.
PokeAccess::Game.define("edas") do
  PokeAccess::World::Lens.declare(:name => :edas_lens_name, :usable => lambda { $game_switches[231] ? true : false })
end
