# Enhanced UI 1.1.x by Lucidious89, for Essentials Deluxe (Keishou; Soulstones 2 ships it edited), an older release than
# plugins/dbk_enhanced_ui.rb's, with the same method names and other arities, so each serves only its own probe:
#   pbUpdateMoveInfoWindow(battler, index)       against (battler, specialAction, cw)
#   pbUpdateBattlerInfo(battler)                 against (battler, effects, idxEffect = 0)
#   pbUpdateBattlerSelection([side, i], select)  against (idxSide, idxPoke, select)
# The effectiveness verdict comes from the icons the game drew, as a copy may use custom types and abilities. Past the
# battle panels: the egg groups and the happiness meter on the summary, each where its setting turns it on.
module PokeAccess
  module EnhancedUIV1
    # The states of the effectiveness strip, in the frame order it draws them: the release draws the first five, and
    # Soulstones 2's edit the two past them, four times and a quarter.
    EFFECT_KEYS = [:mv_eff_unknown, :mv_eff_none, :mv_eff_weak, :mv_eff_super, :mv_eff_neutral,
                   :mv_eff_hyper, :mv_eff_barely]
    # The status category's id, which has no power and no effectiveness.
    STATUS_CAT = 2
    # The rows the panel always paints after those a plugin adds: the name, three labels and three figures.
    MOVE_ROWS = 7
    # Each icon row is [file, x, y, frame * WIDTH, 0, WIDTH, height], so the frame index is row[3] / WIDTH.
    EFFECT_ICON_WIDTH = 64
    # The move flag icons (pbDrawMoveFlagIcons), 26 wide, by frame: ZUD Mechanics' Z and Max moves, not blocked by
    # protection, not copied by Mirror Move, then the move's flags.
    FLAG_ICON_WIDTH = 26
    FLAG_KEYS = [:dbkf_zmove, :dbkf_dynamax, :dbk_flag_noprotect, :dbk_flag_nomirror, :dbk_flag_contact, :dbk_flag_minimize,
                 :dbk_flag_highcrit, :dbk_flag_thaw, :dbk_flag_sound, :dbk_flag_punch, :dbk_flag_bite, :dbk_flag_bomb,
                 :dbk_flag_pulse, :dbk_flag_powder, :dbk_flag_dance, :dbk_flag_slice, :dbk_flag_wind]
    # The flags whose words name a move, said as the game names it.
    FLAG_MOVES = { :dbk_flag_noprotect => :PROTECT, :dbk_flag_nomirror => :MIRRORMOVE, :dbk_flag_minimize => :MINIMIZE }

    # Remembers the effectiveness strip of the draw in progress, as one state index per foe, left to right.
    def self.note_effect_icons(rows)
      @icons = (rows || []).map { |r| (r[3].to_i / EFFECT_ICON_WIDTH) rescue nil }.compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
      @icons = []
    end

    def self.forget_effect_icons
      @icons = nil
      @flags = nil
    end

    # Remembers the flag icons of the draw in progress, as frame indexes in the order they are painted.
    def self.note_flag_icons(rows)
      @flags = (rows || []).map { |r| (r[3].to_i / FLAG_ICON_WIDTH) rescue nil }.compact
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The move panel as phrases: name, type and category from the move, the power, accuracy and effect chance as
    # painted (the batch's last three rows), the flag icons from the battle moves' medium level as the plugin's panel
    # says them, the lines a plugin adds ("Z-Power", Tera), the effectiveness strip and, where descriptions are said, the
    # description.
    def self.move_parts(scene, battler, index)
      painted = PokeAccess::PaintCapture.take_by_source(:eui_moveinfo)
      rows = painted[:positions] || []
      desc = painted[:dtex]
      return nil if rows.length < 3
      figures = rows[-3, 3]
      added = rows.length > MOVE_ROWS ? rows[0, rows.length - MOVE_ROWS].map { |r| PokeAccess.clean(r.to_s) } : []
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
      flags = PokeAccess::Verbosity.keep?(:battle_move, :medium) ? flags_text : nil
      parts.push(flags) if flags
      parts.concat(added)
      eff = effect_text(scene)
      parts.push(eff) if eff
      d = PokeAccess::Verbosity.descriptions? ? PokeAccess::PaintCapture.text(desc) : nil
      parts.push(d) unless d.to_s.strip.empty?
      parts.empty? ? nil : parts
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    # foe an hp share, what foe_parts adds, and the sex of its displayed Pokemon.
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
      tera = tera_part(battler)
      parts.push(tera) if tera
      if owned
        ab = (battler.abilityName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_ability, :a => ab)) if ab && !ab.to_s.empty?
        it = (battler.itemName rescue nil)
        parts.push(PokeAccess::I18n.t(:dbk_item, :i => it)) if it && !it.to_s.empty?
      else
        parts.concat(foe_parts(battler))
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      0
    end

    # What a copy's panel paints more for a foe; the release, nothing.
    def self.foe_parts(_battler); []; end

    # The types the panel draws (pbAddTypesDisplay): with Illusion on a foe, the disguise's plus any added third
    # type; terastallized, the original ones; "???" for a species never met, a celestial battler or one left with no
    # typing (Burn Up, Double Shock).
    def self.painted_types(battler)
      list = drawn_types(battler)
      list.is_a?(Array) && list.empty? ? [:QMARKS] : list
    end

    # painted_types' typing before an empty one is drawn as "???".
    def self.drawn_types(battler)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      (battler.types rescue nil)
    end

    # Whether the panel draws "???" instead of a typing: a species the player has neither owned nor battled
    # (unless the game is set to always show types), and any celestial battler.
    def self.unknown_species?(battler, poke)
      return true if (battler.celestial? rescue false)
      return false if (::Settings::ALWAYS_DISPLAY_TYPES rescue false)
      return false if (battler.pbOwnedByPlayer? rescue true)
      sp = (poke.species rescue nil)
      return false if sp.nil?
      return false if ($player.pokedex.owned?(sp) rescue false)
      (($player.pokedex.battled_count(sp) rescue 0)).to_i <= 0
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The Tera Type icon the panel paints with Terastal Phenomenon installed: a foe under Illusion's as the Pokemon it
    # displays, any other battler's as its own; nil without the plugin.
    def self.tera_part(battler)
      return nil unless (PluginManager.installed?("Terastal Phenomenon") rescue false)
      illusion = (battler.effects[PBEffects::Illusion] rescue nil) && !(battler.pbOwnedByPlayer? rescue true)
      type = ((illusion ? battler.displayPokemon : battler).tera_type rescue nil)
      name = type ? PokeAccess::Data.type_name(type) : nil
      name.nil? || name.to_s.empty? ? nil : PokeAccess::I18n.t(:ss2_adv_tera, :t => name)
    rescue StandardError => e
      PokeAccess.swallowed(e)
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
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # Whether this game runs the release and the plugin's setting has this part on: the suite loads every reader, and
    # another release's settings have the same names.
    def self.shows?(setting)
      return false unless defined?(::Battle::Scene) && ::Battle::Scene.method_defined?(:pbFightMenu_EnhancedUI)
      ::Settings.const_defined?(setting) ? ::Settings.const_get(setting) : false
    rescue StandardError => e
      PokeAccess.swallowed(e)
      false
    end

    # The egg groups the summary draws, picked as pbDisplayEggGroups does: Undiscovered for an egg, a shadow or celestial
    # Pokemon or Battle Bond; Unknown for a genderless one but Ditto; else its groups.
    def self.egg_groups(pk)
      noeggs = (pk.egg? rescue false) || (pk.shadowPokemon? rescue false) || (pk.celestial? rescue false) ||
               (pk.hasAbility?(:BATTLEBOND) rescue false)
      groups = noeggs ? [:Undiscovered] : ((pk.species_data.egg_groups rescue nil) || [])
      genderless = (pk.genderless? rescue false) && !(pk.isSpecies?(:DITTO) rescue false)
      names = if genderless && !groups.include?(:Undiscovered)
                [PokeAccess::I18n.t(:egg_group_unknown)]
              else
                groups.uniq.map { |g| (GameData::EggGroup.get(g).name rescue g.to_s) }
              end
      names.empty? ? nil : PokeAccess::I18n.t(:sum_egg_groups, :g => names.join(", "))
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end

    # The happiness meter pbDisplayHappiness draws, as the share of its bar that is filled; none for an egg or a shadow.
    def self.happiness(pk)
      return nil if (pk.egg? rescue true) || (pk.shadowPokemon? rescue false)
      PokeAccess::I18n.t(:mui_happiness, :n => [((pk.happiness.to_i * 100) / 255.0).round, 100].min)
    rescue StandardError => e
      PokeAccess.swallowed(e)
      nil
    end
  end
