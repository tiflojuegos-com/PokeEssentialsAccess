module PokeAccess
  # How much the mod says per kind of row (a reading), at brief, medium or full; a scheme sets every reading's level
  # (the built-in three alike, a player's own each apart). Row builders pass [text, level] parts to line or ask
  # keep?; plugins and profiles declare readings with define_reading. The info key and Ctrl+T ignore the levels.
  module Verbosity
    # The levels, least to most.
    LEVELS = [:brief, :medium, :full]

    # The key of each level's spoken name, which is also the name of the built-in scheme at that level.
    LEVEL_KEYS = { :brief => :vb_level_brief, :medium => :vb_level_medium, :full => :vb_level_full }

    # The entry a player's scheme keeps for every reading it does not name; without it, those are said in full.
    OTHERS = :others

    # That entry's row in the scheme editor, shaped like a declared reading's.
    OTHERS_ROW = [OTHERS, :vb_others, :vbh_others]

    @readings = []

    # Declares a reading the scheme editor lists, with the keys of its spoken name and of its help (what each level
    # says of it). Declaring one again replaces it where it stands, so a profile can reword a reading it shares.
    def self.define_reading(reading, name_key, help_key)
      row = [reading, name_key, help_key]
      i = @readings.index { |r| r[0] == reading }
      i ? @readings[i] = row : @readings.push(row)
      reading
    end

    # The declared readings as [reading, name key, help key] rows, in the order the editor lists them.
    def self.readings; @readings; end

    # A reading's row, the others entry's, or nil for a reading never declared.
    def self.reading_row(reading)
      reading == OTHERS ? OTHERS_ROW : @readings.assoc(reading)
    end

    # The scheme in use: a built-in level, or a player's scheme name as a Symbol; :full when that scheme is gone.
    def self.active
      v = (PokeAccess::Config.verbosity rescue nil)
      return :full if v.nil?
      return v if LEVELS.include?(v) || PokeAccess::VerbositySchemes.levels(v.to_s)
      :full
    end

    # The level a reading is said at under the active scheme; full while a row is built whole.
    def self.level(reading)
      return :full if @whole
      a = active
      return a if LEVELS.include?(a)
      level_in(PokeAccess::VerbositySchemes.levels(a.to_s) || {}, reading)
    end

    # Where a level stands, least to most; an unknown one (a typo) is logged and ranks as full.
    def self.rank(level)
      i = LEVELS.index(level)
      return i if i
      PokeAccess.log_once("verbosity_level_#{level}", "unknown verbosity level #{level.inspect}")
      LEVELS.length - 1
    end

    # The level a player's scheme, as its {reading => level} entries, gives a reading: its own, else the scheme's
    # others level, else full.
    def self.level_in(levels, reading)
      levels[reading] || levels[OTHERS] || :full
    end

    # Whether a part said from a given level up goes into a reading's row.
    def self.keep?(reading, from)
      rank(from) <= rank(level(reading))
    end

    # A row from its [text, level from which it is said] parts: those the reading's level reaches, blank ones left
    # out, joined with sep. A bare string is a full-level part.
    def self.line(reading, parts, sep = ", ")
      join(kept(reading, parts), sep)
    end

    # Texts joined with sep; joined as sentences, one that already ends its sentence (a game's own "... contest.")
    # takes no second period.
    def self.join(texts, sep)
      sep == ". " ? PokeAccess.sentences(texts) : texts.join(sep)
    end

    # A row at its reading's level, publishing it whole to the info key and to Ctrl+T: for a screen with no sheet of
    # its own (a Pokedex list, a quest log).
    def self.info_line(reading, parts, sep = ", ")
      whole = full_line(parts, sep)
      PokeAccess::Info.set_info(:text, whole, whole)
      line(reading, parts, sep)
    end

    # The same row whole, as full says it: what Ctrl+T repeats.
    def self.full_line(parts, sep = ", ")
      texts = parts.map { |part| part.is_a?(Array) ? part[0] : part }
      join(texts.reject { |t| t.nil? || t.to_s.strip.empty? }.map { |t| t.to_s }, sep)
    end

    # Builds a row as the full level says it, whatever the scheme: the row Ctrl+T repeats.
    def self.whole
      was = @whole
      @whole = true
      yield
    ensure
      @whole = was
    end

    # A row's non-blank part texts that the reading's level reaches, in order.
    def self.kept(reading, parts)
      reach = rank(level(reading))
      out = []
      parts.each do |part|
        text, from = part.is_a?(Array) ? part : [part, :full]
        next if text.nil? || text.to_s.strip.empty?
        out.push(text.to_s) if rank(from) <= reach
      end
      out
    end

    # A list row with its position ("Pidgey, 3 de 8"), or the name alone while positions are left out.
    def self.list_entry(name, n, tot)
      return name.to_s unless keep?(:positions, :medium)
      PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => tot)
    end

    # A row's position in its list ("3 de 8") while positions are said, else nil.
    def self.position(i, n)
      keep?(:positions, :medium) ? PokeAccess::I18n.t(:list_pos, :i => i, :n => n) : nil
    end

    # Whether the key hints a screen writes are said.
    def self.hints?
      keep?(:hints, :medium)
    end

    # A line with its key hint after it while key hints are said, else the line alone.
    def self.with_hint(text, hint, sep = ". ")
      hints? ? "#{text}#{sep}#{hint}" : text.to_s
    end

    # Whether a screen's explanation of the focused option (help, rule, description) is said: only in full.
    def self.descriptions?
      keep?(:descriptions, :full)
    end

    # The schemes the rotation goes through: the built-in ones, then the player's by name.
    def self.rotation
      LEVELS.dup.concat(PokeAccess::VerbositySchemes.names.map { |n| n.to_sym })
    end

    # The scheme dir steps away from the active one in the rotation (1 the next, -1 the previous).
    def self.next_scheme(dir)
      list = rotation
      i = list.index(active) || list.index(:full)
      list[(i + dir) % list.length]
    end

    # Puts a scheme in use and saves the choice.
    def self.use(scheme)
      PokeAccess::Config.verbosity = scheme
      (PokeAccess::Settings.write rescue nil)
    end

    # The rotation key: the next scheme, said.
    def self.rotate_scheme(dir = 1)
      use(next_scheme(dir))
      PokeAccess.speak(PokeAccess::I18n.t(:vb_now, :name => name_of(active)), true, :system)
    end

    # The spoken name of a scheme: a built-in level's, or the name the player gave it.
    def self.name_of(scheme)
      LEVEL_KEYS[scheme] ? PokeAccess::I18n.t(LEVEL_KEYS[scheme]) : scheme.to_s
    end

    # The spoken name of a reading.
    def self.reading_name(reading)
      row = reading_row(reading)
      row ? PokeAccess::I18n.t(row[1]) : reading.to_s
    end
  end
