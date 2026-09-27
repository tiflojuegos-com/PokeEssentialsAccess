# Realidea's Spin Tiles also stop on plain ground (terrain 0) in map 323.
PokeAccess::Game.define("realidea_spin_stop") do
  override("PokeAccess::SpinTiles", :extra_stop?) do |_mod, _original, args|
    ($game_map.map_id rescue 0) == 323 && PokeAccess::Terrain.number_at(args[0], args[1]) == 0
  end
end
