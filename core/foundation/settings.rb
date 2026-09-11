module PokeAccess
  # User settings persisted to a plain key=value ini (no JSON: Ruby 1.8.7 has no json gem). Boot applies
  # these after the per-game constants so the user's choices win; a missing file is created with defaults.
  module Settings
    FILE = "#{PokeAccess::Paths::DATA}/settings.ini"
    # The ini layout version, stamped into every ini written. A file from before a version is brought up
    # to date once, then the player's choices are kept as written. Version 2 (0.4.6) turns the language to
    # :auto, for every ini written before it. The vast majority carry the old fixed default, Spanish,
    # chosen by nobody, and :auto resolves to Spanish for a Spanish system anyway while it hands an
    # English player the English they never got. The few who HAD picked a language by hand are moved
    # too, which costs them one trip through the menu: an ini from before the stamp cannot say which
    # of the two it is.
    VERSION = 2
    # Setting kinds by how they persist: numeric (clamped via Config::KIND_BOUNDS), flag, and symbol.
    # NUMERIC derives from KIND_BOUNDS, so a new numeric kind needs only its bounds row.
    NUMERIC = PokeAccess::Config::KIND_BOUNDS.keys
    SYMS    = [:lang, :algo, :occ, :navmode]
    FLAGS   = PokeAccess::Config.keys_of_kind(:flag)

    # Loads the ini (if any) over Config; creates it with current values otherwise. After applying, the
    # ini is rewritten once if this mod version knows keys the file lacks, so a new setting is editable by
    # hand right after updating rather than only once the config menu has been opened. The user's values
    # just applied are serialised back unchanged.
    #
    # Mod hotkeys are read as overrides: only the moved ones are in the file, so each OVERWRITES its
    # default and the rest keep theirs. An unknown action name is ignored rather than added -- the ini must
    # not be able to invent hotkeys the mod does not have.
    def self.apply
      data = read
      if data.empty?
        write
        return
      end
      NUMERIC.each { |kind| PokeAccess::Config.keys_of_kind(kind).each { |k| set_numeric(k, data[k.to_s], kind) } }
      FLAGS.each   { |k| PokeAccess::Config.send("#{k}=", data[k.to_s] == "true") unless data[k.to_s].nil? }
      SYMS.each    { |kind| PokeAccess::Config.keys_of_kind(kind).each { |k| set_sym(k, data[k.to_s]) } }
      rb = {}
      data.each { |k, v| rb[$1.to_sym] = v.to_i if k =~ /\Abind_(\w+)\z/ && v.to_i > 0 }
      PokeAccess::Config.rebinds = rb unless rb.empty?
      data.each do |k, v|
        next unless k =~ /\Akey_(\w+)\z/ && v.to_i > 0
        sym = $1.to_sym
        PokeAccess::Config.keys[sym] = v.to_i if PokeAccess::Config::KEY_DEFAULTS.has_key?(sym)
      end
      ver = data["settings_version"].to_i
      PokeAccess::Config.language = :auto if ver < 2
      write if ver < VERSION || schema_keys.any? { |k| !data.has_key?(k) }
    rescue StandardError => e
      PokeAccess.write_marker("settings apply: #{e.message}\n")
    end

    # Every settings key this version persists (the write serialisation, minus the per-user bind_* lines),
    # in SCHEMA order, which is the menu's and the same under both Rubies: grouping by kind followed the
    # order of a Hash's keys, which gen-6 shuffles. Built on a DUP of NUMERIC: one game's scripts turn
    # Array#+ into a mutator, and the constant is read again on the next save.
    def self.schema_keys
      kinds = NUMERIC.dup
      kinds.push(:flag)
      kinds.concat(SYMS)
      PokeAccess::Config::SCHEMA.select { |row| kinds.include?(row[2]) }.map { |row| row[0].to_s }
    end

    # Clamps and assigns a numeric setting from its string value, using its kind's [min, max] bounds.
    def self.set_numeric(k, v, kind)
      return if v.nil?
      b = PokeAccess::Config::KIND_BOUNDS[kind]
      return unless b
      n = v.to_i
      n = b[0] if n < b[0]
      n = b[1] if n > b[1]
      PokeAccess::Config.send("#{k}=", n)
    end

    # Assigns a symbol-valued setting from its string value; skips nil or blank.
    def self.set_sym(k, v)
      return if v.nil? || v.strip.empty?
      PokeAccess::Config.send("#{k}=", v.strip.to_sym)
    end

    # Parses the ini into a string hash.
    def self.read
      h = {}
      PokeAccess::KVFile.each(FILE) { |k, v| h[k] = v }
      h
    rescue StandardError => e
      PokeAccess.log_once("settings_read", e)
      {}
    end

    # Writes the current Config values to the ini (see schema_keys for the key list and order). Of the mod
    # hotkeys only the ones the player actually MOVED are written: writing all eleven would freeze today's
    # defaults into every ini, so a future version could never change one without every existing player
    # keeping the old key forever.
    def self.write
      File.open(FILE, "w") do |f|
        f.write("# Configuracion del mod de accesibilidad\n")
        f.write("# volumenes 0-100; sound_nav off/basic/full; language auto o es/en/fr/pt/de/pl\n")
        f.write("settings_version=#{VERSION}\n")
        schema_keys.each { |k| f.write("#{k}=#{PokeAccess::Config.send(k)}\n") }
        f.write("# remap de controles (accion=codigo de tecla virtual de Windows)\n")
        rebinds = PokeAccess::Config.rebinds || {}
        rebinds.keys.sort_by { |sym| sym.to_s }.each { |sym| f.write("bind_#{sym}=#{rebinds[sym]}\n") }
        keys = PokeAccess::Config.keys || {}
        keys.keys.sort_by { |sym| sym.to_s }.each do |sym|
          f.write("key_#{sym}=#{keys[sym]}\n") if PokeAccess::Config::KEY_DEFAULTS[sym] != keys[sym]
        end
      end
    rescue StandardError => e
      PokeAccess.log_once("settings_write", e)
    end
  end
end
