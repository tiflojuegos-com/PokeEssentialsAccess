# Enhanced UI 1.1.2 as Soulstones 2 edits it, read here because plugins/dbk_enhanced_ui.rb (the current release)
# has the same method names with other arities:
#   pbUpdateMoveInfoWindow(battler, index)       against (battler, specialAction, cw)
#   pbUpdateBattlerInfo(battler)                 against (battler, effects, idxEffect = 0)
#   pbUpdateBattlerSelection([side, i], select)  against (idxSide, idxPoke, select)
# The effectiveness verdict comes from the icons the game drew, as this copy uses custom types and abilities.
module PokeAccess
  module SS2EnhancedUI
    # The seven states of this game's effectiveness strip, in the frame order it draws them: the two past
    # the vanilla five are four times and a quarter.
    EFFECT_KEYS = [:mv_eff_unknown, :mv_eff_none, :mv_eff_weak, :mv_eff_super, :mv_eff_neutral,
                   :mv_eff_hyper, :mv_eff_barely]
    # The status category's id, which has no power and no effectiveness.
    STATUS_CAT = 2
    # Each icon row is [file, x, y, frame * WIDTH, 0, WIDTH, height], so the frame index is row[3] / WIDTH.
    EFFECT_ICON_WIDTH = 64
    # The move flag icons (pbDrawMoveFlagIcons), 26 wide, by frame: from 2, not blocked by protection, not copied by
    # Mirror Move, then the move's flags. Frames 0 and 1 (Z and Max moves) need ZUD Mechanics, which this game lacks.
    FLAG_ICON_WIDTH = 26
    FLAG_KEYS = [nil, nil, :dbk_flag_noprotect, :dbk_flag_nomirror, :dbk_flag_contact, :dbk_flag_minimize,
                 :dbk_flag_highcrit, :dbk_flag_thaw, :dbk_flag_sound, :dbk_flag_punch, :dbk_flag_bite, :dbk_flag_bomb,
                 :dbk_flag_pulse, :dbk_flag_powder, :dbk_flag_dance, :dbk_flag_slice, :dbk_flag_wind]
    # The flags whose words name a move, said as the game names it.
    FLAG_MOVES = { :dbk_flag_noprotect => :PROTECT, :dbk_flag_nomirror => :MIRRORMOVE, :dbk_flag_minimize => :MINIMIZE }

    # Remembers the effectiveness strip of the draw in progress, as one state index per foe, left to right.
    def self.note_effect_icons(rows)
      @icons = (rows || []).map { |r| (r[3].to_i / EFFECT_ICON_WIDTH) rescue nil }.compact
    rescue StandardError
      @icons = []
    end

    def self.forget_effect_icons
      @icons = nil
      @flags = nil
    end

    # Remembers the flag icons of the draw in progress, as frame indexes in the order they are painted.
    def self.note_flag_icons(rows)
      @flags = (rows || []).map { |r| (r[3].to_i / FLAG_ICON_WIDTH) rescue nil }.compact
    rescue StandardError
      @flags = []
    end

    # The flag icons of the move panel as words, or nil when it drew none.
    def self.flags_text
      words = (@flags || []).map do |f|
        key = FLAG_KEYS[f]
        next nil unless key
        mv = FLAG_MOVES[key]
        mv ? PokeAccess::I18n.t(key, :move => PokeAccess::Data.move_name(mv)) : PokeAccess::I18n.t(key)
      end
      words = words.compact
      words.empty? ? nil : PokeAccess::I18n.t(:dbk_flags, :list => words.join(", "))
    end

    # Remembers the effects list of the battler panel draw in progress, from the text rows
    # pbAddEffectsDisplay returns: a name row and a count row per effect, in the order it paints them.
    def self.note_effects(rows)
      texts = (rows || []).map { |r| r[0].to_s }
      @effects = texts.each_slice(2).to_a
    rescue StandardError
      @effects = []
    end

    # The effects in play as the panel lists them, each with its turn count as painted ("3/5"); the "---"
    # of an effect with no count to show, and the empty count of a hazard, are left out. nil when none.
    def self.effects_text
      list = (@effects || []).map do |name, count|
        c = count.to_s.strip
        (c.empty? || c == "---") ? name.to_s : "#{name} #{c}"
      end
      list = list.map { |x| PokeAccess.clean(x) }.reject { |x| x.empty? }
      list.empty? ? nil : PokeAccess::I18n.t(:ss2_effects, :list => list.join(", "))
    end

    # How the focused move lands on each foe, worded from those icons and named by the foe when there is
    # more than one. nil when the strip was not drawn (a status move, or every foe fainted).
    def self.effect_text(scene)
      idx = @icons
      return nil if idx.nil? || idx.empty?
      battle = PokeAccess.ivar(scene, :@battle)
      foes = ((battle.allBattlers rescue []).select { |b| b && !(b.index rescue 0).even? && !(b.fainted? rescue true) })
      words = idx.map { |i| PokeAccess::I18n.t(EFFECT_KEYS[i] || EFFECT_KEYS[0]) }
      return words[0] if words.length == 1
      out = []
      words.each_with_index do |w, i|
        nm = PokeAccess.clean((foes[i].name rescue ""))
        out.push(nm.empty? ? w : PokeAccess::I18n.t(:mv_eff_vs, :name => nm, :eff => w))
      end
      out.join(", ")
    rescue StandardError
      nil
    end

    # The move panel as phrases: name, type and category from the move, the power, accuracy and effect chance as
    # painted (the batch's last three rows), the flag icons, the effectiveness strip and the description.
    def self.move_parts(scene, battler, index)
      painted = PokeAccess::PaintCapture.take_by_source(:ss2_moveinfo)
      rows = painted[:positions] || []
      desc = painted[:dtex]
      return nil if rows.length < 3
      figures = rows[-3, 3]
      parts = []
      move = (battler.moves[index] rescue nil)
      nm = PokeAccess.clean((move.name rescue rows[0]))
      parts.push(nm) unless nm.empty?
      t = ((move.pbCalcType(battler) rescue nil) || (move.type rescue nil)) if move
      tn = t ? (PokeAccess::Data.type_name(t) rescue nil) : nil
      parts.push(PokeAccess::I18n.t(:mv_type, :t => tn)) if tn && !tn.to_s.empty?
      cat = (move.category rescue nil)
      word = PokeAccess::MoveInfo.category_word(cat)
      parts.push(word) if word
      parts.push(PokeAccess::I18n.t(:mv_power, :p => power_word(figures[0]))) unless cat == STATUS_CAT
      parts.push(PokeAccess::I18n.t(:mv_acc, :a => acc_word(figures[1])))
      parts.push(PokeAccess::I18n.t(:mv_effect, :n => figures[2])) unless figures[2].to_s == "---"
      flags = flags_text
      parts.push(flags) if flags
      eff = effect_text(scene)
      parts.push(eff) if eff
      d = PokeAccess::PaintCapture.text(desc)
      parts.push(d) unless d.to_s.strip.empty?
      parts.empty? ? nil : parts
    rescue StandardError
      nil
    end

    # "---" on power means the move does no damage and "???" that its power is variable, which is what the
    # panel puts there in place of a number.
    def self.power_word(s)
      return PokeAccess::I18n.t(:mv_power_none) if s.to_s == "---"
      return PokeAccess::I18n.t(:mv_power_var) if s.to_s == "???"
      s.to_s
    end

    # "---" on accuracy means the move never misses.
    def self.acc_word(s)
      s.to_s == "---" ? PokeAccess::I18n.t(:mv_acc_perfect) : s.to_s
    end

    # The battler panel as one line, only what it paints: ability, item and exact hp for the player's own; for a
    # foe an hp share, the ability once revealed or a boss's shields, and the sex of its displayed Pokemon.
    def self.battler_text(battler)
      parts = []
      owned = (battler.pbOwnedByPlayer? rescue true)
      shown = (battler.opposes? rescue false) ? (battler.displayPokemon rescue battler) : (battler.pokemon rescue battler)
      parts.push(PokeAccess.clean(((shown.name rescue nil) || (battler.name rescue "")).to_s))
      gw = (PokeAccess::Party.gender_glyph(shown) rescue nil)
      parts.push(gw) if gw
      parts.push(PokeAccess::I18n.t(:dbk_shiny)) if (battler.shiny? rescue false)
      unless (battler.wild? rescue true)
        ow = (battler.battle.pbGetOwnerFromBattlerIndex(battler.index).name rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_trainer, :name => ow)) if ow && !ow.to_s.empty?
      end
      tn = (battler.battle.turnCount rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_turn, :n => tn.to_i + 1)) if tn
      lvl = (battler.level rescue nil)
      parts.push(PokeAccess::I18n.t(:dbk_level, :n => lvl)) if lvl
      hp = (battler.hp rescue nil)
      thp = (battler.totalhp rescue nil)
      if hp && thp
        parts.push(owned ? PokeAccess::I18n.t(:dbk_hp, :hp => hp, :tot => thp) :
                   PokeAccess::Battle.hp_phrase(hp, thp, true))
      end
      st = (battler.status rescue nil)
      if st && st != :NONE
        sn = (GameData::Status.get(st).name rescue nil)
        parts.push(sn) if sn
      end
      ty = types(battler)
      parts.push(ty) if ty
      if owned
        ab = (battler.abilityName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_ability, :a => ab)) if ab && !ab.to_s.empty?
        it = (battler.itemName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_item, :i => it)) if it && !it.to_s.empty?
      elsif revealed_ability?(battler)
        ab = (battler.abilityName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_ability, :a => ab)) if ab && !ab.to_s.empty?
      elsif (battler.isbossmon rescue false)
        parts.push(PokeAccess::I18n.t(:ss2_shields, :n => (battler.shieldCount rescue 0).to_i))
      end
      last = (battler.lastMoveUsed rescue nil)
      if last
        mv = (GameData::Move.get(last).name rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_lastmove, :m => mv)) if mv
      end
      ch = changes_text(battler)
      parts.push(ch) if ch
      r = parts.reject { |x| x.to_s.empty? }
      r.empty? ? nil : r.join(", ")
    rescue StandardError
      nil
    end

    # The rows of the panel that draw arrows, in the changes wording: the stat stages, then the Crit. Hit row.
    # nil when no row has an arrow.
    def self.changes_text(battler)
      ch = (PokeAccess::Battle.stat_changes(battler) rescue "").to_s.sub(/\A[.,]\s*/, "")
      crit = crit_stage(battler)
      return (ch.empty? ? nil : ch) if crit <= 0
      part = "#{PokeAccess::I18n.t(:dbk_crit)} +#{crit}"
      ch.empty? ? PokeAccess::I18n.t(:bt_changes, :list => part).sub(/\A[.,]\s*/, "") : "#{ch}, #{part}"
    end

    # The Crit. Hit row's arrows (pbAddStatsDisplay): Focus Energy plus the critical boost, four at most.
    def self.crit_stage(battler)
      fx = battler.effects
      n = (fx[PBEffects::FocusEnergy] rescue 0).to_i + (fx[PBEffects::CriticalBoost] rescue 0).to_i
      n > 4 ? 4 : n
    rescue StandardError
      0
    end

    # Whether the game has revealed a foe's ability, in its own record: $RevealedAbility[index][0] holds a
    # {:pkmn, :abil} pair once it has, and the pair of nils until then.
    def self.revealed_ability?(battler)
      rec = ($RevealedAbility[battler.index] rescue nil)
      rec.is_a?(Hash) && rec[0].is_a?(Hash) && rec[0] != { :pkmn => nil, :abil => nil }
    rescue StandardError
      false
    end

    # The types the panel draws (pbAddTypesDisplay): with Illusion on a foe, the disguise's plus any added third
    # type; terastallized, the original ones; "???" for a species never met or a celestial battler.
    def self.painted_types(battler)
      poke = ((battler.opposes? rescue false) ? (battler.displayPokemon rescue nil) : (battler.pokemon rescue nil))
      illusion = ((battler.effects[PBEffects::Illusion] rescue nil) && !(battler.pbOwnedByPlayer? rescue true)) ? true : false
      return [:QMARKS] if unknown_species?(battler, poke)
      if (battler.tera? rescue false)
        return ((illusion ? (poke.types rescue nil) : (battler.pokemon.types rescue nil)) || [])
      end
      return (battler.pbTypes(true) rescue nil) unless illusion
      list = ((poke.types rescue nil) || []).dup
      t3 = (battler.effects[PBEffects::Type3] rescue nil)
      list.push(t3) if t3
      list
    rescue StandardError
      (battler.types rescue nil)
    end

    # Whether the panel draws "???" instead of a typing: a species the player has neither owned nor battled
    # (unless the game is set to always show types), and any celestial battler.
    def self.unknown_species?(battler, poke)
      return true if (battler.celestial? rescue false)
      return false if (Settings::ALWAYS_DISPLAY_TYPES rescue false)
      return false if (battler.pbOwnedByPlayer? rescue true)
      sp = (poke.species rescue nil)
      return false if sp.nil?
      return false if ($player.pokedex.owned?(sp) rescue false)
      (($player.pokedex.battled_count(sp) rescue 0)).to_i <= 0
    rescue StandardError
      false
    end

    # The battler's types as the panel paints them, or nil. The "???" type is said as the word it means: a
    # screen reader drops a run of question marks.
    def self.types(battler)
      list = painted_types(battler)
      list = ((battler.pbTypes(true) rescue nil) || (battler.types rescue nil)) if list.nil?
      names = [list].flatten.compact.uniq.map { |ty| ty == :QMARKS ? PokeAccess::I18n.t(:pdx_unknown_short) : (PokeAccess::Data.type_name(ty) rescue nil) }
      names = names.compact.reject { |s| s.to_s.empty? }
      names.empty? ? nil : PokeAccess::I18n.t(:mv_type, :t => names.join("/"))
    rescue StandardError
      nil
    end

    # The ball lineups the selection grid draws, the foes' first as they sit on top: one per trainer with a Pokemon
    # still able to fight. nil when it draws none.
    def self.lineups_text(scene)
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless battle
      trainers = ((battle.opponent rescue nil) || []) + ((battle.player rescue nil) || [])
      lines = trainers.map { |tr| lineup(tr) }.compact
      lines.empty? ? nil : lines.join(". ")
    end

    # One trainer's lineup, counted as its NUM_BALLS balls show them: healthy, with a status condition, fainted; an
    # empty slot shows an empty ball and is not counted.
    def self.lineup(tr)
      return nil unless (tr.able_pokemon_count rescue 0).to_i > 0
      party = (tr.party rescue nil) || []
      counts = [0, 0, 0]
      (PokeAccess.const_at("Battle::Scene::NUM_BALLS") || 6).times do |i|
        pk = party[i]
        next unless pk
        if !(pk.able? rescue false)
          counts[2] += 1
        elsif (pk.status rescue :NONE) != :NONE
          counts[1] += 1
        else
          counts[0] += 1
        end
      end
      parts = []
      parts.push(PokeAccess::I18n.t(:dbk_lineup_ok, :n => counts[0])) if counts[0] > 0
      parts.push(PokeAccess::I18n.t(:dbk_lineup_status, :n => counts[1])) if counts[1] > 0
      parts.push(PokeAccess::I18n.t(:dbk_lineup_fainted, :n => counts[2])) if counts[2] > 0
      name = PokeAccess.clean((tr.name rescue "").to_s)
      name.empty? ? parts.join(", ") : PokeAccess::I18n.t(:dbk_lineup, :name => name, :list => parts.join(", "))
    end

    # The battler the selection grid is on, from the [side, i] pair the panel highlights. The grid is laid
    # out as the panel lays it out: own side in order, the other side reversed.
    def self.selected_text(scene, index)
      return nil unless index.is_a?(Array)
      battle = PokeAccess.ivar(scene, :@battle)
      return nil unless battle
      sides = [(battle.allSameSideBattlers rescue []), (battle.allOtherSideBattlers.reverse rescue [])]
      b = (sides[index[0]][index[1]] rescue nil)
      return nil unless b
      pk = PokeAccess::Battle.grid_pokemon(b, index[0] == 0)
      nm = (pk.name rescue (b.name rescue nil))
      return nil if nm.nil? || nm.to_s.empty?
      sign = PokeAccess::Party.gender_glyph(pk)
      nm = "#{nm} #{sign}" if sign
      owner = (battle.pbGetOwnerFromBattlerIndex(b.index).name rescue nil)
      (owner && !owner.to_s.empty?) ? PokeAccess::I18n.t(:dbk_owner, :name => nm, :owner => owner) : nm.to_s
    rescue StandardError
      nil
    end
  end
