module PokeAccess
  # DBK Enhanced Battle UI "Battler Info" overlay (Battle::Scene#pbUpdateBattlerInfo): a panel detailing a
  # battler, navigable left/right between battlers and up/down through its active effects. Read the battler
  # summary when the focused battler changes, and the focused effect when it changes (effects are
  # [name, tick, desc] triples from pbGetDisplayEffects). Gated by method existence so only DBK games bind.
  module DBKBattlerInfo
    # The summary line for a battler (name, level, HP, status, ability, item, last move used), or nil.
    def self.summary(battler)
      parts = []
      parts.push(PokeAccess.clean((battler.name rescue "")))
      lvl = (battler.level rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_level, :n => lvl)) if lvl
      hp = (battler.hp rescue nil); thp = (battler.totalhp rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_hp, :hp => hp, :tot => thp)) if hp && thp
      st = (battler.status rescue nil)
      if st && st != :NONE
        sn = (GameData::Status.get(st).name rescue nil)
        parts.push(sn) if sn
      end
      ab = (battler.abilityName rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_ability, :a => ab)) if ab && !ab.to_s.empty?
      it = (battler.itemName rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_item, :i => it)) if it && !it.to_s.empty?
      last = (battler.lastMoveUsed rescue nil)
      if last
        mv = (GameData::Move.get(last).name rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_lastmove, :m => mv)) if mv
      end
      r = parts.reject { |x| x.to_s.empty? }
      r.empty? ? nil : r.join(", ")
    rescue StandardError
      nil
    end

    # The focused effect line ([name, tick, desc]) or nil; the "--" placeholder tick is dropped.
    def self.effect_text(effects, idx)
      e = (effects[idx] rescue nil)
      return nil unless e.is_a?(Array)
      out = []
      out.push(e[0]) if e[0] && !e[0].to_s.empty?
      out.push(e[1]) if e[1] && e[1].to_s != "--" && !e[1].to_s.empty?
      out.push(e[2]) if e[2] && !e[2].to_s.empty?
      out.empty? ? nil : PokeAccess.clean(out.join(". "))
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, _ret, args|
  battler = args[0]; effects = args[1]; idx_effect = args[2] || 0
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :battler && battler
    bidx = (battler.index rescue nil)
    prev = PokeAccess.ivar(scene, :@access_binfo)
    key = [bidx, idx_effect]
    if key != prev
      scene.instance_variable_set(:@access_binfo, key)
      eff = PokeAccess::DBKBattlerInfo.effect_text(effects, idx_effect)
      if !prev || prev[0] != bidx
        sm = PokeAccess::DBKBattlerInfo.summary(battler)
        PokeAccess.speak(sm, true) if sm && !sm.to_s.empty?
        PokeAccess.speak(eff, false) if eff && !eff.to_s.empty?
      elsif eff && !eff.to_s.empty?
        PokeAccess.speak(eff, true)
      end
    end
  else
    scene.instance_variable_set(:@access_binfo, nil) rescue nil
  end
end
