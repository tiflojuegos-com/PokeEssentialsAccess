module PokeAccess
  # Spoken config menu, navigated with mod keys over the live game. Two levels: a top list of
  # categories and, inside each, its settings. :prev/:next move; :where/:route lower/raise a
  # value, toggle a flag, cycle the language, enter a category or run an action; :info reads the
  # focused setting's help; :config goes back a level or closes from the top. Every label and
  # message is a localization key resolved through I18n. The remapper binds the next key pressed.
  module ConfigMenu
    KEYNAMES = {
      0x08 => :key_backspace, 0x09 => :key_tab, 0x0D => :key_enter, 0x10 => :key_shift,
      0x11 => :key_control, 0x12 => :key_alt, 0x1B => :key_escape, 0x20 => :key_space,
      0x25 => :key_arrow_left, 0x26 => :key_arrow_up, 0x27 => :key_arrow_right,
      0x28 => :key_arrow_down
    }
    SCAN_CODES = [0x08, 0x09, 0x0D, 0x1B, 0x20, 0x21, 0x22, 0x23, 0x24,
                  0x25, 0x26, 0x27, 0x28, 0x2D, 0x2E, 0x10, 0x11, 0x12,
                  0xBA, 0xBB, 0xBC, 0xBD, 0xBE, 0xBF, 0xC0,
                  0xDB, 0xDC, 0xDD, 0xDE]
    SCAN_CODES.concat((0x30..0x39).to_a)
    SCAN_CODES.concat((0x41..0x5A).to_a)
    SCAN_CODES.concat((0x60..0x6F).to_a)
    SCAN_CODES.concat((0x70..0x87).to_a)
    @active = false
    @mode = :top
    @index = 0
    @ri = 0
    @capturing = false
    @cap_down = {}
    @preview = nil

    # Setting => the glossary sound that demonstrates it: a volume or tone row plays its family's sample as
    # the value moves, so the player hears the level or the pitch instead of only a number.
    PREVIEWS = {
      :audio3d_volume => :npc, :audio3d_npc => :npc, :audio3d_object => :object, :audio3d_door => :door,
      :audio3d_teleporter => :teleporter, :audio3d_mark => :mark, :audio3d_water => :water, :audio3d_wind => :wind_n,
      :footstep_volume => :step, :wall_volume => :wall, :event_volume => :guide,
      :audio3d_tone_npc => :npc, :audio3d_tone_object => :object, :audio3d_tone_door => :door,
      :audio3d_tone_teleporter => :teleporter, :audio3d_tone_mark => :mark, :audio3d_tone_water => :water, :audio3d_tone_wind => :wind_n,
      :footstep_tone => :step, :wall_tone => :wall, :guide_tone => :guide
    }

    # Glossary sound => the volume setting its family plays at in the field, so an audition that is not
    # about that volume (a tone row, the master row) sounds as loud as the field will.
    FAMILY_VOLUME = {
      :npc => :audio3d_npc, :object => :audio3d_object, :door => :audio3d_door, :teleporter => :audio3d_teleporter,
      :mark => :audio3d_mark,
      :water => :audio3d_water, :wind_n => :audio3d_wind, :step => :footstep_volume, :wall => :wall_volume,
      :guide => :event_volume
    }

    # How long a looping sample (water, wind) auditions before the menu stops it.
    PREVIEW_LOOP_SECONDS = 2.0

    # The three shareable dictionaries as the menu sees them: the store module, the label of its list, and
    # the labels and result messages of its import and export. One table drives the import submenu, the
    # export submenu and the three editable lists, so a fourth dictionary is one more row and nothing else.
    DICTS = {
      :tags  => { :mod => PokeAccess::Tags, :list => :cat_list_tags,
                  :import => :act_import, :import_done => :act_import_done,
                  :export => :act_export, :export_done => :act_export_done, :export_none => :act_export_none },
      :marks => { :mod => PokeAccess::Marks, :list => :cat_list_marks,
                  :import => :act_import_marks, :import_done => :act_import_marks_done,
                  :export => :act_export_marks, :export_done => :act_export_marks_done, :export_none => :act_export_marks_none },
      :maps  => { :mod => PokeAccess::MapNames, :list => :cat_list_maps,
                  :import => :act_import_maps, :import_done => :act_import_maps_done,
                  :export => :act_export_maps, :export_done => :act_export_maps_done, :export_none => :act_export_maps_none }
    }
    # The order the dictionaries are offered in (a 1.8.7 Hash keeps none).
    DICT_ORDER = [:tags, :marks, :maps]
    # Menu mode => the dictionary whose entries it lists.
    LIST_MODES = { :list_tags => :tags, :list_marks => :marks, :list_maps => :maps }

    def self.t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

    def self.say(s); PokeAccess.speak(s, true); end

    def self.active?; @active; end

    def self.open
      return if @active
      unless ($scene.is_a?(Scene_Map) rescue true)
        PokeAccess.speak(PokeAccess::I18n.t(:cfg_map_only), true)
        return
      end
      @active = true; @mode = :top; @index = 0; @capturing = false; @stack = []
      (PokeAccess::Audio3D.suspend rescue nil)
      say("#{t(:cfg)}. #{describe}")
      run_modal
    end

    # Runs the menu as a modal loop driving Graphics/Input itself, so the map scene (player, footsteps,
    # positional audio) stays paused. Reads the GAME's buttons, so navigation uses the player's own
    # controls and any rebinds work for free.
    def self.run_modal
      loop do
        Graphics.update
        Input.update
        break unless @active
        break unless ($scene.is_a?(Scene_Map) rescue false)
        step
      end
      @active = false
    rescue StandardError => e
      @active = false
      PokeAccess.write_marker("config_menu: #{e.class}: #{e.message}\n")
    end

    def self.close
      @active = false; @capturing = false
      stop_preview
      (PokeAccess::Settings.write rescue nil)
      say(t(:cfg_saved))
    end

    # Auditions a volume or tone row: through the positional engine when it is up (the whole octave, centred
    # on the player), else through the flat glossary preview. A family's volume row plays at the value just
    # set; a tone row, and the master row, play at the family's own volume, so between two presses only the
    # thing being adjusted changes and the sample is as loud as the field will be.
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

    # The items of the current mode. Each is a hash with :kind and the data that kind needs.
    def self.items
      case @mode
      when :top
        list = PokeAccess::Config::CATEGORIES.map { |g, label| { :kind => :enter, :group => g, :label => label } }
        list.push({ :kind => :enter, :group => :sounds, :label => :cat_sounds })
        list.push({ :kind => :enter, :group => :tags, :label => :cat_tags })
        list.push({ :kind => :remap, :label => :cat_remap })
        list.push({ :kind => :enter, :group => :debug, :label => :cat_debug })
        list.push({ :kind => :action, :action => :reset, :label => :cat_reset })
        list
      when :sounds
        rows = PokeAccess::SoundGlossary.entries.map do |e|
          { :kind => :sound, :entry => e, :label => e[2] }
        end
        rows.push({ :kind => :back, :label => :back })
        rows
      when :tags
        rows = [{ :kind => :enter, :group => :dict_import, :label => :cat_import },
                { :kind => :enter, :group => :dict_export, :label => :cat_export }]
        DICT_ORDER.each { |d| rows.push({ :kind => :enter, :group => LIST_MODES.invert[d], :label => DICTS[d][:list] }) }
        rows.push({ :kind => :back, :label => :back })
        rows
      when :dict_import, :dict_export
        transfer_rows(@mode == :dict_import ? :import : :export)
      when :list_tags, :list_marks, :list_maps
        entry_rows(LIST_MODES[@mode])
      when :entry_actions
        entry_action_rows(@entry)
      when :debug
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
      when :pathfinder
        rows = PokeAccess::Config.schema_group(:pathfinder).map { |r| { :kind => :setting, :row => r } }
        rows.push({ :kind => :enter, :group => :pathfinder_adv, :label => :cat_nav_adv })
        rows.push({ :kind => :back, :label => :back })
        rows
      when :audio
        rows = PokeAccess::Config.schema_group(:audio).map { |r| { :kind => :setting, :row => r } }
        rows.push({ :kind => :enter, :group => :audio3d_vol,   :label => :cat_pos_vol })
        rows.push({ :kind => :enter, :group => :audio3d_freq,  :label => :cat_pos_freq })
        rows.push({ :kind => :enter, :group => :audio3d_tone,  :label => :cat_pos_tone })
        rows.push({ :kind => :enter, :group => :audio3d_walls, :label => :cat_pos_walls })
        rows.push({ :kind => :enter, :group => :audio3d_adv,   :label => :cat_positional_adv })
        rows.push({ :kind => :back, :label => :back })
        rows
      else
        rows = PokeAccess::Config.schema_group(@mode).map { |r| { :kind => :setting, :row => r } }
        rows.push({ :kind => :back, :label => :back })
        rows
      end
    end

    def self.label_of(item)
      return entry_label(item) if item[:kind] == :entry
      t(item[:row] ? item[:row][4] : item[:label])
    end

    # The import or export submenu: one action per dictionary, then all of them at once.
    def self.transfer_rows(op)
      rows = DICT_ORDER.map { |d| { :kind => :action, :action => [op, d], :label => DICTS[d][op] } }
      rows.push({ :kind => :action, :action => [op, :all], :label => (op == :import ? :act_import_all : :act_export_all) })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The editable list of one dictionary: an :entry row per record (with what the actions need to find it
    # again), a note when there is nothing yet, and back. Guarded per dictionary so a store that fails to
    # load still shows an empty, navigable list.
    def self.entry_rows(dict)
      rows = []
      begin
        case dict
        when :tags
          PokeAccess::Tags.each_record { |mid, eid, r| rows.push({ :kind => :entry, :dict => :tags, :key => [mid, eid], :rec => r }) }
        when :marks
          PokeAccess::Marks.each_mark { |mid, x, y, nm| rows.push({ :kind => :entry, :dict => :marks, :key => [mid, x, y], :name => nm }) }
        when :maps
          PokeAccess::MapNames.each_name { |mid, nm| rows.push({ :kind => :entry, :dict => :maps, :key => mid, :name => nm }) }
        end
      rescue StandardError
        rows = []
      end
      rows.push({ :kind => :note, :label => :list_empty }) if rows.empty?
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # What can be done to the focused entry: show it again (a hidden object only), rename it, forget it.
    def self.entry_action_rows(item)
      rows = []
      return [{ :kind => :back, :label => :back }] unless item
      rows.push({ :kind => :entry_action, :op => :show, :label => :entry_show }) if item[:dict] == :tags && item[:rec]["hidden"]
      rows.push({ :kind => :entry_action, :op => :rename, :label => :tag_rename })
      rows.push({ :kind => :entry_action, :op => :forget, :label => :entry_forget })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The spoken label of a list entry: where it is and what it is called, so two "Puerta" on different maps
    # can be told apart, and a hidden object says so.
    def self.entry_label(item)
      case item[:dict]
      when :tags
        nm = item[:rec]["name"]
        nm = t(:loc_object) if nm.nil? || nm.to_s.empty?
        s = t(:entry_tag, :map => map_label(item[:key][0]), :name => nm)
        item[:rec]["hidden"] ? "#{s}, #{t(:entry_hidden)}" : s
      when :marks
        t(:entry_mark, :map => map_label(item[:key][0]), :name => item[:name], :x => item[:key][1], :y => item[:key][2])
      when :maps
        t(:entry_map, :name => item[:name], :id => item[:key])
      else
        ""
      end
    end

    # A map's spoken name for a list entry, "?" when the game names it nothing.
    def self.map_label(mid)
      nm = (PokeAccess::Locator.map_name(mid) rescue nil)
      (nm.nil? || nm.to_s.empty?) ? "?" : nm
    end

    def self.value_text(row)
      v = PokeAccess::Config.send(row[0])
      case row[2]
      when :flag  then v ? t(:val_on) : t(:val_off)
      when :lang  then PokeAccess::I18n.language_name(v)
      when :sec   then "#{v} #{t(:secs)}"
      when :tiles, :reach, :desk, :gdist then "#{v} #{t(:tiles_unit)}"
      when :ms    then "#{v} #{t(:ms_unit)}"
      when :astar then v.to_s
      when :algo  then t("algo_#{v}".to_sym)
      when :occ   then t("occ_#{v}".to_sym)
      when :navmode then t("nav_#{v}".to_sym)
      else v.to_s
      end
    end

    def self.describe(item = nil)
      item ||= items[@index]
      return label_of(item) unless item[:kind] == :setting
      "#{label_of(item)}, #{value_text(item[:row])}"
    end

    # One modal frame: up/down move, left/right change the focused value, confirm enters/toggles/runs,
    # cancel goes back a level (or closes from the top), help re-reads the description.
    def self.step
      expire_preview
      return capture_step if @capturing
      return rebind_step if @mode == :remap
      help = (PokeAccess::Keys.key(:info) rescue false)
      n = items.length
      @index = 0 if @index >= n || @index < 0
      item = items[@index]
      if Input.repeat?(Input::DOWN)
        @index = (@index + 1) % n; say(describe)
      elsif Input.repeat?(Input::UP)
        @index = (@index - 1) % n; say(describe)
      elsif Input.repeat?(Input::RIGHT)
        adjust_setting(item[:row], 1) if item[:kind] == :setting
      elsif Input.repeat?(Input::LEFT)
        adjust_setting(item[:row], -1) if item[:kind] == :setting
      elsif Input.trigger?(Input::C)
        activate(1)
      elsif Input.trigger?(Input::B)
        back_one
      elsif help
        speak_help
      end
    end

    # Goes back one level (pops the parent menu/cursor off the stack), or closes when at the top.
    def self.back_one
      if @stack.nil? || @stack.empty?
        close
      else
        @mode, @index = @stack.pop
        say(describe)
      end
    end

    def self.speak_help
      item = items[@index]
      return say(t(item[:entry][3])) if item[:kind] == :sound
      if item[:kind] == :setting && item[:row][2] == :algo
        return say(t("help_algo_#{PokeAccess::Config.send(item[:row][0])}".to_sym))
      end
      (item[:kind] == :setting && item[:row][5]) ? say(t(item[:row][5])) : say(describe)
    end

    def self.activate(dir)
      item = items[@index]
      case item[:kind]
      when :enter
        @stack.push([@mode, @index]); @mode = item[:group]; @index = 0
        say("#{t(item[:label])}. #{describe}")
      when :remap
        @stack.push([@mode, @index]); @mode = :remap; @ri = 0
        say("#{t(:cat_remap)}. #{rebind_desc}")
      when :back
        back_one
      when :action
        run_action(item[:action])
      when :entry
        @stack.push([@mode, @index]); @entry = item; @mode = :entry_actions; @index = 0
        say("#{entry_label(item)}. #{describe}")
      when :entry_action
        run_entry_action(item[:op])
      when :note
        say(describe)
      when :sound
        PokeAccess::SoundGlossary.play(item[:entry])
      when :setting
        adjust_setting(item[:row], dir)
      end
    end

    # Starts or stops the session recorder, saying the file it wrote (a tester reads the name back to
    # whoever asked for it) or how many events it captured.
    def self.record_toggle
      if PokeAccess::Recorder.recording?
        n = (PokeAccess::Recorder.stop rescue 0)
        say(t(:rec_stopped, :n => n))
      else
        name = (PokeAccess::Recorder.start rescue nil)
        say(name ? t(:rec_started, :file => name) : t(:rec_failed))
      end
    end

    # Applies one action to the focused entry, tells the locator its overrides changed, and drops back to the
    # list -- which is rebuilt, so a forgotten entry is gone from it. The result is spoken first and the
    # list position queued behind it, so neither cuts the other off.
    def self.run_entry_action(op)
      item = @entry
      name = entry_label(item)
      case op
      when :show
        PokeAccess::Tags.set_hidden(item[:key][0], item[:key][1], false)
        say(t(:unhidden, :name => name))
      when :rename
        rename_entry(item)
      when :forget
        forget_entry(item)
        say(t(:entry_forgotten, :name => name))
      end
      PokeAccess::Events.emit(:tags_changed)
      @mode, @index = @stack.pop unless @stack.nil? || @stack.empty?
      @index = 0 if @index >= items.length
      PokeAccess.speak(describe, false)
    rescue StandardError => e
      PokeAccess.write_marker("config_menu entry #{op}: #{e.class}: #{e.message}\n")
    end

    # Renames the focused entry through the same prompt the map keys use, so the wording and the
    # blank-clears rule are the ones the player already knows.
    def self.rename_entry(item)
      key = item[:key]
      case item[:dict]
      when :tags
        cur = (PokeAccess::Tags.get(key[0], key[1]) rescue nil).to_s
        PokeAccess::Locator.prompt_rename(entry_label(item), cur,
          [:loc_label_for, :loc_label_prompt, :loc_label_removed, :loc_label_saved]) { |v| PokeAccess::Tags.set(key[0], key[1], v) }
      when :marks
        cur = item[:name].to_s
        PokeAccess::Locator.prompt_rename(cur, cur,
          [:mark_edit_for, :mark_prompt, :mark_removed, :mark_saved]) { |v| PokeAccess::Marks.set(key[0], key[1], key[2], v) }
      when :maps
        cur = item[:name].to_s
        PokeAccess::Locator.prompt_rename(cur, cur,
          [:map_label_for, :map_label_prompt, :map_label_removed, :map_label_saved]) { |v| PokeAccess::MapNames.set(key, v) }
      end
    end

    # Forgets the focused entry in its dictionary.
    def self.forget_entry(item)
      key = item[:key]
      case item[:dict]
      when :tags  then PokeAccess::Tags.delete(key[0], key[1])
      when :marks then PokeAccess::Marks.delete(key[0], key[1], key[2])
      when :maps  then PokeAccess::MapNames.delete(key)
      end
    end

    # Runs one dictionary's import or export -- or every dictionary's, for the "all" rows -- and speaks what
    # happened to each, in order.
    def self.run_transfer(op, which)
      list = which == :all ? DICT_ORDER : [which]
      say(list.map { |d| op == :import ? import_one(d) : export_one(d) }.join(". "))
    end

    # Exports one dictionary; the message names the count or that there was nothing.
    def self.export_one(d)
      n = (DICTS[d][:mod].export rescue nil)
      n ? t(DICTS[d][:export_done], :n => n) : t(DICTS[d][:export_none])
    end

    # Imports one dictionary, refusing a file stamped with another game's name: the keys are map ids, so a
    # foreign file would label the wrong things everywhere without a single error.
    def self.import_one(d)
      mod = DICTS[d][:mod]
      file = File.basename(mod.const_get(:IMPORT))
      status, game = (mod.import_status rescue [:none])
      case status
      when :none    then t(:act_import_none, :file => file)
      when :foreign then t(:act_import_foreign, :file => file, :game => game, :mine => (PokeAccess::Game.profile_name rescue "?"))
      else
        n = (mod.import_now rescue 0)
        PokeAccess::Events.emit(:tags_changed)
        t(DICTS[d][:import_done], :n => n)
      end
    end

    # The ONE path that writes a setting from the menu: assigns and drops the locator's event verdicts,
    # whose answers can depend on a setting (transfer_active_page_only), so no toggle serves a stale one.
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
        unit = b[3] ? " #{t(b[3])}" : ""
        return say("#{t(row[4])}, #{v}#{unit}")
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

    # Restores every setting (and key rebinds) to its default and persists it, so the player can undo any
    # tweak in one step; returns to the top so the index cannot point past a shorter list.
    def self.reset_defaults
      PokeAccess::Config::SCHEMA.each { |row| set_config(row[0], row[1]) }
      (PokeAccess::Config.rebinds.clear rescue (PokeAccess::Config.rebinds = {}))
      (PokeAccess::Settings.write rescue nil)
      @mode = :top; @index = 0; @stack = []
      say(t(:cfg_reset_done))
    end

    #--- remap submenu (binds an extra key on top of native input, never replacing it) ---

    # The remap submenu's per-frame step. After a capture it swallows input until the just-pressed key
    # is released, so a held key cannot immediately re-trigger capture or clear-binding.
    def self.rebind_step
      if @cap_wait
        return if down?(@cap_wait)
        @cap_wait = nil
      end
      n = PokeAccess::Remap.buttons.length
      if Input.trigger?(Input::B)
        back_one
      elsif Input.repeat?(Input::UP)
        @ri = (@ri - 1) % n; say(rebind_desc)
      elsif Input.repeat?(Input::DOWN)
        @ri = (@ri + 1) % n; say(rebind_desc)
      elsif PokeAccess::Remap.buttons[@ri][0] == :__reset__
        reset_all if Input.trigger?(Input::C)
      elsif Input.trigger?(Input::C)
        start_capture
      elsif Input.trigger?(Input::LEFT)
        clear_binding
      end
    end

    def self.rebind_desc
      sym = PokeAccess::Remap.buttons[@ri][0]
      return t(:rmp_reset) if sym == :__reset__
      code = if PokeAccess::Remap.mod_action?(sym)
        (PokeAccess::Config.keys[sym] rescue nil)
      else
        (PokeAccess::Config.rebinds[sym] rescue nil)
      end
      t(:rmp_entry, :action => PokeAccess::Remap.label(sym), :key => (code ? keyname(code) : t(:rmp_unassigned)))
    end

    # Restores BOTH tables: the game rebinds go away (the engine's native keys take over) and the mod's own
    # keys return to their shipped values. This is the way back from any binding mess, so it must not leave
    # half of them wrong -- and the gesture that opens this menu is itself remappable now.
    def self.reset_all
      (PokeAccess::Config.rebinds.clear rescue (PokeAccess::Config.rebinds = {}))
      (PokeAccess::Config.keys = PokeAccess::Config::KEY_DEFAULTS.dup rescue nil)
      (PokeAccess::Settings.write rescue nil)
      say(t(:rmp_all_reset))
    end

    # Left on an entry: for a GAME button, unbind it and let the engine's native key take over again. For a
    # MOD key there is no native key to fall back to -- unbound, the action would simply stop existing --
    # so the same gesture restores its shipped default instead.
    def self.clear_binding
      sym = PokeAccess::Remap.buttons[@ri][0]
      if PokeAccess::Remap.mod_action?(sym)
        deflt = PokeAccess::Config::KEY_DEFAULTS[sym]
        changed = deflt && PokeAccess::Config.keys[sym] != deflt
        PokeAccess::Config.keys[sym] = deflt if deflt
        (PokeAccess::Settings.write rescue nil)
        return say(changed ? t(:rmp_restored, :action => PokeAccess::Remap.label(sym)) : t(:rmp_none))
      end
      had = (PokeAccess::Config.rebinds[sym] rescue nil)
      (PokeAccess::Config.rebinds.delete(sym) rescue nil)
      (PokeAccess::Settings.write rescue nil)
      say(had ? t(:rmp_cleared, :action => PokeAccess::Remap.label(sym)) : t(:rmp_none))
    end

    def self.start_capture
      @capturing = true
      @cap_tick = 0
      @cap_down = {}
      SCAN_CODES.each { |c| @cap_down[c] = down?(c) }
      say(t(:rmp_press, :action => PokeAccess::Remap.label(PokeAccess::Remap.buttons[@ri][0])))
    end

    # One frame of key capture while rebinding: cancel, or take the first key pressed and bind it unless
    # Remap reports a conflict. Remap.conflict is ONE check across BOTH tables, so the game's A cannot be
    # bound to a key the mod already owns and silently make it do two things.
    def self.capture_step
      if Input.trigger?(Input::B)
        @capturing = false
        return say(t(:cancelled))
      end
      @cap_tick = (@cap_tick.to_i + 1) % 3
      return unless @cap_tick == 0
      SCAN_CODES.each do |c|
        if down?(c) && !@cap_down[c]
          sym = PokeAccess::Remap.buttons[@ri][0]
          other = PokeAccess::Remap.conflict(c, sym)
          if other
            @capturing = false
            @cap_wait = c
            taken = PokeAccess::Remap::RESERVED.has_key?(c) ? t(other) : PokeAccess::Remap.label(other)
            return say(t(:rmp_inuse, :key => keyname(c), :action => taken))
          end
          if PokeAccess::Remap.mod_action?(sym)
            PokeAccess::Config.keys[sym] = c
          else
            PokeAccess::Config.rebinds[sym] = c
          end
          @capturing = false
          @cap_wait = c
          (PokeAccess::Settings.write rescue nil)
          return say(t(:rmp_assigned, :action => PokeAccess::Remap.label(sym), :key => keyname(c)))
        end
      end
    end

    # Raw physical state of a virtual-key, for the capture loop. Rebinding must read the KEYBOARD, not the
    # engine's buttons (the whole point is to catch a key the engine does not map yet), and it must work
    # while the mod's own input gate is closed -- so it goes to Keyboard, the one owner of that question.
    def self.down?(c); PokeAccess::Keyboard.raw_down?(c); end

    def self.keyname(c)
      return t(KEYNAMES[c]) if KEYNAMES[c]
      return (c - 0x30).to_s if c >= 0x30 && c <= 0x39
      return c.chr if c >= 0x41 && c <= 0x5A
      return t(:key_numpad, :n => c - 0x60) if c >= 0x60 && c <= 0x69
      return t(:key_f, :n => c - 0x6F) if c >= 0x70 && c <= 0x7B
      t(:key_other, :n => c)
    end
  end
end