end

PokeAccess::Game.define("soulstones2") do
  # The strip is drawn from inside the move panel, so its rows are noted on the way past.
  after("Battle::Scene", :pbDrawTypeEffectiveness, :optional => true) do |_s, ret, _a|
    PokeAccess::SS2EnhancedUI.note_effect_icons(ret)
  end

  # So are the flag icons, returned as image rows the panel draws with the rest.
  after("Battle::Scene", :pbDrawMoveFlagIcons, :optional => true) do |_s, ret, _a|
    PokeAccess::SS2EnhancedUI.note_flag_icons(ret)
  end

  # The move panel, around so its draw runs with the capture armed and the effectiveness hook above unguarded;
  # queued, adding only what the fight menu has not said (BattleScene.unheard); deduped by line, not cursor, since
  # staging a mechanic repaints the power without a cursor move.
  around("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, nxt, args|
    PokeAccess::SS2EnhancedUI.forget_effect_icons
    PokeAccess::PaintCapture.arm(:ss2_moveinfo)
    begin
      nxt.call
    ensure
      if PokeAccess.ivar(scene, :@moveUIToggle)
        parts = PokeAccess::SS2EnhancedUI.move_parts(scene, args[0], args[1])
        if parts && PokeAccess::Cursor.changed?(scene, :ss2_move, parts)
          fresh = PokeAccess::BattleScene.unheard(args[0], args[1], parts)
          PokeAccess.speak(PokeAccess.clean(fresh.join(", ")), false) unless fresh.empty?
        end
      else
        PokeAccess::PaintCapture.take(:ss2_moveinfo)
        PokeAccess::BattleScene.panel_shut
        PokeAccess::Cursor.reset(scene, :ss2_move)
      end
    end
  end

  # Hiding the panel lets its slot go, so reopening it on the same move is read.
  before("Battle::Scene", :pbHideMoveInfo, :optional => true) do |scene, _a|
    PokeAccess::BattleScene.panel_shut
    PokeAccess::Cursor.reset(scene, :ss2_move)
  end

  # The effects list is drawn from inside the battler panel, so its rows are noted on the way past.
  after("Battle::Scene", :pbAddEffectsDisplay, :optional => true) do |_s, ret, _a|
    PokeAccess::SS2EnhancedUI.note_effects((ret[1] rescue nil))
  end

  # The battler detail panel as the grid is walked, interrupting; around, like the move panel, so the effects
  # hook above is not guarded out.
  around("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, nxt, args|
    PokeAccess::SS2EnhancedUI.note_effects(nil)
    r = nxt.call
    if PokeAccess.ivar(scene, :@infoUIToggle) && args[0]
      PokeAccess::Cursor.announce(scene, :ss2_binfo, (args[0].index rescue nil), true) do
        ui = PokeAccess::SS2EnhancedUI
        [ui.battler_text(args[0]), ui.effects_text].compact.join(", ")
      end
    else
      PokeAccess::Cursor.reset(scene, :ss2_binfo)
    end
    r
  end

  # The grid; before, since with select true this method ends in the panel's whole modal loop.
  before("Battle::Scene", :pbToggleBattleInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_bsel)
    PokeAccess::Cursor.reset(scene, :ss2_binfo)
  end

  before("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_bsel)
  end

  # With select (the grid opening) the ball lineups follow the battler, queued: they stay as they are while it runs.
  before("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
    PokeAccess::Cursor.announce(scene, :ss2_bsel, args[0], true) do
      PokeAccess::SS2EnhancedUI.selected_text(scene, args[0])
    end
    if args[1] && PokeAccess.ivar(scene, :@infoUIToggle)
      lineups = PokeAccess::SS2EnhancedUI.lineups_text(scene)
      PokeAccess.speak(lineups, false) if lineups
    end
  end
end
