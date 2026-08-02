# Classic trainer card (PokemonTrainerCard_Scene): a static panel drawn once on open, read all on arrival
# (nothing to navigate). The spoken content is the agnostic TrainerCardData; this only wires the scene.
#
# Gated on the data API, not on the class name: a gen-6 fork can declare this same class name (Awakening's
# BES-T compatibility layer) and TrainerCardData reads the modern accessors, so it would answer with a card
# missing the ID, the Pokedex tally and the play time. There the gen-6 card in menus/trainer_card wins.
module PokeAccess
  module TrainerCardV21
    SCENE = PokeAccess::Engine.era_scene(:gamedata, "PokemonTrainerCard_Scene", "PokemonTrainerCardScene")
  end
end

PokeAccess::Hooks.read_on_open(PokeAccess::TrainerCardV21::SCENE) { |_s| PokeAccess::TrainerCardData.text }
