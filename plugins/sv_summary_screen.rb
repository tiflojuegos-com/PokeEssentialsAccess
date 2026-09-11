# Egg Move Learner (EggMoveLearner_Scene, added by a plugin): a move list drawn by hand, so the focused move's
# detail is never spoken. WHAT to say lives in the shared MoveList reader; only WHEN belongs here. The
# generic bare-name read is muted through the mod's own @access_dedicated, then the full detail is read on
# each redraw. hook_container, because this body only STORES and pbStartScene calls pbDrawMoveList, whose
# hook is the announcer.
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbStartScene, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
end
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList, :optional => true) do |scene, _r, _a|
  PokeAccess::MoveList.detail(scene)
end

# And on ENTERING the choice loop, which the redraw does not cover: pbChooseMove only calls pbDrawMoveList
# when the index changes, and on re-entry -- declining the confirmation lands back here -- it sets oldcmd
# equal to the current index on the first pass, so it does not redraw and the screen stays mute over the
# focused move. Before, because pbChooseMove IS the loop: hooked after, it would speak on the way out.
PokeAccess::Hooks.before_hook("EggMoveLearner_Scene", :pbChooseMove, :optional => true) do |scene, _a|
  PokeAccess::MoveList.detail(scene)
end
