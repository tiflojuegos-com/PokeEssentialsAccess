module PokeAccess
  # User settings in a key=value settings.ini, applied after the per-game constants so the player's choices win. Every
  # value is checked against its setting's kind: an unknown key or a value its kind does not take is dropped, and the
  # file is rewritten whenever it differs from what the settings now hold.
  module Settings
    FILE = "#{PokeAccess::Paths::DATA}/settings.ini"

    # Loads the ini over Config (creating it when missing) and rewrites it when it is not what Config now holds.
    # key_* lines override only the mod's own hotkeys; an unknown action is ignored.
    def self.apply
      data = read
      PokeAccess::Config.settings.each do |s|
        v = data.key?(s.key.to_s) ? (PokeAccess::Config.parse(s, data[s.key.to_s]) rescue nil) : nil
        PokeAccess::Config.send("#{s.key}=", v) unless v.nil?
      end
      rb = {}
      data.each { |k, v| rb[$1.to_sym] = v.to_i if k =~ /\Abind_(\w+)\z/ && free_code?(v) }
      PokeAccess::Config.rebinds = rb unless rb.empty?
      set = {}
      data.each do |k, v|
        next unless k =~ /\Akey_(\w+)\z/ && free_code?(v)
        sym = $1.to_sym
        next unless PokeAccess::Config::KEY_DEFAULTS.key?(sym)
        PokeAccess::Config.keys[sym] = v.to_i
        set[sym] = true
      end
      drop_taken_defaults(set)
      write unless (File.read(FILE) rescue nil) == render
    rescue StandardError => e
      PokeAccess.write_marker("settings apply: #{e.message}\n")
    end

    # True for a saved key code a binding may take: a positive number no engine key or fixed gesture reserves.
    def self.free_code?(value)
      value.to_i > 0 && !PokeAccess::Remap::RESERVED.key?(value.to_i)
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

    # Parses the ini into a string hash.
    def self.read
      h = {}
      PokeAccess::KVFile.each(FILE) { |k, v| h[k] = v }
      h
    rescue StandardError => e
      PokeAccess.log_once("settings_read", e)
      {}
    end

    # The ini as the settings now stand: every setting in declaration order, then the rebinds and only the mod hotkeys
    # moved off their defaults, so a later default change still reaches every player.
    def self.render
      out = "# Configuracion del mod de accesibilidad\n" \
            "# volumenes 0-100; sound_nav off/basic/full; hide_unreachable off/unreachable/room; " \
            "route_limit effort/time/none; language auto o es/en/fr/pt/de/pl\n"
      PokeAccess::Config.settings.each { |s| out << "#{s.key}=#{PokeAccess::Config.send(s.key)}\n" }
      out << "# remap de controles (accion=codigo de tecla virtual de Windows)\n"
      rebinds = PokeAccess::Config.rebinds || {}
      rebinds.keys.sort_by { |sym| sym.to_s }.each { |sym| out << "bind_#{sym}=#{rebinds[sym]}\n" }
      keys = PokeAccess::Config.keys || {}
      keys.keys.sort_by { |sym| sym.to_s }.each do |sym|
        out << "key_#{sym}=#{keys[sym]}\n" if PokeAccess::Config::KEY_DEFAULTS[sym] != keys[sym]
      end
      out
    end

    # Writes the ini as the settings now stand; true once written, false when it could not be.
    def self.write
      File.open(FILE, "w") { |f| f.write(render) }
      true
    rescue StandardError => e
      PokeAccess.log_once("settings_write", e)
      false
    end
  end
end
