module PokeAccess
  # The mod's spoken config menu: a modal loop over the map on the game's own buttons, with a stack of screens. This
  # file is the frame; the screens' rows live in config_rows (settings, sound glossary, debug), config_dicts
  # (Personalization), config_verbosity (verbosity schemes) and config_remap (key binding).
  module ConfigMenu
    @active = false
    @mode = :top
    @index = 0
    @capturing = false
    @armed = nil

    def self.t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

    def self.say(s); PokeAccess.speak(s, true, :system); end

    def self.active?; @active; end

    # Opens the menu over the map, holding control while it runs: the soundscape and the guides fall silent under it.
    def self.open
      return if @active
      unless PokeAccess::Control.scene_map?
        PokeAccess.speak(PokeAccess::I18n.t(:cfg_map_only), true, :system)
        return
      end
      @active = true; @mode = :top; @index = 0; @capturing = false; @stack = []; @armed = nil
      PokeAccess::Control.hold(:mod_menu) do
        say("#{t(:cfg)}. #{describe}")
        run_modal
      end
    end

    # The modal loop: drives Graphics and Input itself, so the map scene stays paused, until closed or off the map.
    def self.run_modal
      PokeAccess::Speech.as(:system) do
        loop do
          Graphics.update
          Input.update
          break unless @active
          break unless PokeAccess::Control.scene_map?
          step
        end
      end
      @active = false
    rescue StandardError => e
      @active = false
      PokeAccess.write_marker("config_menu: #{e.class}: #{e.message}\n")
    end

    # Closes the menu and saves the settings, saying whether settings.ini could be written.
    def self.close
      @active = false; @capturing = false
      stop_preview
      say(t(PokeAccess::Settings.write ? :cfg_saved : :cfg_not_saved))
    end

    # The current mode's rows, memoised per mode, entry, scheme, reading group, store write counters, recording state
    # (the debug row's label) and what decides which settings show: step asks for them several times a frame. The key
    # is stored only after a successful build.
    def self.items
      key = [@mode, @entry, @scheme, @reading_group, dict_rev, (PokeAccess::Recorder.recording? rescue false),
             PokeAccess::Config.visibility_key]
      return @items if @items && @items_key == key
      built = build_items
      @items_key = key
      @items = built
    end

    # Each item is a hash with :kind and the data that kind needs.
    def self.build_items
      case @mode
      when :top                                then top_rows
      when :sounds                             then sounds_rows
      when :personal                           then personal_rows
      when :dict_import, :dict_export          then transfer_rows(@mode == :dict_import ? :import : :export)
      when :list_tags, :list_marks, :list_maps then entry_rows(LIST_MODES[@mode])
      when :entry_actions                      then entry_action_rows(@entry)
      when :verbosity                          then verbosity_rows
      when :scheme_actions                     then scheme_action_rows
      when :scheme_use                         then scheme_use_rows
      when :scheme_edit                        then scheme_edit_rows
      when :reading_group                      then reading_group_rows(@reading_group)
      when :debug                              then debug_rows
      else group_rows(@mode)
      end
    end

    # What identifies a row across rebuilds: a setting by key, any other row by its kind and what it opens or runs.
    def self.row_id(item)
      return [:setting, item[:row].key] if item[:row]
      [item[:kind], item[:group] || item[:action] || item[:reading] || item[:name] || item[:op] || item[:label]]
    end

    # Puts the cursor back on the row with an id after the rows changed, or keeps it within the list.
    def self.refocus(id)
      list = items
      i = list.index { |it| row_id(it) == id }
      @index = i || [[@index, list.length - 1].min, 0].max
    end

    # The spoken name of a row.
    def self.label_of(item)
      case item[:kind]
      when :entry   then entry_label(item)
      when :scheme  then scheme_label(item[:name])
      when :reading then PokeAccess::Verbosity.reading_name(item[:reading])
      else t(item[:row] ? item[:row].label : item[:label])
      end
    end

    # A row as it is said: its name and, for a row that holds a value, the value.
    def self.describe(item = nil)
      item ||= items[@index]
      v = value_of(item)
      v ? "#{label_of(item)}, #{v}" : label_of(item)
    end

    # A row's value in words: a setting's, the cane guide's state, or a reading's level in the edited scheme; nil for
    # a row without one.
    def self.value_of(item)
      case item[:kind]
      when :setting then value_text(item[:row])
      when :guide   then t(PokeAccess::Guide.on?(:cane) ? :val_on : :val_off)
      when :reading then reading_level_text(item[:reading])
      end
    end

    # One modal frame: up/down move, left/right change the focused value, confirm enters/toggles/runs,
    # cancel goes back a level (or closes from the top), help says the row's help, and with ctrl the row whole.
    def self.step
      expire_preview
      return capture_step if @capturing
      return rebind_step if @mode == :remap
      help = (PokeAccess::Keys.key(:info) rescue false)
      n = items.length
      @index = 0 if @index >= n || @index < 0
      item = items[@index]
      if Input.repeat?(Input::DOWN)
        move(1)
      elsif Input.repeat?(Input::UP)
        move(-1)
      elsif Input.repeat?(Input::RIGHT)
        adjust(item, 1)
      elsif Input.repeat?(Input::LEFT)
        adjust(item, -1)
      elsif Input.trigger?(Input::C)
        activate(1)
      elsif Input.trigger?(Input::B)
        back_one
      elsif help
        (PokeAccess::Keys.ctrl_down? rescue false) ? speak_row_whole : speak_help
      end
    end

    # Moves the cursor one row (dir -1 up, 1 down), wrapping, which also drops a confirmation left pending.
    def self.move(dir)
      @armed = nil
      @index = (@index + dir) % items.length
      say(describe)
    end

    # Left or right on a row that holds a value: a setting, the cane guide, or a reading in the scheme editor.
    def self.adjust(item, dir)
      case item[:kind]
      when :setting then adjust_setting(item[:row], dir)
      when :guide   then PokeAccess::Guide.toggle(:cane)
      when :reading then adjust_reading(item[:reading], dir)
      end
    end

    # Opens a screen over the current one and says its title and first row.
    def self.enter(mode, title)
      @armed = nil
      @stack.push([@mode, @index]); @mode = mode; @index = 0
      say("#{title}. #{describe}")
    end

    # Goes back one level (pops the parent menu/cursor off the stack), or closes when at the top.
    def self.back_one
      @armed = nil
      return close if @stack.nil? || @stack.empty?
      @mode, @index = @stack.pop
      @index = [[@index, items.length - 1].min, 0].max
      say(describe)
    end

    # The info key on a row: its help (help_text).
    def self.speak_help
      say(help_text(items[@index]))
    end

    # Ctrl with the info key on a row: the row as it is said, its value too, then its help, in one line; the row
    # alone where its help is the row again.
    def self.speak_row_whole
      item = items[@index]
      row = describe(item)
      help = help_text(item)
      say(help == row ? row : "#{row}. #{help}")
    end

    # A row's help: a sound's, reading's, setting's or the row's own, else the row again.
    def self.help_text(item)
      case item[:kind]
      when :sound   then t(item[:entry].glossary[1], key_vars)
      when :reading then reading_help(item[:reading])
      when :setting then setting_help(item[:row])
      else item[:help] ? t(item[:help], key_vars) : describe(item)
      end
    end

    # The help texts' key variables (%{key_prev}...), each the name of the key bound now, or unassigned.
    def self.key_vars
      out = {}
      PokeAccess::Config.keys.each { |sym, code| out["key_#{sym}".to_sym] = code ? keyname(code) : t(:rmp_unassigned) }
      out
    end

    def self.activate(dir)
      item = items[@index]
      case item[:kind]
      when :enter
        enter(item[:group], t(item[:label]))
      when :reading_group
        @reading_group = item[:group]
        enter(:reading_group, t(item[:label]))
      when :remap
        @stack.push([@mode, @index]); @mode = :remap; @ri = 0
        say("#{t(:cat_remap)}. #{rebind_desc}")
      when :back
        back_one
      when :action
        run_action(item[:action])
      when :entry
        @entry = item
        enter(:entry_actions, entry_label(item))
      when :entry_action
        run_entry_action(item[:op])
      when :scheme
        @scheme = item[:name]
        enter(:scheme_actions, item[:name])
      when :scheme_action
        run_scheme_action(item[:op])
      when :note
        say(describe)
      when :sound
        PokeAccess::Sound::Glossary.play(item[:entry])
      when :setting
        adjust_setting(item[:row], dir)
      when :guide
        PokeAccess::Guide.toggle(:cane)
      when :reading
        adjust_reading(item[:reading], dir)
      end
    end
  end
end