end

# The strip is drawn from inside the move panel, so its rows are noted on the way past.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbDrawTypeEffectiveness, :optional => true) do |_s, ret, _a|
  PokeAccess::EnhancedUIV1.note_effect_icons(ret)
end

# So are the flag icons, returned as image rows the panel draws with the rest.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbDrawMoveFlagIcons, :optional => true) do |_s, ret, _a|
  PokeAccess::EnhancedUIV1.note_flag_icons(ret)
end

# The move panel, around so its draw runs with the capture armed and the effectiveness hook above unguarded;
# queued, adding only what the fight menu has not said (BattleScene.unheard); deduped by line, not cursor, since
# staging a mechanic repaints the power without a cursor move.
PokeAccess::Hooks.around_hook("Battle::Scene", :pbUpdateMoveInfoWindow, :optional => true) do |scene, nxt, args|
  PokeAccess::EnhancedUIV1.forget_effect_icons
  PokeAccess::PaintCapture.arm(:eui_moveinfo)
  begin
    nxt.call
  ensure
    if PokeAccess.ivar(scene, :@moveUIToggle)
      parts = PokeAccess::EnhancedUIV1.move_parts(scene, args[0], args[1])
      if parts && PokeAccess::Cursor.changed?(scene, :eui_move, parts)
        fresh = PokeAccess::BattleScene.unheard(args[0], args[1], parts)
        PokeAccess.speak(PokeAccess.clean(fresh.join(", ")), false) unless fresh.empty?
      end
    else
      PokeAccess::PaintCapture.take(:eui_moveinfo)
      PokeAccess::BattleScene.panel_shut
      PokeAccess::Cursor.reset(scene, :eui_move)
    end
  end
