module PokeAccess
  # Config menu, the settings screens: the top list, each schema group and its submenus, the sound glossary, debug,
  # how a setting row reads and changes, and the reset of every setting.
  module ConfigMenu
    # Setting => the glossary sound a volume or tone row plays as its value moves.
    PREVIEWS = {
      :audio3d_volume => :npc, :audio3d_npc => :npc, :audio3d_object => :object, :audio3d_door => :door,
      :audio3d_teleporter => :teleporter, :audio3d_mark => :mark, :audio3d_water => :water, :audio3d_wind => :wind_n,
      :footstep_volume => :step, :wall_volume => :wall, :event_volume => :guide,
      :audio3d_tone_npc => :npc, :audio3d_tone_object => :object, :audio3d_tone_door => :door,
      :audio3d_tone_teleporter => :teleporter, :audio3d_tone_mark => :mark, :audio3d_tone_water => :water, :audio3d_tone_wind => :wind_n,
      :footstep_tone => :step, :wall_tone => :wall, :guide_tone => :guide
    }

    # Glossary sound => the volume setting its family plays at in the field (used by tone and master auditions).
    FAMILY_VOLUME = {
      :npc => :audio3d_npc, :object => :audio3d_object, :door => :audio3d_door, :teleporter => :audio3d_teleporter,
      :mark => :audio3d_mark,
      :water => :audio3d_water, :wind_n => :audio3d_wind, :step => :footstep_volume, :wall => :wall_volume,
      :guide => :event_volume
    }

    # How long a looping sample (water, wind) auditions before the menu stops it.
    PREVIEW_LOOP_SECONDS = 2.0

    # The submenus that hang off the audio screen, as [group, label] pairs in menu order.
    AUDIO_SUBMENUS = [[:audio3d_vol, :cat_pos_vol], [:audio3d_freq, :cat_pos_freq], [:audio3d_tone, :cat_pos_tone],
                      [:audio3d_walls, :cat_pos_walls], [:audio3d_adv, :cat_positional_adv]]

    # Auditions a volume or tone row, positionally if the engine is up, else as the flat glossary sample: a family's
    # volume row at the value just set, a tone or master row at the family's own volume.
    def self.preview(key, kind, v)
      entry = PokeAccess::SoundGlossary.entry(PREVIEWS[key])
      return unless entry
      own = kind == :vol && key != :audio3d_volume
      vol = own ? v : (PokeAccess::Config.send(FAMILY_VOLUME[entry[0]]) rescue 100).to_i
      stop_preview
      pitch = PokeAccess::SoundGlossary.engine_pitch(entry)
      played = (PokeAccess::Audio3D.preview(entry[0], vol, pitch) rescue false)
      return PokeAccess::SoundGlossary.play(entry, vol) unless played
      @preview = [entry[0], PokeAccess.clock + PREVIEW_LOOP_SECONDS] if PokeAccess::Audio3D.loop?(entry[0])
    end

    # Ends a looping audition whose time is up (called every modal frame).
    def self.expire_preview
      stop_preview if @preview && PokeAccess.clock >= @preview[1]
    end

    # Stops the looping audition, if one plays (the menu is closing or its time is up).
    def self.stop_preview
      return unless @preview
      (PokeAccess::Audio3D.preview_stop(@preview[0]) rescue nil)
      @preview = nil
    end

    # The top level: the schema categories, then the menu's own screens and the reset.
    def self.top_rows
      rows = PokeAccess::Config::CATEGORIES.map { |g, label| { :kind => :enter, :group => g, :label => label } }
      rows.push({ :kind => :enter, :group => :sounds, :label => :cat_sounds })
      rows.push({ :kind => :enter, :group => :personal, :label => :cat_personal })
      rows.push({ :kind => :remap, :label => :cat_remap })
      rows.push({ :kind => :enter, :group => :debug, :label => :cat_debug })
      rows.push({ :kind => :action, :action => :reset, :label => :cat_reset })
      rows
    end

    # The sound glossary: one audition row per entry.
    def self.sounds_rows
      rows = PokeAccess::SoundGlossary.entries.map { |e| { :kind => :sound, :entry => e, :label => e[2] } }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The debug screen: the diagnostic dumps, the recorder toggle and the self-check, then its settings.
    def self.debug_rows
      rows = [{ :kind => :action, :action => :diag_audio,  :label => :dbg_diag_audio },
              { :kind => :action, :action => :diag_events, :label => :dbg_diag_events },
              { :kind => :action, :action => :diag_perf,   :label => :dbg_diag_perf },
              { :kind => :action, :action => :diag_map,    :label => :dbg_diag_map },
              { :kind => :action, :action => :diag_scene,  :label => :dbg_diag_scene },
              { :kind => :action, :action => :diag_full,   :label => :dbg_diag_full },
              { :kind => :action, :action => :rec_toggle,
                :label => (PokeAccess::Recorder.recording? ? :dbg_rec_stop : :dbg_rec_start) },
              { :kind => :action, :action => :selfcheck, :label => :dbg_selfcheck }]
      PokeAccess::Config.schema_group(:debug).each { |r| rows.push({ :kind => :setting, :row => r }) }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # A schema group's settings, the submenus that hang off it ([group, label] pairs), then back.
    def self.group_rows(group, submenus = [])
      rows = PokeAccess::Config.schema_group(group).map { |r| { :kind => :setting, :row => r } }
      submenus.each { |g, label| rows.push({ :kind => :enter, :group => g, :label => label }) }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # A numeric setting's value with the unit its kind names, in the form that goes with the number.
    def self.with_unit(kind, v)
      b = PokeAccess::Config::KIND_BOUNDS[kind]
      (b && b[3]) ? "#{v} #{t(b[3], :n => v)}" : v.to_s
    end

    def self.value_text(row)
      v = PokeAccess::Config.send(row[0])
      return with_unit(row[2], v) if PokeAccess::Config::KIND_BOUNDS[row[2]]
      case row[2]
      when :flag  then v ? t(:val_on) : t(:val_off)
      when :lang  then PokeAccess::I18n.language_name(v)
      when :algo  then t("algo_#{v}".to_sym)
      when :occ   then t("occ_#{v}".to_sym)
      when :navmode then t("nav_#{v}".to_sym)
      when :verbosity then PokeAccess::Verbosity.name_of(v)
      else v.to_s
      end
    end

    # A setting's help, as the info key reads it: the chosen search algorithm's own for the algorithm row, else
    # the row's help with the mod's keys named as the player has them, or the row itself when it has none.
    def self.setting_help(row)
      return t("help_algo_#{PokeAccess::Config.send(row[0])}".to_sym) if row[2] == :algo
      row[5] ? t(row[5], key_vars) : describe
    end

    # The menu's only way to write a setting: assigns it and drops the locator's verdicts, which may depend on one.
    def self.set_config(key, v)
      PokeAccess::Config.send("#{key}=", v)
      (PokeAccess::Locator.clear_verdicts rescue nil)
    end

    def self.adjust_setting(row, dir)
      key = row[0]
      b = PokeAccess::Config::KIND_BOUNDS[row[2]]
      if b
        v = PokeAccess::Config.send(key).to_i + dir * b[2]
        v = b[0] if v < b[0]
        v = b[1] if v > b[1]
        set_config(key, v)
        preview(key, row[2], v)
        return say("#{t(row[4])}, #{with_unit(row[2], v)}")
      end
      case row[2]
      when :flag
        v = !PokeAccess::Config.send(key)
        set_config(key, v)
        say("#{t(row[4])}, #{v ? t(:val_on) : t(:val_off)}")
      when :lang
        v = PokeAccess::I18n.next_language(PokeAccess::Config.language)
        set_config(:language, v)
        say("#{t(row[4])}, #{PokeAccess::I18n.language_name(v)}")
      when :algo
        cycle(row, key, dir, PokeAccess::Pathfinder::ALGORITHMS, "algo_")
      when :occ
        cycle(row, key, dir, [:hear, :occlude, :hide], "occ_")
      when :navmode
        cycle(row, key, dir, [:off, :basic, :full], "nav_")
      when :verbosity
        v = PokeAccess::Verbosity.next_scheme(dir)
        set_config(key, v)
        say("#{t(row[4])}, #{PokeAccess::Verbosity.name_of(v)}")
      end
    end

    # Steps a setting through an ordered list of symbols (wrapping), announcing the new value via its
    # i18n prefix (e.g. "occ_" + :hide -> :occ_hide).
    def self.cycle(row, key, dir, list, prefix)
      cur = PokeAccess::Config.send(key)
      v = list[((list.index(cur) || 0) + dir) % list.length]
      set_config(key, v)
      say("#{t(row[4])}, #{t("#{prefix}#{v}".to_sym)}")
    end

    def self.run_action(a)
      return run_transfer(a[0], a[1]) if a.is_a?(Array)
      case a
      when :reset
        reset_defaults
      when :diag_audio  then PokeAccess::Keys.diag_section_to_clip(:audio)
      when :diag_events then PokeAccess::Keys.diag_section_to_clip(:events)
      when :diag_perf   then PokeAccess::Keys.diag_section_to_clip(:perf)
      when :diag_map    then PokeAccess::Keys.diag_section_to_clip(:map)
      when :diag_scene  then PokeAccess::Keys.diag_section_to_clip(:scene)
      when :diag_full   then PokeAccess::Keys.diag_dump
      when :selfcheck   then PokeAccess::SelfCheck.run
      when :rec_toggle  then record_toggle
      end
    end

    # Starts the session recorder (saying its file) or stops it (saying how many events it captured).
    def self.record_toggle
      if PokeAccess::Recorder.recording?
        n = (PokeAccess::Recorder.stop rescue 0)
        say(t(:rec_stopped, :n => n))
      else
        name = (PokeAccess::Recorder.start rescue nil)
        say(name ? t(:rec_started, :file => name) : t(:rec_failed))
      end
    end

    # Restores every setting to its default, clears the key rebinds, saves, and returns to the top screen.
    def self.reset_defaults
      PokeAccess::Config::SCHEMA.each { |row| set_config(row[0], row[1]) }
      (PokeAccess::Config.rebinds.clear rescue (PokeAccess::Config.rebinds = {}))
      (PokeAccess::Settings.write rescue nil)
      @mode = :top; @index = 0; @stack = []
      say(t(:cfg_reset_done))
    end
  end
end
