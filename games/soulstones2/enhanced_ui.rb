# Enhanced UI 1.1.2, EDITED by this game, so its reader lives in the profile: plugins/dbk_enhanced_ui.rb
# covers the current release and would bind to the same method names with other arities:
#   pbUpdateMoveInfoWindow(battler, index)       against (battler, specialAction, cw)
#   pbUpdateBattlerInfo(battler)                 against (battler, effects, idxEffect = 0)
#   pbUpdateBattlerSelection([side, i], select)  against (idxSide, idxPoke, select)
# The copies that RUN are the game's own overrides, loaded after the [Edited] folder: the Plugin Overrides
# paint the effectiveness strip and the Boss Battles plugin the battler panel. The effectiveness verdict is
# taken from the icons the game chose (the frame index pbDrawTypeEffectiveness returns), since this copy
# decides it with custom types and abilities of its own.
module PokeAccess
  module SS2EnhancedUI
    # The seven states of this game's effectiveness strip, in the frame order it draws them: the two past
    # the vanilla five are four times and a quarter.
    EFFECT_KEYS = [:mv_eff_unknown, :mv_eff_none, :mv_eff_weak, :mv_eff_super, :mv_eff_neutral,
                   :mv_eff_hyper, :mv_eff_barely]
    # Move category ids to their spoken names; 2 is status, which has no power and no effectiveness.
    CATS = [:cat_physical, :cat_special, :cat_status]
    STATUS_CAT = 2
    # Each icon row is [file, x, y, frame * WIDTH, 0, WIDTH, height], so the frame index is row[3] / WIDTH.
    EFFECT_ICON_WIDTH = 64

    # Remembers the effectiveness strip of the draw in progress, as one state index per foe, left to right.
    def self.note_effect_icons(rows)
      @icons = (rows || []).map { |r| (r[3].to_i / EFFECT_ICON_WIDTH) rescue nil }.compact
    rescue StandardError
      @icons = []
    end

    def self.forget_effect_icons; @icons = nil; end

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

    # The move panel as one line: name, type and category from the move (icons on screen), the three figures
    # exactly as PAINTED -- the last three rows of the batch: power, accuracy, effect chance, where the power
    # is this copy's whole damage calculation -- the effectiveness strip and the description underneath.
    def self.move_text(scene, battler, index)
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
      parts.push(PokeAccess::I18n.t(:mv_category, :c => PokeAccess::I18n.t(CATS[cat]))) if cat && CATS[cat]
      parts.push(PokeAccess::I18n.t(:mv_power, :p => power_word(figures[0]))) unless cat == STATUS_CAT
      parts.push(PokeAccess::I18n.t(:mv_acc, :a => acc_word(figures[1])))
      parts.push(PokeAccess::I18n.t(:mv_effect, :n => figures[2])) unless figures[2].to_s == "---"
      eff = effect_text(scene)
      parts.push(eff) if eff
      d = PokeAccess::PaintCapture.text(desc)
      parts.push(d) unless d.to_s.strip.empty?
      parts.empty? ? nil : parts.join(", ")
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

    # The battler panel as one line, saying what the panel paints and withholding what it withholds. The
    # ability, the held item and the numeric hp are the player's own battlers' alone; a foe's panel shows
    # its ability once the game has REVEALED it ($RevealedAbility, this game's own bookkeeping), a raid
    # boss shows its shields instead, and a foe's hp comes out as the percentage the rest of the mod uses
    # for a bar. The trainer, the turn, the shiny mark and the types are painted for everyone.
    def self.battler_text(battler)
      parts = []
      owned = (battler.pbOwnedByPlayer? rescue true)
      parts.push(PokeAccess.clean((battler.name rescue "")))
      gw = (PokeAccess::Party.gender_word(battler) rescue nil)
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
      ch = (PokeAccess::Battle.stat_changes(battler) rescue "")
      parts.push(ch.to_s.sub(/\A,\s*/, "")) unless ch.to_s.empty?
      r = parts.reject { |x| x.to_s.empty? }
      r.empty? ? nil : r.join(", ")
    rescue StandardError
      nil
    end

    # Whether the game has revealed a foe's ability, in its own record: $RevealedAbility[index][0] holds a
    # {:pkmn, :abil} pair once it has, and the pair of nils until then.
    def self.revealed_ability?(battler)
      rec = ($RevealedAbility[battler.index] rescue nil)
      rec.is_a?(Hash) && rec[0].is_a?(Hash) && rec[0] != { :pkmn => nil, :abil => nil }
    rescue StandardError
      false
    end

    # The battler's types as the panel paints them, or nil.
    def self.types(battler)
      list = ((battler.pbTypes(true) rescue nil) || (battler.types rescue nil))
      names = [list].flatten.compact.uniq.map { |ty| (PokeAccess::Data.type_name(ty) rescue nil) }
      names = names.compact.reject { |s| s.to_s.empty? }
      names.empty? ? nil : PokeAccess::I18n.t(:mv_type, :t => names.join("/"))
    rescue StandardError
      nil
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
      pk = (b.displayPokemon rescue (b.pokemon rescue nil))
      nm = (pk.name rescue (b.name rescue nil))
      return nil if nm.nil? || nm.to_s.empty?
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

  # AROUND rather than after: the panel's own draw call has to happen with the capture armed, and an
  # after-hook would put it under the reentrancy guard and swallow the pbDrawTypeEffectiveness hook above.
  # Queued, because the same keypress moves the fight menu, which has already said the move's name and PP.
  around("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, nxt, args|
    PokeAccess::SS2EnhancedUI.forget_effect_icons
    PokeAccess::PaintCapture.arm(:ss2_moveinfo)
    begin
      nxt.call
    ensure
      if PokeAccess.ivar(scene, :@moveUIToggle)
        t = PokeAccess::SS2EnhancedUI.move_text(scene, args[0], args[1])
        # Deduped on the LINE, not on the cursor: this panel also repaints without the cursor moving --
        # staging a mechanic rewrites the power it shows -- and a key made of [battler, move] would have
        # gone quiet on exactly the change worth hearing.
        PokeAccess.speak(t, false) if t && !t.to_s.empty? &&
                                      PokeAccess::Cursor.changed?(scene, :ss2_move, t.to_s)
      else
        PokeAccess::PaintCapture.take(:ss2_moveinfo)
        PokeAccess::Cursor.reset(scene, :ss2_move)
      end
    end
  end

  # The detail panel, redrawn as the player walks the grid. Interrupting: it answers the keypress that just
  # moved the cursor.
  after("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, _r, args|
    if PokeAccess.ivar(scene, :@infoUIToggle) && args[0]
      PokeAccess::Cursor.announce(scene, :ss2_binfo, (args[0].index rescue nil), true) do
        PokeAccess::SS2EnhancedUI.battler_text(args[0])
      end
    else
      PokeAccess::Cursor.reset(scene, :ss2_binfo)
    end
  end

  # The grid itself. BEFORE, because with select true this method ends by running the panel's whole modal
  # loop, and an after-hook would not speak until the player had closed it again.
  before("Battle::Scene", :pbToggleBattleInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_bsel)
    PokeAccess::Cursor.reset(scene, :ss2_binfo)
  end

  before("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
    PokeAccess::Cursor.reset(scene, :ss2_bsel)
  end

  before("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
    PokeAccess::Cursor.announce(scene, :ss2_bsel, args[0], true) do
      PokeAccess::SS2EnhancedUI.selected_text(scene, args[0])
    end
  end
end
