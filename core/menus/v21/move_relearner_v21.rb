# The v21 Move Relearner (MoveRelearner_Scene): mutes the list's bare-name read and speaks MoveList.detail on each
# pbDrawMoveList. The open hook is a container, since pbStartScene calls pbDrawMoveList, whose hook speaks.
# era_scene keeps it off a gen-6 fork that declares the same class.
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
