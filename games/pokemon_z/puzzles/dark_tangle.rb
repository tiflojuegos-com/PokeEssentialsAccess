# Maraña Oscura (maps 387 and 388): each part of a floor has its one way on among ropes and cobwebs with no graphic or
# text: six in a row down to Arrayán and, from where a wrong one drops the player, the rope back up.
PokeAccess::Game.define("pokemon_z") do
  [[387, [[at(37, 42, 6, 10), 6, :z_tangle_platform], [at(32, 50, 2, 17), 3, :z_tangle_detour],
          [at(0, 22, 0, 27), 4, :z_tangle_1], [at(33, 46, 20, 27), 11, :z_tangle_2],
          [at(3, 21, 32, 56), 15, :z_tangle_3], [at(28, 50, 32, 40), 9, :z_tangle_detour],
          [at(28, 53, 48, 62), 18, :z_tangle_4]]],
   [388, [[at(19, 28, 25, 29), 7, :z_tangle_5], [at(27, 35, 6, 9), 2, :z_tangle_platform],
          [at(43, 71, 2, 23), 4, :z_tangle_6], [at(3, 26, 2, 35), 1, :z_tangle_detour],
          [at(42, 55, 30, 36), 6, :z_tangle_detour]]]].each do |map, parts|
    mechanic(:state, map) do
      parts.each { |zone, event, key| phase zone, :hint => key, :hidden => right_way(event) }
    end
  end
end
