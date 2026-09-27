# [DBK] Enhanced Battle UI, bundled by La Base de Sky (anil, emerald, relict, royal): the move-info window, the
# battler-info panel and the ball and battler selectors; the Deluxe Battle Kit's mechanic toggles are dbk_battle.

module PokeAccess
  # The Move Info panel (Battle::Scene#pbUpdateMoveInfoWindow), toggled over the fight menu: the focused move's type,
  # category and figures as the window works them out, and its effectiveness on each foe.
  module DBKMoveInfo
    STATUS_CAT = 2

    # The five states pbDrawTypeEffectiveness paints over each opposing battler, in its own order.
    EFFECT_KEYS = [:mv_eff_unknown, :mv_eff_none, :mv_eff_weak, :mv_eff_super, :mv_eff_neutral]

    # Function codes of Tera Blast and Tera Starstorm, in that order, whose type and category the window works out.
    TERA_CATEGORY = ["CategoryDependsOnHigherDamageTera", "TerapagosCategoryDependsOnHigherDamage"]

    # Whether the window draws the move as terastallized: the battler is, Tera is staged for it, or it is Terapagos in
    # its Stellar Form (elsewhere than Anil and Royal that form comes only with terastallizing).
    def self.terastal?(battler, special, cw)
      return true if (battler.tera? rescue false)
      return true if special == :tera && ((cw.teraType rescue 0).to_i > 0)
      (battler.isSpecies?(:TERAPAGOS) rescue false) && (battler.form rescue 0).to_i == 2
    end

    # The type the window draws for a move: the calculated one, but for the two Tera moves their stored type until
    # terastallized, then the Tera type (Tera Blast) or, on Terapagos, Stellar (Tera Starstorm).
    def self.shown_type(move, battler, terastal)
      fc = (move.function_code rescue nil)
      calc = (move.pbCalcType(battler) rescue nil) || (move.type rescue nil)
      return calc unless TERA_CATEGORY.include?(fc)
      return (move.type rescue nil) unless terastal
      return (battler.tera_type rescue nil) || calc if fc == TERA_CATEGORY[0]
      (battler.isSpecies?(:TERAPAGOS) rescue false) ? :STELLAR : calc
    end

    # The category the window draws for a move: for the Tera moves calcCategory, or the higher attacking stat once
    # terastallized; target-dependent ones against the foe ahead; the rest their own.
    def self.shown_category(move, battler, terastal)
      fc = (move.function_code rescue nil)
      if TERA_CATEGORY.include?(fc)
        return (move.calcCategory rescue nil) unless terastal
        atk, spatk = battler.getOffensiveStats
        return atk > spatk ? 0 : 1
      end
      PokeAccess::MoveInfo.target_category(move, battler) || PokeAccess::MoveInfo.category_of(move)
    rescue StandardError
      PokeAccess::MoveInfo.category_of(move)
    end

    # The spoken stats of battler's move idx, one phrase each, or nil; a staged Z-move or Max Move (cw.mode 2), or a
    # dynamaxed battler's, is read in that form, as the window draws it.
    def self.parts(battler, idx, special = nil, cw = nil, scene = nil)
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
      terastal = terastal?(battler, special, cw)
      t = shown_type(move, battler, terastal)
      tname = t ? (GameData::Type.get(t).name rescue nil) : nil
      parts.push(PokeAccess::I18n.t(:mv_type, :t => tname)) if tname
      cat = PokeAccess::MoveInfo.category_word(shown_category(move, battler, terastal))
      parts.push(cat) if cat
      figures(move).each { |f| parts.push(f) }
      parts.push(bonus) if bonus
      if PokeAccess::Verbosity.keep?(:battle_move, :medium)
        words = flag_words(move)
        parts.push(PokeAccess::I18n.t(:dbk_flags, :list => words.join(", "))) unless words.empty?
      end
      eff = effectiveness(scene, move, t)
      parts.push(eff) if eff
      parts.empty? ? nil : parts
    rescue StandardError
      nil
    end

    # The panel's four figures (power, accuracy, priority, effect chance) as spoken lines, from what it painted (its
    # damage runs through pbGetFinalModifiers), else the move data with no effect chance. "---" is no power, no miss,
    # no priority or no chance by column, "???" a variable power.
    def self.figures(move)
      p = @painted
      out = []
      unless (move.category rescue STATUS_CAT) == STATUS_CAT
        pw = p ? power_word(p[0]) : PokeAccess::MoveInfo.power_phrase((move.power rescue 0))
        out.push(PokeAccess::I18n.t(:mv_power, :p => pw))
      end
      acc = p ? acc_word(p[1]) : PokeAccess::MoveInfo.accuracy_phrase((move.accuracy rescue 0))
      out.push(PokeAccess::I18n.t(:mv_acc, :a => acc))
      pri = p ? p[2] : ((move.priority rescue 0).to_i == 0 ? "---" : (move.priority rescue 0).to_i.to_s)
      out.push(PokeAccess::I18n.t(:mv_priority, :n => pri)) unless pri.to_s == "---"
      out.push(PokeAccess::I18n.t(:mv_effect, :n => p[3])) if p && p[3].to_s != "---"
      out
    rescue StandardError
      []
    end

    def self.power_word(s)
      return PokeAccess::I18n.t(:mv_power_none) if s.to_s == "---"
      return PokeAccess::I18n.t(:mv_power_var) if s.to_s == "???"
      s.to_s
    end

    def self.acc_word(s)
      s.to_s == "---" ? PokeAccess::I18n.t(:mv_acc_perfect) : s.to_s
    end

    # The panel's figures and bonus line, caught from its own draw call while it paints: the only four centred rows
    # (the labels are left-aligned), which holds in every copy whatever it translates or shifts, and the left-aligned
    # row pushed after them when pbGetFinalModifiers gives one ("Poder potenciado por Torrente."), its stop dropped
    # as the reading joins its phrases with commas.
    @painted = nil
    @bonus = nil
    @armed = false

    def self.capture_on; @painted = nil; @bonus = nil; @armed = true; end
    def self.capture_off; @armed = false; end

    def self.note_draw(rows)
      return unless @armed && rows.is_a?(Array)
      vals = rows.select { |r| r.is_a?(Array) && r[3] == :center }.map { |r| r[0].to_s.strip }
      return unless vals.length == 4
      @painted = vals
      last = rows.rindex { |r| r.is_a?(Array) && r[3] == :center }
      after = rows[(last + 1)..-1].select { |r| r.is_a?(Array) && r[3] == :left }
      t = after.empty? ? "" : PokeAccess.clean(after.first[0].to_s).sub(/\.+\z/, "")
      @bonus = t.empty? ? nil : t
    rescue StandardError
      nil
    end

    # The bonus line the panel painted with its figures, or nil.
    def self.bonus; @bonus; end

    # The move-property icons (Move Flags) by flag, the same set in every copy.
    FLAG_KEYS = {
      "Contact" => :dbkf_contact, "NoProtect" => :dbkf_noprotect, "NoMirrorMove" => :dbkf_nomirror,
      "TramplesMinimize" => :dbkf_minimize, "HighCriticalHitRate" => :dbkf_crit, "ThawsUser" => :dbkf_thaws,
      "Sound" => :dbkf_sound, "Wind" => :dbkf_wind, "Punching" => :dbkf_punch, "Biting" => :dbkf_bite,
      "Bomb" => :dbkf_bomb, "Pulse" => :dbkf_pulse, "Powder" => :dbkf_powder, "Dance" => :dbkf_dance,
      "Slicing" => :dbkf_slice, "ElectrocuteUser" => :dbkf_electro, "DynamaxMove" => :dbkf_dynamax,
      "ZMove" => :dbkf_zmove
    }

    # The icons pbDrawMoveFlagIcons draws, named in its order and at most nine: the move's flags (a Z or Max Move's
    # by its family, a critical-hit one too) and, aimed at a foe, NoProtect and NoMirrorMove when it lacks
    # CanProtect and CanMirrorMove; a flag with no icon is skipped.
    def self.flag_words(move)
      flags = ((move.flags rescue nil) || []).map { |f| f.to_s }
      if (GameData::Target.get(move.target).targets_foe rescue false)
        flags.push("NoProtect") unless flags.include?("CanProtect")
        flags.push("NoMirrorMove") unless flags.include?("CanMirrorMove")
      end
      words = []
      flags.uniq.each do |f|
        break if words.length > 8
        f = "ZMove" if f.include?("ZMove_")
        f = "DynamaxMove" if f.include?("DynamaxMove_") || f == "GmaxMove"
        f = "HighCriticalHitRate" if f.include?("HighCriticalHitRate_")
        key = FLAG_KEYS[f]
        words.push(PokeAccess::I18n.t(key)) if key
      end
      words
    rescue StandardError
      []
    end

    # How the move lands on each opposing battler, worded from the icon the panel paints over it; nil for a status
    # move, which has no icon.
    def self.effectiveness(scene, move, type)
      battle = (scene ? scene.instance_variable_get(:@battle) : nil)
      return nil unless battle && type && (move.category rescue STATUS_CAT) < STATUS_CAT
      out = []
      (battle.allBattlers rescue []).each do |b|
        next if b.nil? || (b.index rescue 0).even? || (b.fainted? rescue true)
        word = PokeAccess::I18n.t(EFFECT_KEYS[effect_index(b, type)])
        out.push([PokeAccess.clean((b.name rescue "")), word])
      end
      return nil if out.empty?
      return out[0][1] if out.length == 1
      out.map { |n, e| PokeAccess::I18n.t(:mv_eff_vs, :name => n, :eff => e) }.join(", ")
    rescue StandardError
      nil
    end

    # The icon index for one target, classified as pbDrawTypeEffectiveness does, the hidden unknown species included.
    def self.effect_index(b, type)
      return 0 if unknown_species?(b)
      return 3 if (b.tera? rescue false) && type == :STELLAR
      value = Effectiveness.calculate(type, *b.pbTypes(true))
      return 1 if Effectiveness.ineffective?(value)
      return 2 if Effectiveness.not_very_effective?(value)
      return 3 if Effectiveness.super_effective?(value)
      4
    end

    # Whether the panel withholds the effectiveness for this target, in the plugin's order: always for a celestial
    # battler, never with the reveal setting, else until the species is battled or owned.
    def self.unknown_species?(b)
      return true if (b.celestial? rescue false)
      return false if (Settings::SHOW_TYPE_EFFECTIVENESS_FOR_NEW_SPECIES rescue false)
      sp = (b.displayPokemon.species rescue nil)
      return false if sp.nil?
      ($player.pokedex.battled_count(sp) == 0 && !$player.pokedex.owned?(sp)) rescue false
    end
  end