end

# The core's readings, the first the scheme editor lists.
PokeAccess::Verbosity.define_reading(:party, :vb_party, :vbh_party)
PokeAccess::Verbosity.define_reading(:battle_move, :vb_battle_move, :vbh_battle_move)
PokeAccess::Verbosity.define_reading(:battle_marks, :vb_battle_marks, :vbh_battle_marks)
PokeAccess::Verbosity.define_reading(:summary_move, :vb_summary_move, :vbh_summary_move)
PokeAccess::Verbosity.define_reading(:learn_move, :vb_learn_move, :vbh_learn_move)
PokeAccess::Verbosity.define_reading(:bag_item, :vb_bag_item, :vbh_bag_item)
PokeAccess::Verbosity.define_reading(:shop_item, :vb_shop_item, :vbh_shop_item)
PokeAccess::Verbosity.define_reading(:pc_slot, :vb_pc_slot, :vbh_pc_slot)
PokeAccess::Verbosity.define_reading(:dex_entry, :vb_dex_entry, :vbh_dex_entry)
PokeAccess::Verbosity.define_reading(:dex_page, :vb_dex_page, :vbh_dex_page)
PokeAccess::Verbosity.define_reading(:ribbon, :vb_ribbon, :vbh_ribbon)
PokeAccess::Verbosity.define_reading(:positions, :vb_positions, :vbh_positions)
PokeAccess::Verbosity.define_reading(:hints, :vb_hints, :vbh_hints)
PokeAccess::Verbosity.define_reading(:descriptions, :vb_descriptions, :vbh_descriptions)
