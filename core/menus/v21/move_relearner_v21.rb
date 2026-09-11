# Vanilla v21.1 Move Relearner (MoveRelearner_Scene), for games without the BetterMoveRelearner plugin. The
# focused move's detail is hand-drawn in pbDrawMoveList, so the generic bare-name read is muted and the shared
# MoveList.detail is spoken on each redraw. hook_container: this body only STORES, and pbStartScene calls
# pbDrawMoveList, whose hook is the announcer. Gated on the data API rather than the class name, since a
# gen-6 fork can declare the same class with gen-6 internals.
module PokeAccess
  module MoveRelearnerV21
    SCENE = PokeAccess::Engine.era_scene(:gamedata, "MoveRelearner_Scene", "MoveRelearnerScene")
  end
end

PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerV21::SCENE, :pbStartScene, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
end
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerV21::SCENE, :pbDrawMoveList) do |scene, _r, _a|
  PokeAccess::MoveList.detail(scene)
end
