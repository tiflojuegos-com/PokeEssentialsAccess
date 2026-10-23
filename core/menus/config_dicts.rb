module PokeAccess
  # Config menu, Personalization: the verbosity schemes, an editable list per dictionary (tags, marks, map names)
  # and the import and export of all of them; the verbosity screen itself is in config_verbosity.
  module ConfigMenu
    # Each shareable store: its module, its editable list's label and help (none for the schemes, listed on their own
    # screen), and its import's and export's labels, helps and result lines.
    DICTS = {
      :tags    => { :mod => PokeAccess::Tags, :list => :cat_list_tags, :list_help => :cat_list_tags_help,
                    :import => :act_import, :import_help => :act_import_help, :import_done => :act_import_done,
                    :export => :act_export, :export_help => :act_export_help, :export_done => :act_export_done,
                    :export_none => :act_export_none },
      :marks   => { :mod => PokeAccess::Marks, :list => :cat_list_marks, :list_help => :cat_list_marks_help,
                    :import => :act_import_marks, :import_help => :act_import_marks_help,
                    :import_done => :act_import_marks_done,
                    :export => :act_export_marks, :export_help => :act_export_marks_help,
                    :export_done => :act_export_marks_done, :export_none => :act_export_marks_none },
      :maps    => { :mod => PokeAccess::MapNames, :list => :cat_list_maps, :list_help => :cat_list_maps_help,
                    :import => :act_import_maps, :import_help => :act_import_maps_help,
                    :import_done => :act_import_maps_done,
                    :export => :act_export_maps, :export_help => :act_export_maps_help,
                    :export_done => :act_export_maps_done, :export_none => :act_export_maps_none },
      :schemes => { :mod => PokeAccess::VerbositySchemes,
                    :import => :act_import_schemes, :import_help => :act_import_schemes_help,
                    :import_done => :act_import_schemes_done,
                    :export => :act_export_schemes, :export_help => :act_export_schemes_help,
                    :export_done => :act_export_schemes_done, :export_none => :act_export_schemes_none }
    }
    # The order the stores are offered in (a 1.8.7 Hash keeps none).
    DICT_ORDER = [:tags, :marks, :maps, :schemes]
    # Menu mode => the dictionary whose entries it lists.
    LIST_MODES = { :list_tags => :tags, :list_marks => :marks, :list_maps => :maps }
    # LIST_MODES inverted, precomputed rather than inverted on every row rebuild.
    MODE_OF_DICT = { :tags => :list_tags, :marks => :list_marks, :maps => :list_maps }

    # The stores' write counters summed into one key, bumped by every save and reload of any of them.
    def self.dict_rev
      DICT_ORDER.inject(0) { |sum, d| sum + (DICTS[d][:mod].rev rescue 0) }
    end

    # The Personalization rows, each with what the info key says over it: the verbosity schemes, an editable list per
    # dictionary, import, export and back.
    def self.personal_rows
      rows = [{ :kind => :enter, :group => :verbosity, :label => :cat_verbosity, :help => :cat_verbosity_help }]
      DICT_ORDER.each do |d|
        dict = DICTS[d]
        next unless dict[:list]
        rows.push({ :kind => :enter, :group => MODE_OF_DICT[d], :label => dict[:list], :help => dict[:list_help] })
      end
      rows.push({ :kind => :enter, :group => :dict_import, :label => :cat_import, :help => :cat_import_help })
      rows.push({ :kind => :enter, :group => :dict_export, :label => :cat_export, :help => :cat_export_help })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The import or export submenu: one action per store, then all of them at once, each with its help.
    def self.transfer_rows(op)
      help = op == :import ? :import_help : :export_help
      rows = DICT_ORDER.map do |d|
        { :kind => :action, :action => [op, d], :label => DICTS[d][op], :help => DICTS[d][help] }
      end
      all = op == :import ? [:act_import_all, :act_import_all_help] : [:act_export_all, :act_export_all_help]
      rows.push({ :kind => :action, :action => [op, :all], :label => all[0], :help => all[1] })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # One dictionary's editable list: an :entry row per record (keyed to find it again), a note when empty, and back.
    # A store that fails to load lists as empty.
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
      rescue StandardError => e
        PokeAccess.swallowed(e)
        rows = []
      end
      rows.push({ :kind => :note, :label => :list_empty }) if rows.empty?
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # What can be done to the focused entry, each with its help: show it again (a hidden object only), rename it,
    # forget it.
    def self.entry_action_rows(item)
      rows = []
      return [{ :kind => :back, :label => :back }] unless item
      if item[:dict] == :tags && item[:rec]["hidden"]
        rows.push({ :kind => :entry_action, :op => :show, :label => :entry_show, :help => :entry_show_help })
      end
      rows.push({ :kind => :entry_action, :op => :rename, :label => :tag_rename, :help => :tag_rename_help })
      rows.push({ :kind => :entry_action, :op => :forget, :label => :entry_forget, :help => :entry_forget_help })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # A list entry as spoken: map and name (a hidden tag says so, a mark adds its x, y), or a map's name and id.
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

    # Applies an action to the focused entry, emits :tags_changed and goes back to the list: the result spoken, then
    # the list position queued.
    def self.run_entry_action(op)
      item = @entry
      case op
      when :show
        PokeAccess::Tags.set_hidden(item[:key][0], item[:key][1], false)
        say(t(:unhidden, :name => entry_label(item)))
      when :rename
        rename_entry(item)
      when :forget
        name = entry_label(item)
        forget_entry(item)
        say(t(:entry_forgotten, :name => name))
      end
      PokeAccess::Events.emit(:tags_changed)
      @mode, @index = @stack.pop unless @stack.nil? || @stack.empty?
      @index = 0 if @index >= items.length
      PokeAccess.speak(describe, false, :system)
    rescue StandardError => e
      PokeAccess.write_marker("config_menu entry #{op}: #{e.class}: #{e.message}\n")
    end

    # Renames the focused entry through the map keys' own prompt; a blank name changes nothing (Forget deletes it).
    def self.rename_entry(item)
      key = item[:key]
      case item[:dict]
      when :tags
        cur = (PokeAccess::Tags.get(key[0], key[1]) rescue nil).to_s
        PokeAccess::Locator.prompt_rename(entry_label(item), cur,
          [:loc_label_for, :loc_label_prompt, :loc_label_saved]) { |v| PokeAccess::Tags.set(key[0], key[1], v) }
      when :marks
        cur = item[:name].to_s
        PokeAccess::Locator.prompt_rename(cur, cur,
          [:mark_edit_for, :mark_prompt, :mark_saved]) { |v| PokeAccess::Marks.set(key[0], key[1], key[2], v) }
      when :maps
        cur = item[:name].to_s
        PokeAccess::Locator.prompt_rename(cur, cur,
          [:map_label_for, :map_label_prompt, :map_label_saved]) { |v| PokeAccess::MapNames.set(key, v) }
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

    # Runs one store's import or export, or every store's for :all, and speaks each result in order.
    def self.run_transfer(op, which)
      list = which == :all ? DICT_ORDER : [which]
      say(list.map { |d| op == :import ? import_one(d) : export_one(d) }.join(". "))
    end

    # Exports one store; the message names the count, that there was nothing, or that its file could not be written.
    def self.export_one(d)
      mod = DICTS[d][:mod]
      n = (mod.export rescue nil)
      return t(DICTS[d][:export_done], :n => n) if n
      return t(DICTS[d][:export_none]) if mod.count == 0
      t(:act_export_failed, :file => File.basename(mod.const_get(:EXPORT)))
    end

    # Imports one store, refusing a file stamped with another game (its keys are map ids, meaningless elsewhere), said
    # by the file's name alone.
    def self.import_one(d)
      mod = DICTS[d][:mod]
      file = File.basename(mod.const_get(:IMPORT))
      status = (mod.import_status rescue [:none])[0]
      case status
      when :none    then t(:act_import_none, :file => file)
      when :foreign then t(:act_import_foreign, :file => file)
      else
        n = (mod.import_now rescue 0)
        PokeAccess::Events.emit(:tags_changed)
        t(DICTS[d][:import_done], :n => n)
      end
    end
  end
end
