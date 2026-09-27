# The v21 trainer card (PokemonTrainerCard_Scene), read as it paints itself through TrainerCard.read_face, with
# TrainerCardData as fallback; era_scene leaves a gen-6 fork declaring the same class to menus/trainer_card.
module PokeAccess
  module TrainerCardV21
    SCENE = PokeAccess::Engine.era_scene(:gamedata, "PokemonTrainerCard_Scene", "PokemonTrainerCardScene")
  end
end

PokeAccess::Hooks.around_hook(PokeAccess::TrainerCardV21::SCENE, :pbDrawTrainerCardFront, :optional => true) do |scene, nxt, _a|
  PokeAccess::TrainerCard.read_face(scene, true, lambda { PokeAccess::TrainerCardData.text }) { nxt.call }
end
