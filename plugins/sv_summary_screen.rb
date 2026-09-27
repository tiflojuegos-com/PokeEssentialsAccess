# Egg Move Learner (EggMoveLearner_Scene), a hand-drawn move list: the generic read is muted (dedicate) and the
# shared MoveList detail is read on each redraw; hook_container, as pbStartScene drives pbDrawMoveList's hook.
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbStartScene, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
end
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList, :optional => true) do |scene, _r, _a|
  PokeAccess::MoveList.detail(scene)
end

# And before pbChooseMove, the choice loop, whose re-entry (after declining the confirmation) does not redraw.
PokeAccess::Hooks.before_hook("EggMoveLearner_Scene", :pbChooseMove, :optional => true) do |scene, _a|
  PokeAccess::MoveList.detail(scene)
end
