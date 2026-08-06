# Vanilla v21.1 Move Relearner (MoveRelearner_Scene), for games that do NOT use the BetterMoveRelearner
# plugin (those use UI::MoveReminderVisuals, read via screen_v22). Its move list is a Window_CommandPokemon
# whose names the generic reader already voices, but the focused move's detail (type/power/accuracy/pp/desc)
# is hand-drawn in pbDrawMoveList. The scene exposes the same @pokemon/@moves/@sprites["commands"] shape as
# the egg-move tutor, so both use the shared MoveList.detail (core/menus/move_list). Mute the generic
# bare-name read and speak the full detail on each redraw.
# hook_container: this body only STORES, it never speaks, and pbStartScene calls pbDrawMoveList -- whose hook is
# the one that announces. Guarded, that opening read is dropped as nested_other? and the screen opens
# in silence; the guard only earns its keep when the outer hook is itself the announcer.
# The class name is NOT enough to tell the eras apart here: a gen-6 fork can declare MoveRelearner_Scene
# too (Awakening's BES-T compatibility layer) with gen-6 internals, and this reader would then mute the
# generic bare-name read and replace it with nothing, because the detail comes from GameData::Move. Gate on
# the data API, which is what this file is actually written against; "" binds nothing.
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