end

# Arms the capture around the panel's draw; the reading runs after, on the figures it wrote.
PokeAccess::Hooks.around_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |_s, nxt, _a|
  PokeAccess::DBKMoveInfo.capture_on
  begin; nxt.call; ensure; PokeAccess::DBKMoveInfo.capture_off; end
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "dbk_moveinfo_draw", :before) do |args, _r|
  PokeAccess::DBKMoveInfo.note_draw(args[1])
end

# Closing the panel lets its dedup slot go, so reopening it on the same move next turn reads again.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbHideInfoUI, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_moveinfo)
  PokeAccess::BattleScene.panel_shut
end

# The move panel, queued after the fight menu's line with only what that line did not say (BattleScene.unheard);
# keyed on the stats too, as staging a mechanic repaints them under an unmoved cursor.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, _ret, args|
  battler = args[0]; cw = args[2]
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :move && battler && cw
    idx = (cw.index rescue nil)
    parts = idx.nil? ? nil : PokeAccess::DBKMoveInfo.parts(battler, idx, args[1], cw, scene)
    if parts && PokeAccess::Cursor.changed?(scene, :dbk_moveinfo, [(battler.index rescue 0), idx, parts])
      fresh = PokeAccess::BattleScene.unheard(battler, idx, parts)
      PokeAccess.speak(PokeAccess.clean(fresh.join(", ")), false) unless fresh.empty?
    end
  else
    PokeAccess::BattleScene.panel_shut
    PokeAccess::Cursor.reset(scene, :dbk_moveinfo)
  end
