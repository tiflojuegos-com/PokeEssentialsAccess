module PokeAccess
  # Battle reading: command/fight menus, messages, damage, hp, field conditions.
  module Battle
    # Stores the active battle so the hp/field keys can read it.
    def self.set_battle(b); @battle_ref = b; end

    # The active battle set_battle stored, or nil.
    def self.battle; @battle_ref; end

    # Forgets the active battle; called every map frame, gen-6 fights included, so it leaves the in_battle flag to
    # battle_started and battle_ended.
    def self.clear_battle; @battle_ref = nil; end

    # True while a battle runs, per the pbBattleAnimation hook (gen 6 never sets $game_temp.in_battle).
    def self.in_battle?; @in_battle ? true : false; end

    # Marks battle as started (the whole fight is wrapped by pbBattleAnimation); the sonar goes quiet.
    def self.battle_started; @in_battle = true; end

    # Marks battle as ended (pbBattleAnimation's block returned): the sonar resumes and the info key lets go of the
    # battle's move and foes, also where Game_Temp#in_battle is never set.
    def self.battle_ended
      @in_battle = false
      @field_announced_for = nil
      PokeAccess::Info.clear_combat
    end

    # Marks that the command menu is about to (re)open, so its first option read is queued instead of
    # cutting the hp/turn lines just spoken.
    def self.cmd_opening!; @cmd_opening = true; end

    # Returns whether the command menu is opening and clears the flag (so only the first read after an
    # open is queued, and later navigation interrupts normally).
    def self.cmd_opening_consume; v = @cmd_opening; @cmd_opening = false; v; end

    # Builds the stat-stage change suffix for a battler.
    def self.stat_changes(b)
      stages = PokeAccess.ivar(b, :@stages)
      parts = []
      if stages.is_a?(Hash)
        stages.each do |sym, v|
          next if v.nil? || v == 0
          nm = (PokeAccess::Data.stat_name(sym) || sym.to_s)
          parts.push("#{nm} #{v > 0 ? '+' : ''}#{v}")
        end
      elsif stages.is_a?(Array)
        stages.each_index do |s|
          v = stages[s]
          next if v.nil? || v == 0
          nm = (PokeAccess::Data.stat_name(s) || "stat")
          parts.push("#{nm} #{v > 0 ? '+' : ''}#{v}")
        end
      end
      parts.empty? ? "" : PokeAccess::I18n.t(:bt_changes, :list => parts.join(", "))
    rescue StandardError
      ""
    end

    # An hp phrase: a percentage (for a foe or a hide-exact-hp bar) when as_percent, else exact "hp/total".
    def self.hp_phrase(hp, tot, as_percent)
      h = hp.to_i; t = tot.to_i
      return PokeAccess::I18n.t(:bt_hp_pct, :n => (t > 0 ? h * 100 / t : 0)) if as_percent
      PokeAccess::I18n.t(:bt_hp_exact, :hp => h, :tot => t)
    end

    # The sex sign the databox draws beside a battler's name, as a " sign" suffix, or ""; displayGender, so Illusion
    # shows the imitated sex. A box that draws otherwise overrides this in its plugin or game profile.
    def self.shown_sex(b)
      s = PokeAccess::Party.sign((b.displayGender rescue (b.gender rescue nil)))
      s ? " " + s : ""
    end

    # The level a battler's databox draws, or nil where its box draws none; what a box paints in its place
    # ("??") comes back as the word for it.
    def self.shown_level(b)
      b.level
    end

    # The hit points as the battler's box shows them: a percentage for a foe (parity with its bar), exact for
    # the player's own; a box that draws them otherwise overrides this. param hide_exact true for a foe
    def self.shown_hp(b, hide_exact)
      hp_phrase(b.hp, b.totalhp, hide_exact)
    end

    # The types a foe is shown with: the disguise's under Illusion, else its battle types (which a move may change).
    def self.shown_types(b)
      disguise = (b.effects[PBEffects::Illusion] rescue nil)
      return types_of(disguise) if disguise && !(disguise == true)
      list = (b.pbTypes(true) rescue nil) || [(b.type1 rescue nil), (b.type2 rescue nil)].compact
      list = list.uniq.compact
      list.empty? ? types_of((b.pokemon rescue nil)) : list.map { |t| PokeAccess::Data.type_name(t) }.compact
    rescue StandardError
      types_of((b.pokemon rescue nil))
    end

    # The Pokemon a battler-selection grid draws in a slot: the player's own as is, a foe as displayed (Illusion).
    def self.grid_pokemon(b, mine)
      pk = mine ? (b.pokemon rescue nil) : (b.displayPokemon rescue nil)
      pk || b
    end

    # The battler's databox when a databoxStyle battle rule styled it (Deluxe Battle Kit), or nil for a plain box.
    def self.styled_box(b)
      box = (PokeAccess.sprite(b.battle.scene, "dataBox_#{b.index}") rescue nil)
      box && PokeAccess.ivar(box, :@style) ? box : nil
    end

    # The icons a databox draws beside the name, by a pattern on each file name, and the key of the word each stands
    # for; a profile adds its own with icon_mark.
    ICON_MARKS = [
      [/\A(?:icon_own|battleBoxOwned\d*)\z/i, :dex_caught],
      [/\Ashiny\z/i, :pk_shiny],
      [/\A(?:icon_mega(?:_\w+)?|battleMegaEvoBox)\z/i, :bt_mark_mega],
      [/\A(?:icon_primal(?:_\w+)?|battlePrimal\w*Box)\z/i, :bt_mark_primal]
    ]

    # Registers a databox icon of a game's own: a pattern on its file name and the i18n key of its word.
    def self.icon_mark(pattern, key)
      ICON_MARKS.push([pattern, key])
    end

    # The words for the icons a databox drew, in the order drawn, each once.
    def self.marks_of(icons)
      words = []
      (icons || []).each do |path|
        base = File.basename(path.to_s).sub(/\.png\z/i, "")
        hit = ICON_MARKS.find { |pattern, _key| base =~ pattern }
        words.push(PokeAccess::I18n.t(hit[1])) if hit
      end
      words.uniq
    end

    # Runs a databox's refresh (the block) and keeps on its battler the marks its icons stand for; answers what the
    # refresh answers. Each era's file, or a profile for a box of its own, hooks its databox with it.
    def self.marks_around(box)
      ret = nil
      icons = PokeAccess::PaintCapture.icons { ret = yield }
      note_marks(box, icons)
      ret
    end

    # Keeps a databox's marks on its battler; a foe's first marks are said as it enters, queued, from the battle
    # marks reading's medium level. Later changes are left to the battle's own messages.
    def self.note_marks(box, icons)
      b = PokeAccess.ivar(box, :@battler)
      return unless b
      marks = marks_of(icons)
      pk = (b.pokemon rescue nil)
      entering = !PokeAccess.ivar(b, :@pa_marks_for).equal?(pk)
      b.instance_variable_set(:@pa_marks, marks)
      b.instance_variable_set(:@pa_marks_for, pk)
      return unless entering && !marks.empty? && (b.index.to_i.odd? rescue false)
      return unless PokeAccess::Verbosity.keep?(:battle_marks, :medium)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_marks_entry, :name => b.name, :marks => marks.join(", ")), false)
    rescue StandardError
      nil
    end

    # The marks a battler's databox drew, as words; none where it drew none or was never read.
    def self.shown_marks(b)
      PokeAccess.ivar(b, :@pa_marks) || []
    end

    # Describes a battler's name, level, hp, status, the marks its box draws and its stat changes; hide_exact reads hp
    # as a percentage.
    def self.battler_state(b, hide_exact = false)
      return nil unless b
      hp = shown_hp(b, hide_exact)
      name = "#{b.name}#{shown_sex(b)}"
      lv = shown_level(b)
      t = if lv
            PokeAccess::I18n.t(:bt_state, :name => name, :level => lv, :hp => hp)
          else
            PokeAccess::I18n.t(:bt_state_nolevel, :name => name, :hp => hp)
          end
      sv = (b.status rescue nil)
      if sv.is_a?(Symbol)
        st = (sv == :NONE ? nil : (PokeAccess::Data.status_name(sv) rescue nil))
        t += ", " + st.to_s if st && !st.to_s.empty?
      elsif sv && sv != 0
        st = (PokeAccess::Config.status_names[sv] rescue nil)
        t += ", " + PokeAccess::I18n.t(st) if st
      end
      marks = shown_marks(b)
      t += ", " + marks.join(", ") if !marks.empty? && PokeAccess::Verbosity.keep?(:battle_marks, :medium)
      t += stat_changes(b)
      t
    end

    # Speaks the state of every active battler on a side: even indices are the player's, odd the foes'; foe true
    # reads the foes, hp as a percentage.
    def self.announce_hp(foe)
      return unless @battle_ref
      bs = PokeAccess.expect!("battle.battlers", (@battle_ref.battlers rescue nil))
      return unless bs.respond_to?(:each_with_index)
      parts = []
      bs.each_with_index do |b, i|
        next if b.nil?
        next unless (b.pokemon rescue nil)
        next unless (i.odd? == foe)
        s = (battler_state(b, foe) rescue nil)
        parts.push(s) if s
      end
      PokeAccess.speak(parts.empty? ? PokeAccess::I18n.t(:bt_no_pokemon) : parts.join(". "), true)
    rescue StandardError
      nil
    end

    # Spoken type names of a pokemon, via the engine's data provider.
    def self.types_of(pk)
      return [] unless pk
      (PokeAccess::Data.pokemon_types(pk) || []).uniq
    rescue StandardError
      []
    end

    # Describes every opponent for the command menu and the info key: name, level, types and the marks its box draws.
    def self.foe_info
      bs = @battle_ref && @battle_ref.battlers
      return nil unless bs.respond_to?(:each_with_index)
      parts = []
      bs.each_with_index do |b, i|
        next unless b && i.odd?
        next unless (b.pokemon rescue nil)
        ty = shown_types(b)
        name = "#{b.name}#{shown_sex(b)}"
        lv = shown_level(b)
        line = lv ? PokeAccess::I18n.t(:bt_foe, :name => name, :level => lv) : PokeAccess::I18n.t(:bt_foe_nolevel, :name => name)
        line += ", " + PokeAccess::I18n.t(:bt_type, :t => ty.join(' ')) unless ty.empty?
        marks = shown_marks(b)
        line += ", " + marks.join(", ") unless marks.empty?
        parts.push(line)
      end
      parts.empty? ? nil : parts.join(". ")
    rescue StandardError
      nil
    end

    @last_target = nil

    # The index of the battler choosing a target in gen 6's pbChooseTarget: the one it was called for (kept by its
    # hook), else the fight window's battler; nil when unreadable (the caller then assumes slot 0).
    def self.target_chooser_index(scene)
      kept = PokeAccess.ivar(scene, :@access_target_chooser)
      return kept if kept.is_a?(Integer)
      cw = PokeAccess.sprite(scene, "fightwindow") || PokeAccess.sprite(scene, "fightWindow")
      b = (cw.battler rescue nil)
      (b.index rescue nil)
    rescue StandardError
      nil
    end

    # The side key for a highlighted target: foe for an odd index, self for the chooser (nil = slot 0), else ally.
    def self.target_side_key(index, chooser)
      return :bt_target_foe if index.odd?
      return :bt_target_self if index == (chooser.nil? ? 0 : chooser)
      :bt_target_ally
    end

    # The command menu's window, where its labels live: @window up to v17, @cmdWindow from v19 on.
    def self.command_window(disp)
      PokeAccess.ivar(disp, :@window) || PokeAccess.ivar(disp, :@cmdWindow)
    end

    # Keeps the four command labels of a setTexts call ([message, label0..label3]), which some displays throw away.
    def self.stash_command_texts(disp, value)
      return unless value.is_a?(Array)
      disp.instance_variable_set(:@access_cmd_texts, value[1, 4])
    rescue StandardError
      nil
    end

    # Speaks the focused battle command from the command window's list or, for a display that draws buttons
    # (USE_GRAPHICS), the labels stash_command_texts kept; nothing when neither has it.
    def self.read_command(disp, index, interrupt)
      w = command_window(disp)
      cmds = (w ? PokeAccess.ivar(w, :@commands) : nil) || PokeAccess.ivar(disp, :@access_cmd_texts)
      return unless cmds && cmds[index].is_a?(String)
      PokeAccess.speak_clean(cmds[index], interrupt, :menu)
    end

    # Speaks the focused gen-6 fight move once per change, at the battle_move level: brief the name and pp, medium
    # adds the type, full the category. An empty slot passes key nil, which Cursor treats as unchanged.
    # param interrupt false for the opening read, which queues behind the hp and turn lines
    def self.read_fight_move(disp, interrupt = true)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      ok = b && b.moves[idx] && PokeAccess::MoveInfo.real_id?(PokeAccess::MoveInfo.id_of(b.moves[idx]))
      PokeAccess::Cursor.on_change(disp, :fight_move, ok ? idx : nil) do
        m = b.moves[idx]
        ty = (PokeAccess::Data.type_name(m.type) rescue nil)
        nm, ty = PokeAccess::MoveInfo.painted(m, m.name.to_s, ty)
        pp = m.respond_to?(:pp) ? PokeAccess::I18n.t(:mv_pp, :pp => m.pp, :tot => PokeAccess.attr_of(m, :totalpp, :total_pp)) : nil
        parts = [[nm.to_s, :brief],
                 [(ty && !ty.to_s.empty?) ? PokeAccess::I18n.t(:mv_type, :t => ty) : nil, :medium],
                 [PokeAccess::MoveInfo.category_word(PokeAccess::MoveInfo.category_of(m)), :full],
                 [pp, :brief]]
        PokeAccess.speak_clean(PokeAccess::Verbosity.line(:battle_move, parts, ". "), interrupt, :menu)
        PokeAccess::Info.set_info(:move, m)
      end
    rescue StandardError
      nil
    end

    # levelup_text from the raw pbLevelUp arguments, whose old stats come as hp, atk, def, speed, spatk, spdef in
    # v16-17 and as hp, atk, def, spatk, spdef, speed in the v18 hybrids (modern).
    def self.levelup_from_args(a, modern)
      spatk, spdef, speed = modern ? [a[5], a[6], a[7]] : [a[6], a[7], a[5]]
      levelup_text(a[0], a[2], a[3], a[4], spatk, spdef, speed)
    end

    # Whether this is a double battle: the doublebattle flag in gen 6, pbSideSize(0) from v18 on.
    def self.doubles?(battle)
      d = (battle.doublebattle rescue nil)
      return (d ? true : false) unless d.nil?
      (battle.pbSideSize(0) rescue 1).to_i > 1
    rescue StandardError
      false
    end

    # Announces every slot a spread move lights (the non-nil entries of list), once per change.
    def self.announce_targets(scene, list)
      lit = []
      list.each_index { |i| lit.push(i) unless list[i].nil? }
      return if lit.empty?
      return if lit == @last_target
      @last_target = lit
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle
      chooser = target_chooser_index(scene)
      names = lit.map do |i|
        b = (battle.battlers ? battle.battlers[i] : nil) rescue nil
        nm = (b && (b.pokemon rescue nil)) ? b.name : PokeAccess::I18n.t(:bt_empty_slot)
        "#{nm}, #{PokeAccess::I18n.t(target_side_key(i, chooser))}"
      end
      PokeAccess.speak(names.join(". "), true, :menu)
    rescue StandardError
      nil
    end

    # Announces the battler under the target cursor in doubles; a negative index resets, an array is a spread move.
    def self.announce_target(scene, index)
      return announce_targets(scene, index) if index.is_a?(Array)
      if index.nil? || index < 0
        @last_target = nil
        return
      end
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle
      return unless doubles?(battle)
      return if index == @last_target
      @last_target = index
      b = (battle.battlers ? battle.battlers[index] : nil) rescue nil
      side = PokeAccess::I18n.t(target_side_key(index, target_chooser_index(scene)))
      name = (b && (b.pokemon rescue nil)) ? b.name : PokeAccess::I18n.t(:bt_empty_slot)
      PokeAccess.speak("#{name}, #{side}", true, :menu)
    rescue StandardError
      nil
    end

    # Modern weather and terrain symbols => the i18n keys the gen-6 integer path uses; the last row is the weather of
    # the engine Reborn and Rejuvenation share, named after the moves that set it.
    WEATHER_SYMS = { :Sun => :w_sun, :Rain => :w_rain, :Sandstorm => :w_sandstorm, :Hail => :w_hail,
                     :Snow => :w_snow, :HarshSun => :w_harsh_sun, :HeavyRain => :w_heavy_rain,
                     :StrongWinds => :w_strong_winds, :ShadowSky => :w_shadow_sky,
                     :SUNNYDAY => :w_sun, :RAINDANCE => :w_rain, :SANDSTORM => :w_sandstorm, :HAIL => :w_hail,
                     :STRONGWINDS => :w_strong_winds, :SHADOWSKY => :w_shadow_sky }
    TERRAIN_SYMS = { :Electric => :bt_electric, :Grassy => :bt_grassy, :Misty => :bt_misty,
                     :Psychic => :bt_psychic }
    # Gen-6 overworld weather (PBFieldWeather) => i18n key; its layout differs from the battle weather's.
    FIELD_WEATHER = { 1 => :w_rain, 2 => :w_storm, 3 => :w_snow, 4 => :w_blizzard,
                      5 => :w_sandstorm, 6 => :w_heavy_rain, 7 => :w_sun }

    # The localized weather name for a weather id, dual-shape: an integer (gen-6) via the config table,
    # or a symbol (modern) via the symbol map. nil for none/unknown.
    def self.weather_name(wid)
      return nil if wid.nil? || wid == 0 || wid == :None
      key = (PokeAccess::Config.weather_names[wid] rescue nil) || WEATHER_SYMS[wid]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The localized overworld weather name for a symbol (modern) or a PBFieldWeather integer (gen 6); nil for none.
    # The game's own name is the last resort, and only when it differs from the id (vanilla's name is the id).
    def self.overworld_weather_name(wid)
      return nil if wid.nil? || wid == 0 || wid == :None
      if wid.is_a?(Symbol)
        key = (PokeAccess::Config.field_weather_names[wid] rescue nil) || WEATHER_SYMS[wid]
        return PokeAccess::I18n.t(key) if key
        w = (GameData::Weather.get(wid) rescue nil)
        n = (w.name rescue nil)
        n = (w.real_name rescue nil) if n.nil? || n.to_s.empty?
        return n if n && !n.to_s.empty? && n.to_s != wid.to_s
        return wid.to_s
      end
      key = (PokeAccess::Config.field_weather_names[wid] rescue nil) || FIELD_WEATHER[wid]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The time-of-day key from PBDayNight at the game's own now (pbGetTimeNow), or nil without a clock. Specific bands
    # go before the broad isDay?, and evening before afternoon (the v16 afternoon, 12 to 20, covers evening).
    def self.time_of_day
      return nil unless defined?(PBDayNight)
      now = (pbGetTimeNow rescue Time.now)
      return :tod_morning   if (PBDayNight.isMorning?(now) rescue false)
      return :tod_evening   if (PBDayNight.isEvening?(now) rescue false)
      return :tod_afternoon if (PBDayNight.isAfternoon?(now) rescue false)
      return :tod_night     if (PBDayNight.isNight?(now) rescue false)
      return :tod_day       if (PBDayNight.isDay?(now) rescue false)
      nil
    end

    # Formats a duration in whole seconds as m:ss.
    def self.fmt_mmss(secs)
      s = secs.to_i
      format("%d:%02d", s / 60, s % 60)
    end

    # The seconds left in a Bug Contest: a System.uptime start against TIME_ALLOWED (modern, scaled, as some mkxp-z
    # count uptime in microseconds) or a frame_count start against TimerSeconds (gen 6); nil without a limit.
    def self.contest_time_left(s)
      if defined?(System) && System.respond_to?(:uptime) && s.respond_to?(:timer_start)
        total = (BugContestState::TIME_ALLOWED rescue 0)
        return nil if total <= 0
        scale = (PokeAccess.uptime_scale || 1.0)
        return [total - (System.uptime - s.timer_start) / scale, 0].max.to_i
      end
      tmr = (s.timer rescue nil)
      return nil if tmr.nil?
      total = (BugContestState::TimerSeconds rescue 0)
      return nil if total <= 0
      fr = (Graphics.frame_rate rescue PokeAccess::FPS.to_i)
      [total - (Graphics.frame_count - tmr) / fr, 0].max.to_i
    rescue StandardError
      nil
    end

    # The Safari Zone or Bug Contest status for the field key (balls, steps or time left), else the Poke Radar chain
    # (rd[2]); nil when none is running.
    def self.field_event_text
      s = (pbSafariState rescue nil)
      if s && (s.inProgress? rescue false)
        parts = []
        b = (s.ballcount rescue nil); parts.push(PokeAccess::I18n.t(:safari_balls, :n => b)) if b
        st = (s.steps rescue nil); parts.push(PokeAccess::I18n.t(:safari_steps, :n => st)) if st && st > 0
        return parts.empty? ? nil : parts.join(", ")
      end
      c = (pbBugContestState rescue nil)
      if c && (c.inProgress? rescue false)
        parts = []
        b = (c.ballcount rescue nil); parts.push(PokeAccess::I18n.t(:contest_balls, :n => b)) if b
        t = contest_time_left(c); parts.push(PokeAccess::I18n.t(:contest_time, :t => fmt_mmss(t))) if t
        return parts.empty? ? nil : parts.join(", ")
      end
      rd = ($game_temp.poke_radar_data rescue nil) || ($PokemonTemp.pokeradar rescue nil)
      return PokeAccess::I18n.t(:radar_chain, :n => rd[2].to_i) if rd.is_a?(Array) && rd[2] && rd[2].to_i > 0
      nil
    rescue StandardError
      nil
    end

    # Speaks the overworld weather (clear when none), the time of day and field_event_text.
    def self.announce_overworld
      parts = []
      wn = overworld_weather_name(($game_screen.weather_type rescue nil))
      parts.push(wn ? PokeAccess::I18n.t(:bt_weather, :w => wn) : PokeAccess::I18n.t(:ow_clear))
      tod = time_of_day
      parts.push(PokeAccess::I18n.t(tod)) if tod
      fe = field_event_text
      parts.push(fe) if fe
      PokeAccess.speak(parts.join(", "), true)
    rescue StandardError
      nil
    end

    # Speaks field conditions: weather, terrains, rooms, screens and hazards (or the overworld weather
    # when not in battle).
    def self.announce_field
      return announce_overworld unless @battle_ref
      out = []
      fe = field_effect_name(@battle_ref)
      out.push(PokeAccess::I18n.t(:bt_field_effect, :f => fe)) if fe
      field_weather(out)
      field_terrain(out)
      field_sides(out)
      PokeAccess.speak(out.empty? ? PokeAccess::I18n.t(:bt_no_field) : out.join(", "), true)
    rescue StandardError => e
      PokeAccess.log_once("announce_field", e)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_field_error), true)
    end

    # The name of the battlefield a fork keeps apart from weather and terrain (Fire Ash's fieldEffect, the Reborn
    # engine's field), or nil where the battle has none or it is the plain one.
    def self.field_effect_name(battle)
      fe = (battle.fieldEffect rescue nil)
      n = (fe.nil? || fe == :None) ? nil : (GameData::BattleFieldEffect.try_get(fe).name rescue nil)
      n = cache_field_name(battle) if n.nil? || n.to_s.empty?
      (n.nil? || n.to_s.empty?) ? nil : n.to_s
    rescue StandardError
      nil
    end

    # The field of the engine Reborn and Rejuvenation share: battle.field.effect, named by the $cache field data;
    # nil for its plain :INDOOR field.
    def self.cache_field_name(battle)
      fe = (battle.field.effect rescue nil)
      return nil if fe.nil? || fe == :INDOOR
      ($cache.FEData[fe].name rescue nil)
    end

    # Says once per battle the battlefield it opens on, which the screen shows only as its backdrop.
    def self.announce_opening_field(battle)
      return if battle.nil? || battle.equal?(@field_announced_for)
      @field_announced_for = battle
      fe = field_effect_name(battle)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_field_effect, :f => fe), false) if fe
    end

    # Appends the current weather. Each field_* section rescues on its own, so a failure drops only that part.
    def self.field_weather(out)
      wid = (@battle_ref.pbWeather rescue (@battle_ref.weather rescue 0))
      wn = weather_name(wid)
      out.push(PokeAccess::I18n.t(:bt_weather, :w => wn)) if wn
    rescue StandardError
      nil
    end

    # The Reborn engine's terrains, turn counters in the battle's @state effects keyed by symbol.
    RV_TERRAINS = [[:ELECTERRAIN, :bt_electric], [:GRASSY, :bt_grassy], [:MISTY, :bt_misty], [:PSYTERRAIN, :bt_psychic]]

    # Appends trick room / gravity and the active terrain (object-terrain on modern, effect flags on gen-6, the
    # Reborn engine's @state counters).
    def self.field_terrain(out)
      state = PokeAccess.ivar(@battle_ref, :@state)
      return rv_field_terrain(out, state.effects) if state && (state.effects.key?(:ELECTERRAIN) rescue false)
      field = PokeAccess.ivar(@battle_ref, :@field)
      return unless field
      [[:TrickRoom, :bt_trickroom], [:Gravity, :bt_gravity]].each do |k, key|
        c = (field.effects[PBEffects.const_get(k)] rescue 0)
        out.push(PokeAccess::I18n.t(key)) if c && c > 0
      end
      if field.respond_to?(:terrain)
        tk = TERRAIN_SYMS[(field.terrain rescue nil)]
        out.push(PokeAccess::I18n.t(tk)) if tk
      else
        [[:GrassyTerrain, :bt_grassy], [:MistyTerrain, :bt_misty],
         [:ElectricTerrain, :bt_electric], [:PsychicTerrain, :bt_psychic]].each do |k, key|
          c = (field.effects[PBEffects.const_get(k)] rescue 0)
          out.push(PokeAccess::I18n.t(key)) if c && c > 0
        end
      end
    rescue StandardError
      nil
    end

    # The Reborn engine's rooms and terrains: Trick Room on the battle itself, Gravity (negative while permanent) and
    # each terrain in its @state effects.
    def self.rv_field_terrain(out, effects)
      out.push(PokeAccess::I18n.t(:bt_trickroom)) if (@battle_ref.trickroom rescue 0).to_i > 0
      out.push(PokeAccess::I18n.t(:bt_gravity)) if effects[:Gravity].to_i != 0
      RV_TERRAINS.each { |k, key| out.push(PokeAccess::I18n.t(key)) if effects[k].to_i > 0 }
    rescue StandardError
      nil
    end

    # Whether a side effect is in play: a counter (turns, layers) above zero, or a true boolean (Stealth Rock).
    def self.active_effect?(v)
      return v > 0 if v.is_a?(Numeric)
      v ? true : false
    end

    # The per-side effects in spoken order, [PBEffects constant, i18n key]; an Array, as gen 6's Hash is unordered.
    # The Reborn engine has no PBEffects and keys its side effects by these same names as symbols.
    SIDE_EFFECTS = [[:Reflect, :bt_reflect], [:LightScreen, :bt_lightscreen], [:AuroraVeil, :bt_auroraveil],
                    [:Spikes, :bt_spikes], [:StealthRock, :bt_stealthrock], [:ToxicSpikes, :bt_toxicspikes],
                    [:Tailwind, :bt_tailwind], [:StickyWeb, :bt_stickyweb]]

    # Appends the per-side effects (screens, hazards, tailwind...) for both sides.
    def self.field_sides(out)
      sides = PokeAccess.ivar(@battle_ref, :@sides)
      return unless sides
      side_names = [PokeAccess::I18n.t(:bt_side_yours), PokeAccess::I18n.t(:bt_side_foe)]
      [0, 1].each do |si|
        s = sides[si]; next unless s
        SIDE_EFFECTS.each do |k, key|
          v = defined?(PBEffects) ? (s.effects[PBEffects.const_get(k)] rescue nil) : (s.effects[k] rescue nil)
          next unless active_effect?(v)
          out.push(PokeAccess::I18n.t(:bt_side_effect, :effect => PokeAccess::I18n.t(key), :side => side_names[si]))
        end
      end
    rescue StandardError
      nil
    end

    # The hp changes one pbHPChanged call reports: (battler, old hp), or the Reborn engine's list of [battler, old hp]
    # pairs, whose second argument is an animation flag and is not read.
    def self.hp_changed(first, second)
      return announce_hp_change(first, second) unless first.is_a?(Array)
      first.each { |pair| announce_hp_change(pair[0], pair[1]) if pair.is_a?(Array) }
    end

    # Speaks the hp delta of a battler when it changes (damage or healing).
    def self.announce_hp_change(pkmn, oldhp)
      return unless pkmn && oldhp
      diff = (pkmn.hp - oldhp rescue 0)
      return if diff == 0
      foe = (pkmn.index.odd? rescue false)
      verb = PokeAccess::I18n.t(diff < 0 ? :bt_lose : :bt_gain)
      rest = shown_hp(pkmn, foe)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_hp_change, :name => pkmn.name, :verb => verb, :n => diff.abs, :rest => rest), false)
    end

    # The announce key for a Mega button toggle between available (1) and registered (2), or nil; 0 is hidden, and
    # the button appearing is mega_reveal?'s. on and off are the keys for registered and cancelled.
    def self.mega_key(last, v, on = :bt_mega_on, off = :bt_mega_off)
      return nil unless v == 1 || v == 2
      return nil if last.nil? || last == v || last == 0
      v == 2 ? on : off
    end

    # True when the button has just come up available (the fight menu opening with the mechanic ready).
    def self.mega_reveal?(last, v)
      v == 1 && (last.nil? || last == 0)
    end

    # "Mega Evolution available", or the mechanic the button stands for this turn when it is another one.
    # param mech :mega, :ultra, or a special-action symbol (Z-move, dynamax, tera)
    def self.ready_text(mech)
      return PokeAccess::I18n.t(:bt_mega_ready) if mech.nil? || mech == :mega
      return PokeAccess::I18n.t(:bt_ultra_ready) if mech == :ultra
      name = SPECIAL_NAMES[mech]
      name ? PokeAccess::I18n.t(:bt_special_ready, :name => PokeAccess::I18n.t(name)) : PokeAccess::I18n.t(:bt_special_other_ready)
    end

    # The mechanic the fight menu was opened for (see note_special_action), or nil for plain mega.
    def self.special_action; @special_action; end

    # Spoken names for the battle mechanics the Deluxe Battle Kit puts behind the same fight-menu button.
    SPECIAL_NAMES = { :dynamax => :bt_m_dynamax, :zmove => :bt_m_zmove,
                      :ultra => :bt_m_ultra, :tera => :bt_m_tera }

    # The ZUD plugin's fight-menu button (v19): one @mode toggle, and @chosen_button says which mechanic the
    # press registers, by constants the menu class declares.
    ZUD_BUTTONS = [[:MegaButton, :mega], [:UltraBurstButton, :ultra], [:ZMoveButton, :zmove],
                   [:DynamaxButton, :dynamax]]

    # The mechanic behind a ZUD fight menu's button, or nil where the menu has no such button.
    def self.zud_mechanic(disp)
      c = PokeAccess.ivar(disp, :@chosen_button)
      return nil if c.nil?
      k = disp.class
      ZUD_BUTTONS.each { |const, mech| return mech if k.const_defined?(const) && k.const_get(const) == c }
      nil
    rescue StandardError
      nil
    end

    # The announce key (or [key, name]) for a ZUD button toggle: the plain mega and ultra lines, the
    # mechanic's own name for the Z-move and dynamax ones.
    def self.zud_key(mech, last, v)
      return mega_key(last, v, :bt_ultra_on, :bt_ultra_off) if mech == :ultra
      k = mega_key(last, v)
      return k unless k && (mech == :zmove || mech == :dynamax)
      [(v == 2 ? :bt_special_on : :bt_special_off), SPECIAL_NAMES[mech]]
    end

    # Records which mechanic the fight menu was opened for, for the toggle hook; only a Symbol (Deluxe Battle Kit)
    # counts, vanilla passing the boolean megaEvoPossible.
    def self.note_special_action(action)
      @special_action = action.is_a?(Symbol) ? action : nil
    end

    # The announce key, [key, name] pair or nil for a special-action button toggle from mode last to v, named for the
    # mechanic behind it; an unnamed one gets generic wording, not the mega one.
    def self.special_key(last, v)
      k = mega_key(last, v)
      return nil unless k
      return k unless @special_action
      name = SPECIAL_NAMES[@special_action]
      return (v == 2 ? :bt_special_other_on : :bt_special_other_off) unless name
      [(v == 2 ? :bt_special_on : :bt_special_off), name]
    end

    # The per-stat increases on level up: pkmn's new stats against the old ones pbLevelUp received, passed in this
    # order (see levelup_from_args); nil when nothing changed.
    def self.levelup_text(pkmn, ohp, oatk, odef, ospa, ospd, ospe)
      return nil unless pkmn
      parts = []
      [[:totalhp, ohp, :st_hp], [:attack, oatk, :st_atk], [:defense, odef, :st_def],
       [:spatk, ospa, :st_spatk], [:spdef, ospd, :st_spdef], [:speed, ospe, :st_speed]].each do |attr, old, key|
        nv = (pkmn.send(attr) rescue nil)
        next if nv.nil? || old.nil?
        d = nv - old
        parts.push(PokeAccess::I18n.t(:lvl_stat, :stat => PokeAccess::I18n.t(key), :n => d)) if d != 0
      end
      parts.empty? ? nil : parts.join(", ")
    end
  end
end
