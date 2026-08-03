module PokeAccess
  # Battle reading: command/fight menus, messages, damage, hp, field conditions.
  module Battle
    # Stores the active battle so the hp/field keys can read it.
    def self.set_battle(b); @battle_ref = b; end

    # Forgets the active battle (called each map frame so stale data is not read). It does NOT touch the
    # in_battle flag: map_poll runs clear_battle every frame, including during a gen-6 fight (which runs
    # inside Scene_Map), so clearing the flag here would erase it one frame after pbBattleAnimation set it.
    # The flag is owned solely by battle_started/battle_ended (the around-hook's ensure is the safety net).
    def self.clear_battle; @battle_ref = nil; end

    # True while a battle is running. Set by the pbBattleAnimation around-hook (gen-6), NOT from
    # $game_temp.in_battle, which gen-6 never sets -- so the spatial sonar is silenced for wild battles too
    # (those run inside Scene_Map without changing the scene or the interpreter). Used by Spatial.busy?.
    def self.in_battle?; @in_battle ? true : false; end

    # Marks battle as started (the whole fight is wrapped by pbBattleAnimation); the sonar goes quiet.
    def self.battle_started; @in_battle = true; end

    # Marks battle as ended (pbBattleAnimation's block returned); the sonar resumes.
    def self.battle_ended; @in_battle = false; end

    # The battler at a battler index in the captured battle, or nil. Used to name a target whose menu text
    # the engine left blank (e.g. a hidden/unseen foe slot in a double battle).
    def self.battler_at(idx)
      return nil unless @battle_ref && idx
      bs = (@battle_ref.battlers rescue nil)
      bs ? bs[idx] : nil
    rescue StandardError
      nil
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

    # An hp phrase, either a percentage (for a foe or a hide-exact-hp bar) or exact "hp/total". Centralises the
    # branch the battle readers each open-coded, including the divide-by-zero guard on total. param as_percent
    # read as a percentage rather than exact
    def self.hp_phrase(hp, tot, as_percent)
      h = hp.to_i; t = tot.to_i
      return PokeAccess::I18n.t(:bt_hp_pct, :n => (t > 0 ? h * 100 / t : 0)) if as_percent
      PokeAccess::I18n.t(:bt_hp_exact, :hp => h, :tot => t)
    end

    # Describes a battler's hp, status and stat changes. param hide_exact reads hp as a percentage
    # (parity with the foe's bar)
    def self.battler_state(b, hide_exact = false)
      return nil unless b
      hp = hp_phrase(b.hp, b.totalhp, hide_exact)
      t = PokeAccess::I18n.t(:bt_state, :name => b.name, :level => b.level, :hp => hp)
      sv = (b.status rescue nil)
      if sv.is_a?(Symbol)
        st = (sv == :NONE ? nil : (PokeAccess::Data.status_name(sv) rescue nil))
        t += ", " + st.to_s if st && !st.to_s.empty?
      elsif sv && sv != 0
        st = (PokeAccess::Config.status_names[sv] rescue nil)
        t += ", " + PokeAccess::I18n.t(st) if st
      end
      t += stat_changes(b)
      t
    end

    # Speaks the hp of EVERY active battler on a side (so doubles/triples read all). Even battler indices
    # are the player's side, odd are the opponents'. param foe true reads the opponents (hp as percentage)
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

    # Describes EVERY opponent (command menu / info key): name, level and type, so doubles/triples
    # are covered.
    def self.foe_info
      bs = @battle_ref && @battle_ref.battlers
      return nil unless bs.respond_to?(:each_with_index)
      parts = []
      bs.each_with_index do |b, i|
        next unless b && i.odd?
        pk = (b.pokemon rescue nil)
        next unless pk
        ty = types_of(pk)
        line = PokeAccess::I18n.t(:bt_foe, :name => b.name, :level => b.level)
        line += ", " + PokeAccess::I18n.t(:bt_type, :t => ty.join(' ')) unless ty.empty?
        parts.push(line)
      end
      parts.empty? ? nil : parts.join(". ")
    rescue StandardError
      nil
    end

    @last_target = nil

    # The index of the battler currently choosing a target in the gen-6 pbChooseTarget loop, read from the
    # fight window whose battler was set to the chooser (cw.battler = @battle.battlers[index]). Used so the
    # self/ally label is relative to the chooser, not hardcoded to slot 0 (the second player slot, index 2,
    # is also a valid chooser and would otherwise mislabel itself as ally and its partner as self). nil when
    # it cannot be read, so the caller keeps the slot-0 assumption as a fallback.
    def self.target_chooser_index(scene)
      cw = PokeAccess.sprite(scene, "fightwindow")
      b = (cw.battler rescue nil)
      (b.index rescue nil)
    rescue StandardError
      nil
    end

    # The side key for a highlighted battler while choosing a target, relative to the chooser: an odd index
    # is always the foe's side; among the player's slots, the chooser itself reads "your pokemon" and the
    # partner "ally". param chooser the choosing battler's index, or nil to assume slot 0
    def self.target_side_key(index, chooser)
      return :bt_target_foe if index.odd?
      return :bt_target_self if index == (chooser.nil? ? 0 : chooser)
      :bt_target_ally
    end

    # Speaks the move under the fight-menu cursor, once per real change. An empty/absent slot passes key
    # nil, which Cursor treats as unchanged: it neither speaks nor records, so the last real move stays as
    # the dedup key and the next real move still reads. (The menu itself refuses to move onto an empty slot,
    # so this is the defensive path, not the normal one.)
    # @param interrupt false for the opening read, so it queues behind the hp/turn lines instead of cutting
    #   them; true for navigation, which should cut the previous move
    # The command menu's labels live ONLY inside its window, so unlike read_fight_move -- which goes to the
    # battler's own data and is therefore immune to all of this -- the command reader has to find the
    # widget. And Essentials renamed it: @window up to v17, @cmdWindow from v19 on (checked against the
    # upstream tags v19 through v21.1). Tried in that order, so the pre-v19 games resolve on the first
    # attempt and behave exactly as they always did.
    def self.command_window(disp)
      PokeAccess.ivar(disp, :@window) || PokeAccess.ivar(disp, :@cmdWindow)
    end

    # Speaks the focused battle command (fight/bag/pokemon/run), or nothing when the window cannot be read.
    def self.read_command(disp, index, interrupt)
      w = command_window(disp)
      cmds = w ? PokeAccess.ivar(w, :@commands) : nil
      return unless cmds && cmds[index].is_a?(String)
      PokeAccess.speak_clean(cmds[index], interrupt)
    end

    def self.read_fight_move(disp, interrupt = true)
      b = PokeAccess.ivar(disp, :@battler)
      idx = PokeAccess.ivar(disp, :@index)
      ok = b && b.moves[idx] && b.moves[idx].id != 0
      PokeAccess::Cursor.on_change(disp, :fight_move, ok ? idx : nil) do
        m = b.moves[idx]
        t = m.name.to_s
        t += ". " + PokeAccess::I18n.t(:mv_pp, :pp => m.pp, :tot => m.totalpp) if m.respond_to?(:pp)
        PokeAccess.speak_clean(t, interrupt)
        PokeAccess::Info.set_info(:move, m)
      end
    rescue StandardError
      nil
    end

    # Announces the battler under the target cursor while choosing a move's target in doubles (gen-6
    # pbChooseTarget highlights via pbUpdateSelected). param index the highlighted battler index, or
    # negative to clear (so re-entering selection reads again)
    def self.announce_target(scene, index)
      if index.nil? || index < 0
        @last_target = nil
        return
      end
      battle = PokeAccess.ivar(scene, :@battle)
      return unless battle
      return unless (battle.doublebattle rescue false)
      return if index == @last_target
      @last_target = index
      b = (battle.battlers ? battle.battlers[index] : nil) rescue nil
      side = PokeAccess::I18n.t(target_side_key(index, target_chooser_index(scene)))
      name = (b && (b.pokemon rescue nil)) ? b.name : PokeAccess::I18n.t(:bt_empty_slot)
      PokeAccess.speak("#{name}, #{side}", true)
    rescue StandardError
      nil
    end

    # GameData-era Essentials returns weather/terrain as symbols (gen-6 used integers / PBEffects), so these
    # map the modern symbols to the same localization keys the gen-6 path already uses.
    WEATHER_SYMS = { :Sun => :w_sun, :Rain => :w_rain, :Sandstorm => :w_sandstorm, :Hail => :w_hail,
                     :Snow => :w_snow, :HarshSun => :w_harsh_sun, :HeavyRain => :w_heavy_rain,
                     :StrongWinds => :w_strong_winds, :ShadowSky => :w_shadow_sky }
    TERRAIN_SYMS = { :Electric => :bt_electric, :Grassy => :bt_grassy, :Misty => :bt_misty,
                     :Psychic => :bt_psychic }
    # Overworld weather is its own enum in gen-6 (PBFieldWeather), laid out differently from the battle
    # weather table, so it gets its own integer map. Modern reuses the GameData::Weather name.
    FIELD_WEATHER = { 1 => :w_rain, 2 => :w_storm, 3 => :w_snow, 4 => :w_blizzard,
                      5 => :w_sandstorm, 6 => :w_heavy_rain, 7 => :w_sun }

    # The localized weather name for a weather id, dual-shape: an integer (gen-6) via the config table,
    # or a symbol (modern) via the symbol map. nil for none/unknown.
    def self.weather_name(wid)
      return nil if wid.nil? || wid == 0 || wid == :None
      key = (PokeAccess::Config.weather_names[wid] rescue nil) || WEATHER_SYMS[wid]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The localized overworld weather name: modern a GameData::Weather symbol (resolved to its own
    # localized name), gen-6 an integer in the PBFieldWeather layout. nil for none.
    def self.overworld_weather_name(wid)
      return nil if wid.nil? || wid == 0 || wid == :None
      if wid.is_a?(Symbol)
        n = (GameData::Weather.get(wid).name rescue nil)
        return n if n && !n.to_s.empty?
        k = WEATHER_SYMS[wid]; return k ? PokeAccess::I18n.t(k) : wid.to_s
      end
      key = FIELD_WEATHER[wid]
      key ? PokeAccess::I18n.t(key) : nil
    end

    # The time-of-day key from the day/night clock (same module in both engines), or nil if the game
    # has no such system. The broad isDay? window overlaps the specific bands, so the named parts
    # (morning/afternoon/evening/night) are checked first and plain day is the fallback.
    def self.time_of_day
      return nil unless defined?(PBDayNight)
      return :tod_morning   if (PBDayNight.isMorning? rescue false)
      return :tod_afternoon if (PBDayNight.isAfternoon? rescue false)
      return :tod_evening   if (PBDayNight.isEvening? rescue false)
      return :tod_night     if (PBDayNight.isNight? rescue false)
      return :tod_day       if (PBDayNight.isDay? rescue false)
      nil
    end

    # Formats a duration in whole seconds as m:ss.
    def self.fmt_mmss(secs)
      s = secs.to_i
      format("%d:%02d", s / 60, s % 60)
    end

    # The seconds left in a Bug Contest, computed from whichever clock the engine stores: modern keeps a
    # System.uptime start against TIME_ALLOWED; gen-6 a Graphics.frame_count start against TimerSeconds.
    # nil when there is no time limit or it cannot be read. Both stamps come from the ENGINE, so the elapsed
    # figure is in the engine's own units and has to be scaled: some forks ship an mkxp-z that counts uptime
    # in microseconds, which made every contest read "0:00" from the first second.
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

    # The Safari Zone / Bug Contest status for the field key: balls left and steps (Safari) or time
    # remaining (contest), else a Poke Radar chain. nil when none is running. (Safari/contest states are
    # globals in both engines, absent only in the test stubs.)
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
      # Poke Radar: rd[2] is the chain count, in $game_temp (modern) or $PokemonTemp (gen-6).
      rd = ($game_temp.poke_radar_data rescue nil) || ($PokemonTemp.pokeradar rescue nil)
      return PokeAccess::I18n.t(:radar_chain, :n => rd[2].to_i) if rd.is_a?(Array) && rd[2] && rd[2].to_i > 0
      nil
    rescue StandardError
      nil
    end

    # Speaks the overworld weather and time of day (the G key outside battle), plus the Safari Zone or
    # Bug Contest status when one is in progress. Always says something: clear sky when there is no
    # weather, plus the time band when a clock exists.
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
      field_weather(out)
      field_terrain(out)
      field_sides(out)
      PokeAccess.speak(out.empty? ? PokeAccess::I18n.t(:bt_no_field) : out.join(", "), true)
    rescue StandardError => e
      PokeAccess.log_once("announce_field", e)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_field_error), true)
    end

    # Appends the current weather. Each section is self-guarded so a transient state (e.g. the very frame a
    # terrain expires) or a constant missing on this engine never loses the whole report -- it reads what it
    # can and drops only the failing part, instead of the blanket "could not read the field".
    def self.field_weather(out)
      wid = (@battle_ref.pbWeather rescue (@battle_ref.weather rescue 0))
      wn = weather_name(wid)
      out.push(PokeAccess::I18n.t(:bt_weather, :w => wn)) if wn
    rescue StandardError
      nil
    end

    # Appends trick room / gravity and the active terrain (object-terrain on modern, effect flags on gen-6).
    def self.field_terrain(out)
      field = PokeAccess.ivar(@battle_ref, :@field)
      return unless field
      { :TrickRoom => :bt_trickroom, :Gravity => :bt_gravity }.each do |k, key|
        c = (field.effects[PBEffects.const_get(k)] rescue 0)
        out.push(PokeAccess::I18n.t(key)) if c && c > 0
      end
      if field.respond_to?(:terrain)
        tk = TERRAIN_SYMS[(field.terrain rescue nil)]
        out.push(PokeAccess::I18n.t(tk)) if tk
      else
        { :GrassyTerrain => :bt_grassy, :MistyTerrain => :bt_misty,
          :ElectricTerrain => :bt_electric, :PsychicTerrain => :bt_psychic }.each do |k, key|
          c = (field.effects[PBEffects.const_get(k)] rescue 0)
          out.push(PokeAccess::I18n.t(key)) if c && c > 0
        end
      end
    rescue StandardError
      nil
    end

    # Appends the per-side effects (screens, hazards, tailwind...) for both sides.
    def self.field_sides(out)
      sides = PokeAccess.ivar(@battle_ref, :@sides)
      return unless sides
      side_names = [PokeAccess::I18n.t(:bt_side_yours), PokeAccess::I18n.t(:bt_side_foe)]
      [0, 1].each do |si|
        s = sides[si]; next unless s
        { :Reflect => :bt_reflect, :LightScreen => :bt_lightscreen, :AuroraVeil => :bt_auroraveil,
          :Spikes => :bt_spikes, :StealthRock => :bt_stealthrock, :ToxicSpikes => :bt_toxicspikes,
          :Tailwind => :bt_tailwind, :StickyWeb => :bt_stickyweb }.each do |k, key|
          c = (s.effects[PBEffects.const_get(k)] rescue 0)
          out.push(PokeAccess::I18n.t(:bt_side_effect, :effect => PokeAccess::I18n.t(key), :side => side_names[si])) if c && c > 0
        end
      end
    rescue StandardError
      nil
    end

    # Speaks the hp delta of a battler when it changes (damage or healing).
    def self.announce_hp_change(pkmn, oldhp)
      return unless pkmn && oldhp
      diff = (pkmn.hp - oldhp rescue 0)
      return if diff == 0
      foe = (pkmn.index.odd? rescue false)
      verb = PokeAccess::I18n.t(diff < 0 ? :bt_lose : :bt_gain)
      rest = hp_phrase(pkmn.hp, pkmn.totalhp, foe)
      PokeAccess.speak(PokeAccess::I18n.t(:bt_hp_change, :name => pkmn.name, :verb => verb, :n => diff.abs, :rest => rest), false)
    end

    # The announce key for a Mega-Evolution button state change, or nil. Only a real toggle between
    # available (1) and registered (2) is voiced, not the initial open. param v 0 hidden, 1 available, 2 on
    def self.mega_key(last, v)
      return nil unless v == 1 || v == 2
      return nil if last.nil? || last == v
      v == 2 ? :bt_mega_on : :bt_mega_off
    end

    # The per-stat increases on level up: diffs the new stats (already on pkmn) against the old values
    # the scene's pbLevelUp received; nil when nothing changed. The caller passes the stats already
    # mapped, since their order differs by engine.
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