end

module PokeAccess
  # The Battler Info panel (Battle::Scene#pbUpdateBattlerInfo): left and right between battlers, up and down through
  # their effects ([name, tick, desc] from pbGetDisplayEffects); the summary and the focused effect as they change.
  module DBKBattlerInfo
    # The types the panel paints: a foe's disguise under Illusion, the pre-Tera ones once terastallized, else the
    # current ones.
    def self.display_types(battler)
      poke = ((battler.opposes? rescue false) ? (battler.displayPokemon rescue nil) : (battler.pokemon rescue nil))
      illusion = ((battler.effects[PBEffects::Illusion] rescue nil) && !(battler.pbOwnedByPlayer? rescue true))
      return ((poke.types.clone rescue nil) || []) if illusion && !(battler.tera? rescue false)
      return ((battler.pbPreTeraTypes rescue nil) || []) if (battler.tera? rescue false)
      (battler.pbTypes(true) rescue nil) || (battler.types rescue nil)
    rescue StandardError
      (battler.types rescue nil)
    end

    # The battler's types as the panel paints them, for both sides, or nil; "unknown" for a species the panel hides
    # (DBKMoveInfo.unknown_species?).
    def self.types(battler)
      return PokeAccess::I18n.t(:pdx_unknown_value) if (PokeAccess::DBKMoveInfo.unknown_species?(battler) rescue false)
      list = display_types(battler)
      names = ([list].flatten.compact.uniq.map { |ty| (PokeAccess::Data.type_name(ty) rescue nil) })
      names = names.compact.reject { |s| s.to_s.empty? }
      names.empty? ? nil : PokeAccess::I18n.t(:mv_type, :t => names.join("/"))
    rescue StandardError
      nil
    end

    # The summary line for a battler, or nil, withholding what the panel does: ability, item and numeric HP only for
    # the player's own (a foe's HP as Battle.hp_phrase), an unknown level for a raid boss, and the stat stages.
    def self.summary(battler)
      owned = (battler.pbOwnedByPlayer? rescue true)
      parts = identity_parts(battler) + condition_parts(battler, owned) + detail_parts(battler, owned)
      r = parts.reject { |x| x.to_s.empty? }
      r.empty? ? nil : r.join(", ")
    rescue StandardError
      nil
    end

    # Who the battler is: name, sex, shiny, its trainer and the turn count. Name, sex and shiny mark are those of
    # the Pokemon the panel draws (an Illusion shows the one it imitates), with no sex on a raid boss.
    def self.identity_parts(battler)
      shown = shown_pokemon(battler)
      parts = [PokeAccess.clean(((shown.name rescue nil) || (battler.name rescue "")).to_s)]
      gw = (battler.isRaidBoss? rescue false) ? nil : (PokeAccess::Party.gender_glyph(shown) rescue nil)
      parts.push(gw) if gw
      parts.push(shiny_word(shown)) if (PokeAccess::Party.shiny?(shown) rescue false)
      unless (battler.wild? rescue true)
        ow = (battler.battle.pbGetOwnerName(battler.index) rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_trainer, :name => ow)) if ow && !ow.to_s.empty?
      end
      tn = (battler.battle.turnCount rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_turn, :n => tn.to_i + 1)) if tn
      parts
    end

    # The word for the shiny star the panel draws: one star for every shiny in the plugin; a copy that draws another
    # for a super shiny overrides this in its profile (royal).
    def self.shiny_word(_pk)
      PokeAccess::I18n.t(:dbk_shiny)
    end

    # The Pokemon the panel draws for a battler: a foe's displayed one, the player's own one.
    def self.shown_pokemon(battler)
      (battler.opposes? rescue false) ? (battler.displayPokemon rescue battler) : (battler.pokemon rescue battler)
    end

    # The level the panel paints: :unknown (a placeholder) on a raid boss, else the battler's, or nil; a profile whose
    # copy hides it elsewhere overrides this (royal).
    def self.panel_level(battler)
      (battler.isRaidBoss? rescue false) ? :unknown : (battler.level rescue nil)
    end

    # How the battler stands: level, HP as the panel shows it, types and status.
    def self.condition_parts(battler, owned)
      parts = []
      lvl = panel_level(battler)
      if lvl == :unknown
        parts.push(PokeAccess::I18n.t(:dbk_level_unknown))
      elsif lvl
        parts.push(PokeAccess::I18n.t(:dbk_level, :n => lvl))
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
      parts
    end

    # What the panel adds for the player's own battlers (ability, item), then the last move used and the
    # stat stages.
    def self.detail_parts(battler, owned)
      parts = []
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
      parts.push(st.to_s.sub(/\A[.,]\s*/, "")) unless st.to_s.empty?
      parts
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

