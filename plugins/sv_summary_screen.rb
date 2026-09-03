# Egg Move Learner (the "Tutor de Movimientos Huevo" screen a plugin adds, EggMoveLearner_Scene): a move
# list drawn by hand, so the focused move's detail is never spoken. WHAT to say lives in the shared
# MoveList reader, which the v21 Move Relearner uses too; only WHEN to say it belongs here, because only
# this screen is the plugin's.
#
# Mute the generic bare-name read of the move window first, then read the full detail on each redraw. The
# flag is the mod's own @access_dedicated, not @ignore_input, which some Selectable windows already use to
# gate their navigation.
#
# hook_container, because this body only STORES and pbStartScene calls pbDrawMoveList, whose hook is the
# announcer; guarded, that opening read would be dropped as nested_other? and the screen would open silent.
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
