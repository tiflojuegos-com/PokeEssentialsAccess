# Egg Move Learner (the "Tutor de Movimientos Huevo" screen a plugin adds, EggMoveLearner_Scene): a move
# list drawn by hand, so the focused move's detail is never spoken. WHAT to say lives in the shared
# MoveList reader, which the v21 Move Relearner uses too; only WHEN to say it belongs here, because only
# this screen is the plugin's.
#
# Mute the generic bare-name read of the move window first, then read the full detail on each redraw. The
# flag is the mod's own @access_dedicated, not @ignore_input, which some Selectable windows already use to
# gate their navigation.
#
# hook_container: this body only STORES, it never speaks, and pbStartScene calls pbDrawMoveList -- whose
# hook is the one that announces. Guarded, that opening read is dropped as nested_other? and the screen
# opens in silence; the guard only earns its keep when the outer hook is itself the announcer.
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbStartScene, :optional => true, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
end
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList, :optional => true) do |scene, _r, _a|
  PokeAccess::MoveList.detail(scene)
end