# Opening the panel forgets its dedup keys, which live on the battle-long Battle::Scene, so reopening reads again.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbOpenBattlerInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_binfo_b)
  PokeAccess::Cursor.reset(scene, :dbk_binfo_e)
end

# Two slots: the battler (its summary, interrupting) and the [battler, effect] pair (the effect line,
# queued behind a fresh summary, interrupting when only the effect moved).
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, _ret, args|
  battler = args[0]; effects = args[1]; idx_effect = args[2] || 0
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :battler && battler
    bidx = (battler.index rescue nil)
    new_battler = PokeAccess::Cursor.changed?(scene, :dbk_binfo_b, bidx)
    new_effect = PokeAccess::Cursor.changed?(scene, :dbk_binfo_e, [bidx, idx_effect])
    if new_battler || new_effect
      eff = PokeAccess::DBKBattlerInfo.effect_text(effects, idx_effect)
      if new_battler
        sm = PokeAccess::DBKBattlerInfo.summary(battler)
        PokeAccess.speak(sm, true)
        PokeAccess.speak(eff, false)
      elsif eff && !eff.to_s.empty?
        PokeAccess.speak(eff, true)
      end
    end
  else
    PokeAccess::Cursor.reset(scene, :dbk_binfo_b)
    PokeAccess::Cursor.reset(scene, :dbk_binfo_e)
  end
