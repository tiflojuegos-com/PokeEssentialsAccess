module PokeAccess
  # DBK Enhanced Battle UI "Battler Info" overlay (Battle::Scene#pbUpdateBattlerInfo): a panel detailing a
  # battler, navigable left/right between battlers and up/down through its active effects. Read the battler
  # summary when the focused battler changes, and the focused effect when it changes (effects are
  # [name, tick, desc] triples from pbGetDisplayEffects). Gated by method existence so only DBK games bind.
  module DBKBattlerInfo
    # Los tipos que el panel PINTA, que no siempre son los reales. El panel resuelve tres casos antes de
    # dibujar: con Ilusion activa sobre un rival muestra los del Pokemon disfrazado, terastalizado muestra
    # los ANTERIORES a la teracristalizacion, y solo si no hay ninguna de las dos cosas los actuales. Leer
    # los reales revelaba la ilusion -- el dato que el rival esta escondiendo -- y contradecia la pantalla
    # en pleno combate. param battler el battler enfocado
    def self.display_types(battler)
      poke = ((battler.opposes? rescue false) ? (battler.displayPokemon rescue nil) : (battler.pokemon rescue nil))
      illusion = ((battler.effects[PBEffects::Illusion] rescue nil) && !(battler.pbOwnedByPlayer? rescue true))
      return ((poke.types.clone rescue nil) || []) if illusion && !(battler.tera? rescue false)
      return ((battler.pbPreTeraTypes rescue nil) || []) if (battler.tera? rescue false)
      (battler.pbTypes(true) rescue nil) || (battler.types rescue nil)
    rescue StandardError
      (battler.types rescue nil)
    end

    # The battler's types as the panel paints them, or nil. Drawn for BOTH sides, outside the
    # owned-by-player gate, and on a foe they are the reason the panel is opened at all. Hidden behind the
    # panel's own rule for a species never seen -- the same predicate the move-info panel uses, so the two
    # cannot disagree about what is known.
    def self.types(battler)
      return PokeAccess::I18n.t(:pdx_unknown_value) if (PokeAccess::DBKMoveInfo.unknown_species?(battler) rescue false)
      list = display_types(battler)
      names = ([list].flatten.compact.uniq.map { |ty| (PokeAccess::Data.type_name(ty) rescue nil) })
      names = names.compact.reject { |s| s.to_s.empty? }
      names.empty? ? nil : PokeAccess::I18n.t(:mv_type, :t => names.join("/"))
    rescue StandardError
      nil
    end

    # The summary line for a battler (name, level, HP, status, ability, item, last move used), or nil.
    #
    # What the panel WITHHOLDS is withheld here too: the ability, the held item and the numeric hp/totalhp
    # are drawn inside an "if battler.pbOwnedByPlayer?" block, so a foe's panel shows a bar and nothing
    # else, and in a battle those three fields decide the turn. The bar itself is real information, so a
    # foe's HP comes out as the percentage the rest of the mod uses for a bar (Battle.hp_phrase). The level
    # obeys the same rule and reads "???" for a raid boss; the "??" one fangame draws behind its own switch
    # belongs in that profile, and is the one case still read as a number here.
    #
    # El bloque de caracteristicas SI se lee: el panel dibuja una flecha por cada nivel de subida o bajada
    # junto a cada estadistica, y es la mitad de la pantalla que dice si el combate se esta torciendo. Sale
    # por Battle.stat_changes, la misma que usa la tecla de PS, para que las dos digan lo mismo.
    def self.summary(battler)
      parts = []
      owned = (battler.pbOwnedByPlayer? rescue true)
      parts.push(PokeAccess.clean((battler.name rescue "")))
      if (battler.isRaidBoss? rescue false)
        parts.push(PokeAccess::I18n.t(:dbk_level_unknown))
      else
        lvl = (battler.level rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_level, :n => lvl)) if lvl
      end
      hp = (battler.hp rescue nil); thp = (battler.totalhp rescue nil)
      if hp && thp
        parts.push(owned ? PokeAccess::I18n.t(:dbk_hp, :hp => hp, :tot => thp) :
                   PokeAccess::Battle.hp_phrase(hp, thp, true))
      end
      ty = types(battler)
      parts.push(ty) if ty
      st = (battler.status rescue nil)
      if st && st != :NONE
        sn = (GameData::Status.get(st).name rescue nil)
        parts.push(sn) if sn
      end
      if owned
        ab = (battler.abilityName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_ability, :a => ab)) if ab && !ab.to_s.empty?
        it = (battler.itemName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_item, :i => it)) if it && !it.to_s.empty?
      end
      last = (battler.lastMoveUsed rescue nil)
      if last
        mv = (GameData::Move.get(last).name rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_lastmove, :m => mv)) if mv
      end
      st = (PokeAccess::Battle.stat_changes(battler) rescue "")
      parts.push(st.to_s.sub(/\A,\s*/, "")) unless st.to_s.empty?
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
