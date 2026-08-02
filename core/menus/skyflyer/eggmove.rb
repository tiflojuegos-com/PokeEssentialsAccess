module PokeAccess
  # Egg Move Learner (Skyflyer's "Tutor de Movimientos Huevo", EggMoveLearner_Scene): a move list drawn by
  # hand (like the Move Reminder), so the focused move's detail -- type, power, accuracy, pp, description --
  # is not spoken. pbDrawMoveList redraws on each cursor move; read the focused move's full detail there.
  # The bare name is already read by the generic command hook, so its window is muted to avoid a double read.
  module SkyEggMove
    def self.detail(scene)
      pk = PokeAccess.ivar(scene, :@pokemon)
      moves = PokeAccess.ivar(scene, :@moves)
      win = PokeAccess.sprite(scene, "commands")
      idx = (win.index rescue nil)
      return unless pk && moves.is_a?(Array) && idx && idx >= 0 && idx < moves.length
      d = (GameData::Move.get(moves[idx]) rescue nil)
      return unless d
      nm = (d.name rescue PokeAccess::I18n.t(:info_move))
      ty = (GameData::Type.get(d.display_type(pk)).name rescue nil)
      pw = (d.display_damage(pk) rescue (d.power rescue 0)).to_i
      acc = (d.display_accuracy(pk) rescue (d.accuracy rescue 0)).to_i
      tot = (d.total_pp rescue nil)
      desc = (d.description rescue "")
      s = PokeAccess::MoveInfo.line(nm.to_s, ty, pw, acc, :pp => tot, :total_pp => tot, :desc => desc)
      PokeAccess.speak(s, true)
    rescue StandardError
      nil
    end
  end
end

# Mute the generic bare-name read of the move window, then read the full detail on each redraw. Use the mod's
# own @access_dedicated flag (not @ignore_input, which some Selectable windows use to gate their navigation).
# hook_container: this body only STORES, it never speaks, and pbStartScene calls pbDrawMoveList -- whose hook is
# the one that announces. Guarded, that opening read is dropped as nested_other? and the screen opens
# in silence; the guard only earns its keep when the outer hook is itself the announcer.
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbStartScene, :hook_container => true) do |scene, _r, _a|
  w = PokeAccess.sprite(scene, "commands")
  w.instance_variable_set(:@access_dedicated, true) if w
end
PokeAccess::Hooks.after_hook("EggMoveLearner_Scene", :pbDrawMoveList) do |scene, _r, _a|
  PokeAccess::SkyEggMove.detail(scene)
end
