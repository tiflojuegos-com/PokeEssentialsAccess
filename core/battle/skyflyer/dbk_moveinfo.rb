module PokeAccess
  # DBK Enhanced Battle UI "Move Info" overlay (Battle::Scene#pbUpdateMoveInfoWindow): a panel toggled over
  # the fight menu that details the focused move (type, category, power, accuracy). The fight menu already
  # voices the move name and PP, so this adds the extra stats, recomputed from the move data exactly as the
  # window does (power = move.power, type = move.pbCalcType(battler), category = move.category). Gated by
  # method existence so only DBK games bind.
  module DBKMoveInfo
    CATS = [:cat_physical, :cat_special, :cat_status]
    STATUS_CAT = 2

    # The five states pbDrawTypeEffectiveness paints over each opposing battler, in its own order.
    EFFECT_KEYS = [:mv_eff_unknown, :mv_eff_none, :mv_eff_weak, :mv_eff_super, :mv_eff_neutral]

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
      pri = (move.priority rescue 0).to_i
      parts.push(PokeAccess::I18n.t(:mv_priority, :n => pri)) unless pri == 0
      eff = effectiveness(scene, move, t)
      parts.push(eff) if eff
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError
      nil
    end

    # How the move lands on each opposing battler, worded from the icon the panel paints over it. This is the
    # reason the panel exists -- a sighted player reads that icon at a glance -- and it was the one thing the
    # reader never said, so a blind player toggled the panel open and got the same four stats the fight menu
    # already gives. Status moves have no icon, and neither has this.
    def self.effectiveness(scene, move, type)
      battle = (scene ? scene.instance_variable_get(:@battle) : nil)
      return nil unless battle && type && (move.category rescue STATUS_CAT) < STATUS_CAT
      out = []
      (battle.allBattlers rescue []).each do |b|
        next if b.nil? || (b.index rescue 0).even? || (b.fainted? rescue true)
        word = PokeAccess::I18n.t(EFFECT_KEYS[effect_index(b, type)])
        out.push([PokeAccess.clean((b.name rescue "")).to_s.strip, word])
      end
      return nil if out.empty?
      return out[0][1] if out.length == 1
      out.map { |n, e| PokeAccess::I18n.t(:mv_eff_vs, :name => n, :eff => e) }.join(", ")
    rescue StandardError
      nil
    end

    # The icon index for one target, classified exactly as pbDrawTypeEffectiveness does -- unknown species
    # included: the panel hides the answer for a species the player has neither battled nor owns, and saying
    # it anyway would hand out information the screen is deliberately withholding.
    def self.effect_index(b, type)
      return 0 if unknown_species?(b)
      return 3 if (b.tera? rescue false) && type == :STELLAR
      value = Effectiveness.calculate(type, *b.pbTypes(true))
      return 1 if Effectiveness.ineffective?(value)
      return 2 if Effectiveness.not_very_effective?(value)
      return 3 if Effectiveness.super_effective?(value)
      4
    end

    # Whether the panel withholds the effectiveness for this target. Same precedence as the plugin: a
    # celestial battler is always hidden, the setting reveals every new species, and otherwise it is hidden
    # until the player has battled or owned the species.
    def self.unknown_species?(b)
      return true if (b.celestial? rescue false)
      return false if (Settings::SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES rescue false)
      sp = (b.displayPokemon.species rescue nil)
      return false if sp.nil?
      ($player.pokedex.battled_count(sp) == 0 && !$player.pokedex.owned?(sp)) rescue false
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
