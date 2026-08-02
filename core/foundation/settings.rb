module PokeAccess
  # User settings persisted to a plain key=value ini (no JSON: Ruby 1.8.7 has no json gem). Boot applies
  # these after the per-game constants so the user's choices win; a missing file is created with defaults.
  module Settings
    FILE = "#{PokeAccess::Paths::DATA}/settings.ini"
    # Setting kinds by how they persist: numeric (clamped via Config::KIND_BOUNDS), flag, and symbol.
    # NUMERIC derives from KIND_BOUNDS, so a new numeric kind needs only its bounds row.
    NUMERIC = PokeAccess::Config::KIND_BOUNDS.keys
    SYMS    = [:lang, :algo, :occ, :navmode]
    FLAGS   = PokeAccess::Config.keys_of_kind(:flag)

    # Loads the ini (if any) over Config; creates it with current values otherwise. After applying, the
    # ini is rewritten once if this mod version knows keys the file lacks, so a new setting is editable
    # by hand right after updating -- previously it only appeared once the user touched the config menu.
    # The user's values just applied are serialised back unchanged.
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
      # Mod hotkeys: only the moved ones are in the file, so each one OVERWRITES its default and the rest
      # keep theirs. An unknown action name is ignored rather than added -- the ini must not be able to
      # invent hotkeys the mod does not have.
      data.each do |k, v|
        next unless k =~ /\Akey_(\w+)\z/ && v.to_i > 0
        sym = $1.to_sym
        PokeAccess::Config.keys[sym] = v.to_i if PokeAccess::Config::KEY_DEFAULTS.has_key?(sym)
      end
      write if schema_keys.any? { |k| !data.has_key?(k) }
    rescue StandardError => e
      PokeAccess.write_marker("settings apply: #{e.message}\n")
    end

    # Every settings key this version persists (the write serialisation, minus the per-user bind_* lines),
    # in write order. The kind list is built on a duped array with push/concat, never NUMERIC + [...]:
    # a fangame script patch redefines Array#+ as an in-place mutator, so the literal `+` would
    # corrupt the NUMERIC constant (dup/push/concat are untouched).
    def self.schema_keys
      kinds = NUMERIC.dup
      kinds.push(:flag)
      kinds.concat(SYMS)
      kinds.map { |kind| PokeAccess::Config.keys_of_kind(kind).map { |k| k.to_s } }.flatten
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
    rescue StandardError
      {}
    end

    # Writes the current Config values to the ini (see schema_keys for the key list and order).
    def self.write
      File.open(FILE, "w") do |f|
        f.write("# Configuracion del mod de accesibilidad\n")
        f.write("# volumenes 0-100; sound_nav off/basic/full\n")
        schema_keys.each { |k| f.write("#{k}=#{PokeAccess::Config.send(k)}\n") }
        f.write("# remap de controles (accion=codigo de tecla virtual de Windows)\n")
        (PokeAccess::Config.rebinds || {}).each { |sym, code| f.write("bind_#{sym}=#{code}\n") }
        # Only the mod hotkeys the player actually MOVED: writing all eleven would freeze today's defaults
        # into every ini, so a future version could never change one without every existing player keeping
        # the old key forever.
        (PokeAccess::Config.keys || {}).each do |sym, code|
          f.write("key_#{sym}=#{code}\n") if PokeAccess::Config::KEY_DEFAULTS[sym] != code
        end
      end
    rescue StandardError
    end
  end
end
