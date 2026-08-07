# Vanilla v21.1 Move Relearner (MoveRelearner_Scene), for games that do NOT use the BetterMoveRelearner
# plugin (those use UI::MoveReminderVisuals, read via screen_v22). Its move list is a Window_CommandPokemon
# whose names the generic reader already voices, but the focused move's detail (type/power/accuracy/pp/desc)
# is hand-drawn in pbDrawMoveList. The scene exposes the same @pokemon/@moves/@sprites["commands"] shape as
# the egg-move tutor, so both use the shared MoveList.detail (core/menus/move_list): mute the generic
# bare-name read and speak the full detail on each redraw.
#
# hook_container, because this body only STORES and pbStartScene calls pbDrawMoveList, whose hook is the
# announcer; guarded, that opening read would be dropped as nested_other? and the screen would open silent.
#
# The class name alone cannot tell the eras apart: a gen-6 fork can declare MoveRelearner_Scene too, with
# gen-6 internals, and this reader would then mute the generic read and replace it with nothing, since the
# detail comes from GameData::Move. Gate on the data API instead; "" binds nothing.
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