end

# Hiding the panel lets its slot go, so reopening it on the same move is read.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbHideMoveInfo, :optional => true) do |scene, _a|
  PokeAccess::BattleScene.panel_shut
  PokeAccess::Cursor.reset(scene, :eui_move)
end

# The effects list is drawn from inside the battler panel, so its rows are noted on the way past.
PokeAccess::Hooks.after_hook("Battle::Scene", :pbAddEffectsDisplay, :optional => true) do |_s, ret, _a|
  PokeAccess::EnhancedUIV1.note_effects((ret[1] rescue nil))
end

# The battler detail panel as the grid is walked, interrupting; around, like the move panel, so the effects
# hook above is not guarded out.
PokeAccess::Hooks.around_hook("Battle::Scene", :pbUpdateBattlerInfo, :optional => true) do |scene, nxt, args|
  PokeAccess::EnhancedUIV1.note_effects(nil)
  r = nxt.call
  if PokeAccess.ivar(scene, :@infoUIToggle) && args[0]
    PokeAccess::Cursor.announce(scene, :eui_binfo, (args[0].index rescue nil), true) do
      ui = PokeAccess::EnhancedUIV1
      [ui.battler_text(args[0]), ui.effects_text].compact.join(", ")
    end
  else
    PokeAccess::Cursor.reset(scene, :eui_binfo)
  end
  r
end

# The grid; before, since with select true this method ends in the panel's whole modal loop.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbToggleBattleInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :eui_bsel)
  PokeAccess::Cursor.reset(scene, :eui_binfo)
end

PokeAccess::Hooks.before_hook("Battle::Scene", :pbSelectBattlerInfo, :optional => true) do |scene, _a|
  PokeAccess::Cursor.reset(scene, :eui_bsel)
end

# With select (the grid opening) the ball lineups follow the battler, queued: they stay as they are while it runs.
PokeAccess::Hooks.before_hook("Battle::Scene", :pbUpdateBattlerSelection, :optional => true) do |scene, args|
  PokeAccess::Cursor.announce(scene, :eui_bsel, args[0], true) do
    PokeAccess::EnhancedUIV1.selected_text(scene, args[0])
  end
  if args[1] && PokeAccess.ivar(scene, :@infoUIToggle)
    lineups = PokeAccess::EnhancedUIV1.lineups_text(scene)
    PokeAccess.speak(lineups, false) if lineups
  end
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :memo_extras, :tag => "enhanced_ui_v1") do |_m, original, args|
  ui = PokeAccess::EnhancedUIV1
  groups = ui.shows?(:SUMMARY_EGG_GROUPS) ? ui.egg_groups(args[0]) : nil
  groups ? original.call + [groups] : original.call
end

PokeAccess::Hooks.override(PokeAccess::SummaryGameData, :info_text, :tag => "enhanced_ui_v1") do |_m, original, args|
  ui = PokeAccess::EnhancedUIV1
  t = original.call
  meter = ui.shows?(:SUMMARY_HAPPINESS_METER) ? ui.happiness(args[0]) : nil
  (t && meter) ? "#{t.strip} #{meter}" : t
end
