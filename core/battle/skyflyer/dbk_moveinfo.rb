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

PokeAccess::Hooks.after_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, _ret, args|
  battler = args[0]; cw = args[2]
  if PokeAccess.ivar(scene, :@enhancedUIToggle) == :move && battler && cw
    idx = (cw.index rescue nil)
    key = idx.nil? ? nil : "mi#{(battler.index rescue 0)}_#{idx}"
    # Queued: the same keypress moves the fight menu, which already speaks name, type, power, accuracy and
    # PP, and this panel refreshes one call later. Interrupting would truncate the line it extends.
    PokeAccess::Cursor.announce(scene, :dbk_moveinfo, key, false) do
      PokeAccess::DBKMoveInfo.text(battler, idx, args[1], cw, scene)
    end
  else
    PokeAccess::Cursor.reset(scene, :dbk_moveinfo)
  end
end
