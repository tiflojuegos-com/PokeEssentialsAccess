# [DBK] Enhanced Battle UI, the battle panels La Base de Sky bundles (anil, emerald, relict, royal): the
# move-info window, the battler-info panel and the ball/battler selectors. One file because they are ONE
# third-party plugin and share DBKMoveInfo; the Deluxe Battle Kit's own mechanic toggles are dbk_battle.

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
      figures(move).each { |f| parts.push(f) }
      eff = effectiveness(scene, move, t)
      parts.push(eff) if eff
      parts.empty? ? nil : parts.join(", ")
    rescue StandardError
      nil
    end

    # The four figures the panel writes -- power, accuracy, priority and added-effect chance -- as spoken
    # lines, from what it PAINTED and not from the move data.
    #
    # The panel runs the whole damage calculation (STAB, item, ability, terastal, the move's own function
    # code) through pbGetFinalModifiers, and that final number is the entire reason the panel exists: with
    # STAB a 90-power move is drawn as 135. Recomputing it would mean reimplementing the plugin.
    #
    # The panel's placeholders map onto words the reader already has: "---" on power is no damage, "???" is
    # a variable-power move, "---" on accuracy is never misses, and "---" on priority or on the effect
    # chance means there is none, which is the case both already omit.
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

    # Captures the panel's own draw call while it is painting.
    #
    # The four figures are found by ALIGNMENT: they are the only rows the panel centres, the labels beside
    # them being left-aligned. That holds in the four copies and, unlike matching the labels themselves,
    # does not break if a game translates "Pow" or shifts the columns (one of them does both).
    @painted = nil
    @armed = false

    def self.capture_on; @painted = nil; @armed = true; end
    def self.capture_off; @armed = false; end

    def self.note_draw(rows)
      return unless @armed && rows.is_a?(Array)
      vals = rows.select { |r| r.is_a?(Array) && r[3] == :center }.map { |r| r[0].to_s.strip }
      @painted = vals if vals.length == 4
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

# Around, so the panel's draw call happens with the capture armed. The reading still runs after, on the
# figures it just wrote.
PokeAccess::Hooks.around_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |_s, nxt, _a|
  PokeAccess::DBKMoveInfo.capture_on
  begin; nxt.call; ensure; PokeAccess::DBKMoveInfo.capture_off; end
end

PokeAccess::Hooks.wrap_kernel("pbDrawTextPositions", "dbk_moveinfo_draw", :before) do |args, _r|
  PokeAccess::DBKMoveInfo.note_draw(args[1])
end

# Queued rather than interrupting: the same keypress moves the fight menu, which already speaks name, type,
# power, accuracy and PP, and this panel refreshes one call later -- interrupting would cut the line it extends.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, _ret, args|
  battler = args[0]; cw = args[2]
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :move && battler && cw
    idx = (cw.index rescue nil)
    key = idx.nil? ? nil : "mi#{(battler.index rescue 0)}_#{idx}"
    PokeAccess::Cursor.announce(scene, :dbk_moveinfo, key, false) do
      PokeAccess::DBKMoveInfo.text(battler, idx, args[1], cw, scene)
    end
  else
    PokeAccess::Cursor.reset(scene, :dbk_moveinfo)
  end
end

module PokeAccess
  # DBK Enhanced Battle UI "Battler Info" overlay (Battle::Scene#pbUpdateBattlerInfo): a panel detailing a
  # battler, navigable left/right between battlers and up/down through its active effects. Read the battler
  # summary when the focused battler changes, and the focused effect when it changes (effects are
  # [name, tick, desc] triples from pbGetDisplayEffects). Gated by method existence so only DBK games bind.
  module DBKBattlerInfo
    # The types the panel PAINTS, which are not always the real ones. The panel settles three cases before
    # drawing: with Illusion active on a foe it shows the disguise's types, Terastallized it shows the ones
    # from BEFORE terastallizing, and only with neither the current ones. Reading the real ones revealed the
    # illusion -- the very fact the foe is hiding -- and contradicted the screen mid-battle.
    # param battler the focused battler
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
    # The stat block IS read: the panel draws one arrow per stage of raise or drop beside each stat, and it
    # is the half of the screen that says whether the battle is going wrong. It comes from
    # Battle.stat_changes, the same source as the HP key, so the two agree.
    def self.summary(battler)
      parts = []
      owned = (battler.pbOwnedByPlayer? rescue true)
      parts.push(PokeAccess.clean((battler.name rescue "")))
      gw = (PokeAccess::Party.gender_word(battler) rescue nil)
      parts.push(gw) if gw
      parts.push(PokeAccess::I18n.t(:dbk_shiny)) if (battler.shiny? rescue false)
      unless (battler.wild? rescue true)
        ow = (battler.battle.pbGetOwnerName(battler.index) rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_trainer, :name => ow)) if ow && !ow.to_s.empty?
      end
      tn = (battler.battle.turnCount rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_turn, :n => tn.to_i + 1)) if tn
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