end

module PokeAccess
  # The in-battle selectors, sprite cursors with no command window: the Poke Ball picker and the battler-selection
  # grid, read as the cursor moves (the panel a battler opens is DBKBattlerInfo).
  module DBKSelectors
    # The focused ball line ("name, count") from the [item_id, count] entry, or the Back label.
    # param show_desc true while the panel shows the ball's description (the details key), which is then added
    def self.ball_text(items, index, show_desc = false)
      e = (items[index] rescue nil)
      return nil unless e
      id = e.is_a?(Array) ? e[0] : e
      item = (GameData::Item.try_get(id) rescue nil)
      return PokeAccess::I18n.t(:dbk_back) unless item
      n = e.is_a?(Array) ? e[1] : nil
      line = n ? PokeAccess::I18n.t(:dbk_ball, :name => item.name, :n => n) : item.name.to_s
      return line unless show_desc
      d = (item.description rescue nil)
      (d && !d.to_s.empty?) ? "#{line}. #{PokeAccess.clean(d.to_s)}" : line
    rescue StandardError
      nil
    end

    # The focused battler line ("name sign, owner's") of the selection grid, laid out as the plugin does: own side,
    # then the other reversed. The sex sign is drawn on every slot but a raid boss's.
    def self.battler_text(scene, idxSide, idxPoke)
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless battle
      sides = [(battle.allSameSideBattlers rescue []),
               (battle.allOtherSideBattlers.reverse rescue [])]
      b = (sides[idxSide][idxPoke] rescue nil)
      return nil unless b
      pk = PokeAccess::Battle.grid_pokemon(b, idxSide == 0)
      nm = (pk.name rescue (b.name rescue nil))
      return nil unless nm && !nm.to_s.empty?
      sign = (idxSide == 0 || !(b.isRaidBoss? rescue false)) ? PokeAccess::Party.gender_glyph(pk) : nil
      nm = "#{nm} #{sign}" if sign
      owner = (battle.pbGetOwnerFromBattlerIndex(b.index).name rescue nil)
      (owner && !owner.to_s.empty?) ? PokeAccess::I18n.t(:dbk_owner, :name => nm, :owner => owner) : nm.to_s
    rescue StandardError
      nil
    end
  end
end

# Poke Ball selector: pbUpdateBallSelection(items, index, showDesc) redraws on each move, read deduped by [index,
# showDesc] (the details key toggles the description in place) and reset when the selector opens.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_ball)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _ret, args|
  PokeAccess::Cursor.announce(scene, :dbk_ball, [args[1], args[2]]) do
    PokeAccess::DBKSelectors.ball_text(args[0], args[1], args[2])
  end
end

# Battler selection grid: pbUpdateBattlerSelection(idxSide, idxPoke, select), read deduped by [side, poke] and reset
# on opening. A before hook: with select the method runs the panel's modal loop, whose readers must not be guarded.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_bsel)
end
PokeAccess::Hooks.before_hook("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
  PokeAccess::Cursor.announce(scene, :dbk_bsel, [args[0], args[1]]) do
    PokeAccess::DBKSelectors.battler_text(scene, args[0], args[1])
  end
end
