module PokeAccess
  # Config menu, verbosity: the scheme in use, a new scheme and the player's own (use, edit, rename, copy, delete).
  # The editor lists this game's readings, then the level of those the scheme does not name; each change is saved.
  module ConfigMenu
    # What can be done to one of the player's schemes, in menu order, each with its label.
    SCHEME_ACTIONS = [[:use, :vb_act_use], [:edit, :vb_act_edit], [:rename, :tag_rename], [:copy, :vb_act_copy],
                      [:delete, :entry_forget]]

    # The longest name a scheme may be given.
    SCHEME_NAME_MAX = 20

    # The verbosity screen: the scheme-in-use setting, a new scheme, then the player's own schemes by name.
    def self.verbosity_rows
      rows = PokeAccess::Config.schema_group(:verbosity).map { |r| { :kind => :setting, :row => r } }
      rows.push({ :kind => :scheme_action, :op => :new, :label => :vb_new, :help => :vb_new_help })
      PokeAccess::VerbositySchemes.names.each { |n| rows.push({ :kind => :scheme, :name => n }) }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # A scheme's row: its name, and that it is the one in use.
    def self.scheme_label(name)
      name.to_s == PokeAccess::Verbosity.active.to_s ? t(:vb_in_use, :name => name) : name.to_s
    end

    # What can be done to the scheme entered.
    def self.scheme_action_rows
      rows = SCHEME_ACTIONS.map { |op, label| { :kind => :scheme_action, :op => op, :label => label } }
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The editor's rows: every reading declared here, then the level of the ones the scheme does not name.
    def self.scheme_edit_rows
      rows = PokeAccess::Verbosity.readings.map { |r| { :kind => :reading, :reading => r[0] } }
      rows.push({ :kind => :reading, :reading => PokeAccess::Verbosity::OTHERS })
      rows.push({ :kind => :back, :label => :back })
      rows
    end

    # The levels of the scheme entered, {reading => level}.
    def self.scheme_levels
      PokeAccess::VerbositySchemes.levels(@scheme) || {}
    end

    # A reading's level in the scheme entered, in words.
    def self.reading_level_text(reading)
      PokeAccess::Verbosity.name_of(PokeAccess::Verbosity.level_in(scheme_levels, reading))
    end

    # What each level says of a reading, as the info key reads it on the reading's row.
    def self.reading_help(reading)
      row = PokeAccess::Verbosity.reading_row(reading)
      row ? t(row[2]) : describe
    end

    # Moves a reading of the scheme entered one level down (dir -1) or up (1) from the level it is said at, wrapping,
    # saves the scheme and says the reading's new level.
    def self.adjust_reading(reading, dir)
      levels = scheme_levels.dup
      list = PokeAccess::Verbosity::LEVELS
      now = PokeAccess::Verbosity.level_in(levels, reading)
      levels[reading] = list[(list.index(now).to_i + dir) % list.length]
      PokeAccess::VerbositySchemes.set(@scheme, levels)
      say("#{PokeAccess::Verbosity.reading_name(reading)}, #{reading_level_text(reading)}")
    end

    # Runs a scheme action: a new scheme, from the verbosity screen, or one on the scheme entered.
    def self.run_scheme_action(op)
      case op
      when :new    then create_scheme(current_levels)
      when :use    then use_scheme
      when :edit   then enter(:scheme_edit, t(:vb_editing, :name => @scheme))
      when :rename then rename_scheme
      when :copy   then create_scheme(scheme_levels)
      when :delete then delete_scheme
      end
    end

    # The levels a new scheme starts from: each declared reading's under the scheme in use, and the others' level.
    def self.current_levels
      out = {}
      PokeAccess::Verbosity.readings.each { |r| out[r[0]] = PokeAccess::Verbosity.level(r[0]) }
      out[PokeAccess::Verbosity::OTHERS] = PokeAccess::Verbosity.level(PokeAccess::Verbosity::OTHERS)
      out
    end

    # Asks for a name, saves a scheme with the given levels under it and opens its editor over the verbosity
    # screen, whose cursor is left on the new scheme's row for the way back.
    def self.create_scheme(levels)
      name = ask_scheme_name
      return unless name
      PokeAccess::VerbositySchemes.set(name, levels)
      @mode, @index = @stack.pop if @mode == :scheme_actions
      @index = scheme_row(name) || @index
      @scheme = name
      enter(:scheme_edit, t(:vb_created, :name => name))
    end

    # Puts the scheme entered in use.
    def self.use_scheme
      PokeAccess::Verbosity.use(@scheme.to_sym)
      say(t(:vb_now, :name => @scheme))
    end

    # Gives the scheme entered a new name, keeps it in use if it was, and leaves the verbosity screen's cursor on
    # it for the way back (the list is in name order).
    def self.rename_scheme
      name = ask_scheme_name(@scheme, @scheme)
      return unless name
      in_use = PokeAccess::Verbosity.active.to_s == @scheme
      PokeAccess::VerbositySchemes.rename(@scheme, name)
      PokeAccess::Verbosity.use(name.to_sym) if in_use
      @scheme = name
      i = scheme_row(name)
      @stack.last[1] = i if i && !@stack.empty?
      say(t(:vb_renamed, :name => name))
    end

    # Deletes the scheme entered on a second press of its row (the first asks) and goes back to the verbosity
    # screen. A scheme deleted while in use leaves the full level in use, and says so.
    def self.delete_scheme
      unless @armed == :delete
        @armed = :delete
        return say(t(:vb_delete_confirm, :name => @scheme))
      end
      @armed = nil
      in_use = PokeAccess::Verbosity.active.to_s == @scheme
      PokeAccess::VerbositySchemes.delete(@scheme)
      PokeAccess::Verbosity.use(:full) if in_use
      parts = [t(:vb_deleted, :name => @scheme)]
      parts.push(t(:vb_now, :name => PokeAccess::Verbosity.name_of(:full))) if in_use
      @scheme = nil
      @mode, @index = @stack.pop
      @index = items.length - 1 if @index >= items.length
      say(parts.push(describe).join(". "))
    end

    # The row of a scheme on the verbosity screen, or nil.
    def self.scheme_row(name)
      verbosity_rows.index { |r| r[:kind] == :scheme && r[:name] == name }
    end

    # Asks for a scheme name through the game's text entry: the cleaned name, or nil (said why) if blank or unusable.
    # param except the scheme being renamed, whose own name stays free for it
    def self.ask_scheme_name(current = "", except = nil)
      txt = begin
              pbEnterText(t(:vb_name_prompt), 0, SCHEME_NAME_MAX, current)
            rescue StandardError => e
              PokeAccess.log_once("scheme_name_prompt", e)
              nil
            end
      name = PokeAccess::VerbositySchemes.clean_name(txt.to_s)
      if name.empty?
        say(t(:cancelled))
        return nil
      end
      unless PokeAccess::VerbositySchemes.valid_name?(name, except)
        say(t(:vb_name_taken, :name => name))
        return nil
      end
      name
    end
  end
end