# Opening the panel forgets the keys: the dedup hangs off Battle::Scene, which lives for the whole
# battle, so reopening on the same battler must re-read (the sibling selector resets :dbk_bsel likewise).
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
        PokeAccess.speak(sm, true) if sm && !sm.to_s.empty?
        PokeAccess.speak(eff, false) if eff && !eff.to_s.empty?
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
  # DBK Enhanced Battle UI in-battle SELECTORS (sprite cursors, no command window, so the generic hook
  # cannot see them). Two screens sit on the action path: the Poke Ball picker (which ball to throw) and the
  # battler-selection grid (which battler to inspect). The detail panel that opens AFTER picking a battler is
  # read by DBKBattlerInfo above; here we read the CURSOR as it moves. Gated by method existence so only DBK games
  # bind, and no-op on gen-6 (no Battle::Scene).
  module DBKSelectors
    # The focused ball line ("name, count") from the [item_id, count] entry, or the Back label.
    # param show_desc true while the panel is showing the ball's description, which is what the details key
    #   toggles: the screen paints a whole paragraph and the index does not move
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

    # The focused battler line ("name, owner's") for the selection grid, rebuilt the way the plugin lays the
    # grid out (own side, then the other side reversed), so idxSide/idxPoke map to the same battler.
    def self.battler_text(scene, idxSide, idxPoke)
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless battle
      sides = [(battle.allSameSideBattlers rescue []),
               (battle.allOtherSideBattlers.reverse rescue [])]
      b = (sides[idxSide][idxPoke] rescue nil)
      return nil unless b
      pk = (b.displayPokemon rescue (b.pokemon rescue nil))
      nm = (pk.name rescue (b.name rescue nil))
      return nil unless nm && !nm.to_s.empty?
      owner = (battle.pbGetOwnerFromBattlerIndex(b.index).name rescue nil)
      (owner && !owner.to_s.empty?) ? PokeAccess::I18n.t(:dbk_owner, :name => nm, :owner => owner) : nm.to_s
    rescue StandardError
      nil
    end
  end
end

# Poke Ball selector: pbUpdateBallSelection(items, index, showDesc) redraws on open and on each left/right
# move; read the focused ball. The dedup ivar lives on the battle-long Scene, so reset it when the selector
# (re)opens, or reopening on the same index would stay mute.
#
# The key is [index, showDesc], not the index alone: the details key toggles a full description panel open
# and shut WITHOUT moving the cursor, so an index-only key never noticed that the screen had changed.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBallInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_ball)
end
PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateBallSelection, :optional => true) do |scene, _ret, args|
  PokeAccess::Cursor.announce(scene, :dbk_ball, [args[1], args[2]]) do
    PokeAccess::DBKSelectors.ball_text(args[0], args[1], args[2])
  end
end

# Battler selection grid: pbUpdateBattlerSelection(idxSide, idxPoke, select) redraws on each cursor move;
# read the highlighted battler (deduped by the [side, poke] pair). Reset on (re)open like the ball selector.
#
# BEFORE and not after, because this method is not just a redraw: called with select true, which is how the
# key opens the panel, it ends in "pbSelectBattlerInfo if select" and that IS the panel's whole modal loop.
# Hooked after, the call that opens the grid would not speak until the player closed it.
#
# Running before also settles the reentrancy question rather than working around it: a before hook does not
# put the original under the guard at all, so pbUpdateBattlerInfo, the reset below and
# pbUpdateMoveInfoWindow are never suppressed. Nothing here reads the return value, so before costs nothing.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :dbk_bsel)
end
PokeAccess::Hooks.before_hook("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
  PokeAccess::Cursor.announce(scene, :dbk_bsel, [args[0], args[1]]) do
    PokeAccess::DBKSelectors.battler_text(scene, args[0], args[1])
  end
end
