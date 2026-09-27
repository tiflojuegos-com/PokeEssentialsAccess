module PokeAccess
  # User settings in a key=value settings.ini, applied after the per-game constants so the player's choices win;
  # a missing file is created with the current values.
  module Settings
    FILE = "#{PokeAccess::Paths::DATA}/settings.ini"
    # The ini layout version, stamped into every ini written; an older file is migrated once. Version 2 (0.4.6)
    # sets the language to :auto, since an ini from before cannot tell a chosen Spanish from the old default.
    VERSION = 2
    # Setting kinds by how they persist: numeric (clamped by Config::KIND_BOUNDS), flag and symbol.
    NUMERIC = PokeAccess::Config::KIND_BOUNDS.keys
    SYMS    = [:lang, :algo, :occ, :navmode, :verbosity]
    FLAGS   = PokeAccess::Config.keys_of_kind(:flag)

    # Loads the ini over Config (creating it when missing), then rewrites it when it is older or lacks a known
    # key. key_* lines override only the mod's own hotkeys; an unknown action is ignored.
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
      set = {}
      data.each do |k, v|
        next unless k =~ /\Akey_(\w+)\z/ && v.to_i > 0
        sym = $1.to_sym
        next unless PokeAccess::Config::KEY_DEFAULTS.has_key?(sym)
        PokeAccess::Config.keys[sym] = v.to_i
        set[sym] = true
      end
      drop_taken_defaults(set)
      ver = data["settings_version"].to_i
      PokeAccess::Config.language = :auto if ver < 2
      write if ver < VERSION || schema_keys.any? { |k| !data.has_key?(k) }
    rescue StandardError => e
      PokeAccess.write_marker("settings apply: #{e.message}\n")
    end

    # Unbinds each mod key still on its default that a saved binding already uses (a default new in this version on
    # a key the player gave to something else), so the saved binding keeps working; the remap menu can bind it again.
    # param set the mod keys the ini sets itself
    def self.drop_taken_defaults(set)
      keys = PokeAccess::Config.keys
      taken = (PokeAccess::Config.rebinds || {}).values
      keys.each { |s, c| taken.push(c) if set[s] }
      keys.keys.each { |s| keys[s] = nil if !set[s] && !keys[s].nil? && taken.include?(keys[s]) }
    end

    # Every schema key the ini persists, in SCHEMA order (the same under both Rubies). Built by dup and push,
    # not Array#+, which one game's scripts turn into a mutator.
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

    # Writes the current Config values to the ini (keys and order from schema_keys), plus the rebinds and only
    # the mod hotkeys moved off their defaults, so a later default change still reaches every player.
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
