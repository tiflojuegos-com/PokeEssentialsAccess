module PokeAccess
  # The field notes of the engine Reborn, Rejuvenation and Desolation share (Window_FieldEffectNotes, on the
  # Pokegear's Field Notes and, in Reborn and Rejuvenation, on a battle's): a list of notes whose rows mix text with
  # icons. The generic command reader moves through it; each row is the note as painted with its icons worded, its
  # stage tab and whether confirming opens more. A new list opens with the field's name.
  module FieldNotesRV
    # Icon names of the notes => the i18n key of their word; type icons (typeFIRE, and the field icons that paint a
    # type's label, fieldGrass) are named by the type.
    ICON_KEYS = { "fieldChange" => :rv_icon_change, "fieldUp" => :rv_icon_up, "fieldRedUp" => :rv_icon_red_up,
                  "fieldDown" => :rv_icon_down, "fieldPlus" => :rv_icon_plus, "fieldNoSleep" => :rv_icon_no_sleep,
                  "fieldNoFreeze" => :rv_icon_no_freeze, "fieldAllStat" => :rv_icon_any_status,
                  "fieldFaint" => :rv_icon_faint, "fieldBurn" => :st_burn, "fieldFreeze" => :st_freeze,
                  "fieldParalyze" => :st_paralysis, "fieldPoisonStatus" => :st_poison, "fieldSleep" => :st_sleep }

    ICON = /<icon=(\w+)([^>]*)>/

    # The question-mark type icon (typeQMARK, fieldQmark): a type the note leaves unknown.
    UNKNOWN_TYPE = /\A(?:type|field)qmarks?\z/i

    # The word for one icon: the spoken text its markup carries (tts="..."), the mod's for a known one in any case (the
    # game loads the file by a name Windows does not tell by case), a type's name, or nothing.
    def self.icon_word(name, attrs)
      own = attrs.to_s[/tts="([^"]*)"/, 1]
      return own if own
      low = name.to_s.downcase
      key = ICON_KEYS[name] || ICON_KEYS.find { |k, _v| k.downcase == low }.to_a[1]
      key ||= :rv_icon_unknown_type if name.to_s =~ UNKNOWN_TYPE
      return PokeAccess::I18n.t(key) if key
      type = type_word(name)
      type ? PokeAccess::I18n.t(:pdx_type, :t => type) : ""
    end

    # The name of the type a type icon shows: typeFIRE, or a field icon painted with the type's label (fieldGrass)
    # where its name is one of the engine's types; nil for any other icon.
    def self.type_word(name)
      return nil unless name.to_s =~ /\A(type|field)(\w+)\z/
      prefix = $1
      sym = $2.upcase.to_sym
      return nil if prefix == "field" && !PokeAccess::DataRV.type?(sym)
      PokeAccess::Data.type_name(sym)
    end

    # A note's text with its icons worded and the rest of its markup dropped.
    def self.worded(text)
      PokeAccess.clean(text.to_s.gsub(ICON) { " #{icon_word($1, $2)} " })
    end

    # The row under the cursor: the painted note, its stage tabs (cogwheel text, and Rejuvenation's note) and whether
    # confirming shows more.
    def self.row(win, i)
      notes = (win.notes rescue nil)
      note = notes.is_a?(Array) ? notes[i] : nil
      cmds = win.instance_variable_get(:@commands)
      raw = cmds.is_a?(Array) && cmds[i] ? cmds[i] : (note ? note.text : nil)
      return nil if raw.nil?
      parts = [worded(raw)]
      if note
        parts.push(worded(note.cogwheeltext)) if note.respond_to?(:cogwheeltext)
        parts.push(worded(note.note)) if note.respond_to?(:note)
        parts.push(PokeAccess::I18n.t(:rv_note_more)) unless note.elaboration.to_s.empty?
      end
      parts.reject { |p| p.empty? }.join(", ")
    end

    # The name of the field a list of notes belongs to; Desolation keys its notes by number, the others by symbol.
    def self.field_name(notes)
      note = notes.is_a?(Array) ? notes.first : nil
      return nil if note.nil?
      fe = note.fieldeffect
      fe = fieldIDToSym(fe) if fe.is_a?(Integer) && respond_to?(:fieldIDToSym, true)
      return PokeAccess.clean(getFieldName(fe)) if respond_to?(:getFieldName, true)
      data = $cache.FEData[fe]
      data ? PokeAccess.clean(data.name) : nil
    rescue StandardError
      nil
    end

    # The layer the next list shows as [n, of], set by a battle's notes before they build one.
    def self.layer=(pair); @layer = pair; end

    # The heading of a list as it opens: its field, and which one when a battle stacks several.
    def self.heading(notes)
      pos = @layer
      @layer = nil
      name = field_name(notes)
      return name if name.nil? || pos.nil? || pos[1].to_i < 2
      "#{name}, #{PokeAccess::I18n.t(:rv_note_layer, :n => pos[0], :m => pos[1])}"
    end

    # Hooks the notes lists and the battle's layers.
    def self.bind
      PokeAccess::Menus.def_extractor("Window_FieldEffectNotes") { |win, i| PokeAccess::FieldNotesRV.row(win, i) }
      PokeAccess::Hooks.after_hook("Window_FieldEffectNotes", :initialize, :optional => true) do |win, _r, _a|
        t = PokeAccess::FieldNotesRV.heading(win.notes)
        PokeAccess.speak(t, true) if t && !t.empty?
      end
      PokeAccess::Hooks.before_hook("Scene_FieldNotes_Battle", :pbStartScene, :optional => true) do |_scene, args|
        PokeAccess::FieldNotesRV.layer = [1, (Array(args[0]) - [:INDOOR]).length]
      end
      PokeAccess::Hooks.before_hook("Scene_FieldNotes_Battle", :pbSwitchFieldNotes, :optional => true) do |scene, _a|
        PokeAccess::FieldNotesRV.layer = [PokeAccess.ivar(scene, :@index).to_i + 1,
                                          Array(PokeAccess.ivar(scene, :@fieldlayers)).length]
      end
    end
  end
end

PokeAccess::FieldNotesRV.bind if PokeAccess::DataRV.engine?
