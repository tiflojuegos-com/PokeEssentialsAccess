module PokeAccess
  # DBK Enhanced Battle UI "Move Info" overlay (Battle::Scene#pbUpdateMoveInfoWindow): a panel toggled over
  # the fight menu that details the focused move (type, category, power, accuracy). The fight menu already
  # voices the move name and PP, so this adds the extra stats, recomputed from the move data exactly as the
  # window does (power = move.power, type = move.pbCalcType(battler), category = move.category). Gated by
  # method existence so only DBK games bind.
  module DBKMoveInfo
    CATS = [:cat_physical, :cat_special, :cat_status]
    STATUS_CAT = 2

    # The spoken stats line for the move at index idx of battler, or nil. Mirrors DBK's window by converting
    # the move clone to its Z-move / Max-move form when that mechanic is staged (special + cw.mode == 2), so
    # the announced type/power match what is drawn instead of the base move.
    def self.text(battler, idx, special = nil, cw = nil, scene = nil)
      move = (battler.moves[idx] rescue nil)
      return nil unless move
      move = (move.clone rescue move)
      begin
        battle = (scene ? scene.instance_variable_get(:@battle) : nil)
        mode = (cw ? (cw.mode rescue 0) : 0)
        if special == :zmove && mode == 2 && move.respond_to?(:convert_zmove)
          move = move.convert_zmove(battler, battle, idx, false)
        elsif ((battler.dynamax? rescue false) || (special == :dynamax && mode == 2)) && move.respond_to?(:convert_dynamax_move)
          move = move.convert_dynamax_move(battler, battle, idx)
        end
      rescue StandardError
      end
      parts = []
      name = PokeAccess.clean((move.name rescue ""))
      parts.push(name) unless name.to_s.empty?
      t = (move.pbCalcType(battler) rescue nil) || (move.type rescue nil)
      tname = t ? (GameData::Type.get(t).name rescue nil) : nil
      parts.push(PokeAccess::I18n.t(:mv_type, :t => tname)) if tname
      cat = (move.category rescue nil)
      parts.push(PokeAccess::I18n.t(:mv_category, :c => PokeAccess::I18n.t(CATS[cat]))) if cat && CATS[cat]
      unless cat == STATUS_CAT
        pw = (move.power rescue 0)
        parts.push(PokeAccess::I18n.t(:mv_power, :p => PokeAccess::MoveInfo.power_phrase(pw)))
      end
      acc = (move.accuracy rescue 0)
      parts.push(PokeAccess::I18n.t(:mv_acc, :a => PokeAccess::MoveInfo.accuracy_phrase(acc)))
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, _ret, args|
  battler = args[0]; cw = args[2]
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :move && battler && cw
    idx = (cw.index rescue nil)
    key = idx.nil? ? nil : "mi#{(battler.index rescue 0)}_#{idx}"
    if key && key != PokeAccess.ivar(scene, :@access_moveinfo)
      scene.instance_variable_set(:@access_moveinfo, key)
      t = PokeAccess::DBKMoveInfo.text(battler, idx, args[1], cw, scene)
      PokeAccess.speak(t, true) if t && !t.to_s.empty?
    end
  else
    scene.instance_variable_set(:@access_moveinfo, nil) rescue nil
  end
end
