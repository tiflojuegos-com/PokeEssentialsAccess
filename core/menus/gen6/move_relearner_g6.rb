# Gen-6 Move Relearner (MoveRelearnerScene, no underscore -- the vanilla gen-6 class, distinct from the
# modern MoveRelearner_Scene read in menus/v21). Its move list is a Window_CommandPokemon whose bare names the
# generic reader already voices, but the focused move's full detail (type/power/accuracy/description) is only
# hand-drawn in pbDrawMoveList. Without this, gen-6 games spoke only the move name while the modern relearner
# and the forget-move screen spoke everything -- the inconsistency players reported. Mute the bare-name read
# and speak the full detail on each redraw, via MoveInfo.by_id_via_data (PBMoveData on gen-6). The BetterMove-
# Relearner plugin stores @moves as [id, "MT"] pairs; vanilla stores plain ids, so unwrap.
module PokeAccess
  module MoveRelearnerGen6
    # The move id under the focused list row. The traversal (and the [id, tag] unwrap this screen needs,
    # because BetterMoveRelearner pairs each id with a tag) is shared with every other hand-drawn move list.
    def self.focused_id(scene)
      PokeAccess::MoveList.focused_id(scene)
    end

    # Speaks the focused move's full detail (or nothing when it cannot be resolved).
    def self.detail(scene)
      id = focused_id(scene)
      return if id.nil?
      s = PokeAccess::MoveInfo.by_id_via_data(id)
      PokeAccess.speak(s, true) if s && !s.to_s.empty?
    rescue StandardError
      nil
    end

    # The scene class to hook, or "" when this reader does not apply to the running engine. Same trap as the
    # gen-6 summary: a fork can declare MoveRelearnerScene as an empty SUBCLASS of MoveRelearner_Scene and
    # only ever build the latter, so this reader bound to nothing -- and move_relearner_v21, matching that
    # v17 name, bound instead, MUTED the generic bare-name read and then said nothing itself, because its
    # detail builder needs GameData::Move. The screen went from "only the move name" to completely silent.
    SCENE = PokeAccess::Engine.era_scene(:gen6, "MoveRelearnerScene", "MoveRelearner_Scene")
  end
end

# Mute the generic bare-name read of the move list, but with the mod's own flag: on gen-6 the command
# window gates its OWN navigation on @ignore_input (050_SpriteWindow), so setting that here would freeze the
# player's cursor. @access_dedicated tells menus.rb to skip the window without touching the engine's input.
# hook_container: this body only STORES, it never speaks, and pbStartScene calls pbDrawMoveList -- whose hook is
# the one that announces. Guarded, that opening read is dropped as nested_other? and the screen opens
# in silence; the guard only earns its keep when the outer hook is itself the announcer.
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbStartScene, :hook_container => true) do |scene, _r, _a|
  PokeAccess.dedicate(PokeAccess.sprite(scene, "commands"))
end
PokeAccess::Hooks.after_hook(PokeAccess::MoveRelearnerGen6::SCENE, :pbDrawMoveList) do |scene, _r, _a|
  PokeAccess::MoveRelearnerGen6.detail(scene)
end
