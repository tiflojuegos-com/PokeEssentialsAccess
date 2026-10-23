module PokeAccess
  # Config menu, the settings screens: the top list, each group with the settings it shows now and the groups that
  # hang from it, the sound glossary, debug, how a setting row reads and changes, and the reset of every setting.
  module ConfigMenu
    # How long a looping sample (water, wind) auditions before the menu stops it.
    PREVIEW_LOOP_SECONDS = 2.0

    # Auditions a volume or tone row (Sound::Glossary.preview_of), positionally if the engine is up, else as the flat
    # glossary sample: a family's volume row at the value just set, a tone or master row at the family's own volume,
    # its sound switched on or not; the master row's flat sample scaled by the master just set, silent at 0.
    def self.preview(key, kind, v)
      gl = PokeAccess::Sound::Glossary
      entry = gl.entry(gl.preview_of(key))
      return unless entry
      master = key == :audio3d_volume
      own = kind == :vol && !master
      vol = own ? v : (PokeAccess::Sound::Mixer.level(entry.id) || 100)
      stop_preview
      return if vol <= 0 || (master && v <= 0)
      played = (PokeAccess::Sound.preview(entry.id, vol, gl.engine_pitch(entry)) rescue false)
      return gl.play(entry, master ? vol * v / 100 : vol) unless played
      @preview = [entry.id, PokeAccess.clock + PREVIEW_LOOP_SECONDS] if PokeAccess::Sound.loop?(entry.id)
    end

    # Ends a looping audition whose time is up (called every modal frame).
    def self.expire_preview
      stop_preview if @preview && PokeAccess.clock >= @preview[1]
    end

    # Stops the looping audition, if one plays (the menu is closing or its time is up).
    def self.stop_preview
      return unless @preview
      (PokeAccess::Sound.preview_stop(@preview[0]) rescue nil)
      @preview = nil
    end

    # What each screen the top list or a group opens holds, by its mode, as the info key says it over the row that
    # opens it.
    SCREEN_HELP = {
      :general => :cat_general_help, :pathfinder => :cat_pathfinder_help, :pathfinder_adv => :cat_nav_adv_help,
      :audio => :cat_audio_help, :audio3d_on => :cat_sounds_on_help, :audio3d_vol => :cat_pos_vol_help,
      :audio3d_freq => :cat_pos_freq_help, :audio3d_tone => :cat_pos_tone_help, :audio3d_walls => :cat_pos_walls_help,
      :audio3d_adv => :cat_positional_adv_help, :debug => :cat_debug_help, :sounds => :cat_sounds_help,
      :personal => :cat_personal_help, :remap => :cat_remap_help
    }

    # The row that opens a screen: its mode, its label and what it holds.
    def self.screen_row(mode, label)
      { :kind => :enter, :group => mode, :label => label, :help => SCREEN_HELP[mode] }
    end

    # The top level: the setting groups that have something to show, then the menu's own screens and the reset.
    def self.top_rows
      rows = shown_groups(:top).map { |g| screen_row(g.id, g.label) }
      rows.push(screen_row(:sounds, :cat_sounds))
      rows.push(screen_row(:personal, :cat_personal))
      rows.push({ :kind => :remap, :label => :cat_remap, :help => SCREEN_HELP[:remap] })
      rows.push(screen_row(:debug, :cat_debug))
      rows.push({ :kind => :action, :action => :reset, :label => :cat_reset })
      rows
    end

    # The sound glossary: one audition row per entry.
    def self.sounds_rows
      rows = PokeAccess::Sound::Glossary.entries.map { |e| { :kind => :sound, :entry => e, :label => e.glossary[0] } }
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
      rows.concat(setting_rows(:debug))
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The cane guide's row among the sound switches: whether Shift+I has the cane on, switched as the key switches it
    # (a live state, never saved).
    GUIDE_ROW = { :kind => :guide, :label => :lbl_on_guide, :help => :help_on_guide }

    # A group's screen: the settings it shows now (the sound switches with the guide's row where its family stands,
    # before the jumps'), the groups that hang from it with something to show, then back.
    def self.group_rows(group)
      rows = setting_rows(group)
      if group == :audio3d_on
        i = rows.index { |r| r[:row].key == :sound_jumps }
        rows.insert(i || rows.length, GUIDE_ROW)
      end
      shown_groups(group).each { |g| rows.push(screen_row(g.id, g.label)) }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The rows of a group's settings the menu shows now.
    def self.setting_rows(group)
      PokeAccess::Config.settings_in(group).select { |s| PokeAccess::Config.visible?(s) }.map { |s| { :kind => :setting, :row => s } }
    end

    # The groups hanging from a parent that have a setting to show, themselves or further down.
    def self.shown_groups(parent)
      PokeAccess::Config.groups_in(parent).select { |g| group_shown?(g.id) }
    end

    # Whether a group has a setting the menu shows now, in it or in a group under it.
    def self.group_shown?(id)
      PokeAccess::Config.settings_in(id).any? { |s| PokeAccess::Config.visible?(s) } ||
        PokeAccess::Config.groups_in(id).any? { |g| group_shown?(g.id) }
    end

    # A setting's value in words.
    def self.value_text(row)
      PokeAccess::Config.value_name(row, PokeAccess::Config.send(row.key))
    end

    # A setting's help, as the info key reads it: the chosen search algorithm's own for the algorithm row, else
    # the row's help with the mod's keys named as the player has them, or the row itself when it has none.
    def self.setting_help(row)
      return t("help_algo_#{PokeAccess::Config.send(row.key)}".to_sym) if row.kind == :algo
      row.help ? t(row.help, key_vars) : describe
    end

    # Moves a setting one step (dir -1 or 1), auditions a volume or tone, says the setting and keeps the focus on it
    # while other rows appear or go.
    def self.adjust_setting(row, dir)
      v = PokeAccess::Config.set(row.key, PokeAccess::Config.next_value(row, dir))
      preview(row.key, row.kind, v) if PokeAccess::Sound::Glossary.preview_of(row.key)
      refocus([:setting, row.key])
      say("#{t(row.label)}, #{PokeAccess::Config.value_name(row, v)}")
    end

    def self.run_action(a)
      return run_transfer(a[0], a[1]) if a.is_a?(Array)
      case a
      when :reset then reset_defaults
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

    # Restores every setting to its default on a second press of its row (the first asks), saves and keeps the focus
    # on its row while the top screen's groups appear or go. The language and the keys stay as they are: the keys
    # have their own reset.
    def self.reset_defaults
      unless @armed == :reset
        @armed = :reset
        return say(t(:cfg_reset_confirm))
      end
      @armed = nil
      PokeAccess::Config.restore_defaults
      (PokeAccess::Settings.write rescue nil)
      refocus([:action, :reset])
      say(t(:cfg_reset_done))
    end
  end
end
