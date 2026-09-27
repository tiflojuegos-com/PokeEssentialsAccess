# Royal's League Card (TarjetaEntrenador_Scene), painted once in pbStartScene and read by the core card reader.
PokeAccess::Game.define("royal") do
  around("TarjetaEntrenador_Scene", :pbStartScene) do |scene, nxt, _a|
    PokeAccess::TrainerCard.read_face(scene, false) { nxt.call }
  end
end
