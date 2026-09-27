# The mod loader for both mkxp-z preload and native RMXP injection: evals core and the game profile in manifest
# order, the declared plugin readers and the commons the profile imports between them, then applies user settings.
# eval only runs the mod's own files.
module PokeAccessBoot
  ROOT = "accessibility"

  # Loads core, the declared plugin readers, the commons the game profile imports and then the profile itself (both
  # after the plugins, so they can override one), and applies user settings over the per-game defaults.
  def self.run
    load_manifest("#{ROOT}/core")
    game = "#{ROOT}/game"
    commons = imported_dirs(game)
    load_plugins(declared_plugins(game, commons))
    commons.each { |dir| load_manifest(dir) }
    load_manifest(game)
    (PokeAccess::Settings.apply rescue nil) if defined?(PokeAccess) && PokeAccess.const_defined?(:Settings)
    miss = ((PokeAccess::Hooks.missing + PokeAccess::Hooks.unbound) rescue [])
    log("[diag] enganches sin metodo (posible typo): #{miss.join(', ')}") if miss && !miss.empty?
    if defined?(PokeAccess::Data) && (PokeAccess::Data.active_priority rescue nil).to_i <= 0
      log("[diag] PokeAccess::Data en modo emergencia: ningun provider de motor registrado (datos = id crudo)")
    end
    par = (PokeAccess::I18n.parity_issues rescue [])
    log("[diag] i18n sin paridad (clave en un idioma y no en otro): #{par.join(', ')}") if par && !par.empty?
  end

  # Evals each <dir>/<entry>.rb in the order <dir>/manifest.rb lists them, never the filesystem's order.
  def self.load_manifest(dir)
    mf = "#{dir}/manifest.rb"
    unless File.exist?(mf)
      log("#{dir}: sin manifest.rb")
      return
    end
    list = modules_of(read_manifest(mf), mf)
    return if list.nil?
    list.each { |entry| load_module("#{dir}/#{entry}.rb") }
  end

  # The manifest's evaluated value, or nil (logged): a module Array, or {:modules => [...], :plugins => [...],
  # :imports => [...]} for a profile that declares plugin readers or imports commons; both shapes are in use.
  def self.read_manifest(mf)
    eval(File.read(mf), TOPLEVEL_BINDING, mf)
  rescue Exception => e
    raise if e.is_a?(SystemExit)
    log("#{mf}: #{e.class}: #{e.message}")
    nil
  end

  # The module list out of either manifest shape, or nil (logged) when it is neither.
  def self.modules_of(value, mf)
    return value if value.is_a?(Array)
    if value.is_a?(Hash)
      mods = value[:modules]
      return mods if mods.is_a?(Array)
      log("#{mf}: la clave :modules no es una lista")
      return nil
    end
    log("#{mf}: no devolvio una lista de modulos ni un hash con :modules")
    nil
  end

  # The evaluated manifest of dir, or nil when it has none or it fails (logged).
  def self.manifest_value(dir)
    mf = "#{dir}/manifest.rb"
    File.exist?(mf) ? read_manifest(mf) : nil
  end

  # The folders of the commons the profile at dir imports (:imports), in its order and once each. A common is
  # installed in <base>/<name> and imports nothing itself; one with no manifest is logged and skipped, not fatal.
  def self.imported_dirs(dir, base = "#{ROOT}/common")
    value = manifest_value(dir)
    names = (value.is_a?(Hash) && value[:imports].is_a?(Array)) ? value[:imports].map { |n| n.to_s }.uniq : []
    dirs = names.map { |n| "#{base}/#{n}" }
    dirs.select do |d|
      found = File.exist?("#{d}/manifest.rb")
      log("import declarado pero ausente: #{d}") unless found
      found
    end
  end

  # The plugin readers the profile declares, joined by those its commons declare: a list of names, :auto (detect
  # them; the generic profile) or []. Never inferred otherwise: two games can ship the same plugin class with
  # different internals.
  def self.declared_plugins(dir, commons = [])
    own = plugins_of(dir)
    return :auto if own == :auto
    commons.each do |c|
      extra = plugins_of(c)
      own |= extra if extra.is_a?(Array)
    end
    own
  end

  # One manifest's own :plugins: a list of names, :auto, or [] without the key or a Hash manifest.
  def self.plugins_of(dir)
    value = manifest_value(dir)
    return [] unless value.is_a?(Hash)
    list = value[:plugins]
    return :auto if list == :auto
    list.is_a?(Array) ? list : []
  end

  # Loads the named plugin readers (detected ones for :auto); a missing file is logged and skipped, not fatal.
  def self.load_plugins(names)
    table = read_manifest("#{ROOT}/plugins/manifest.rb") if File.exist?("#{ROOT}/plugins/manifest.rb")
    (PokeAccess::Plugins.table = table rescue nil) if table
    names = detected_plugins(table) if names == :auto
    names.each do |name|
      path = "#{ROOT}/plugins/#{name}.rb"
      if File.exist?(path)
        load_module(path)
        (PokeAccess::Plugins.note_loaded(name) rescue nil)
      else
        log("plugin declarado pero ausente: #{path}")
      end
    end
  end

  # The plugins the running game has, by the detection table (plugin => the class or "Class#method" that gives it
  # away), sorted by name.
  def self.detected_plugins(table)
    return [] unless table.is_a?(Hash)
    found = table.keys.select { |name| (PokeAccess::Engine.has?(table[name].to_s) rescue false) }
    found = found.map { |name| name.to_s }.sort
    log("plugins detectados: #{found.join(', ')}") unless found.empty?
    found
  rescue StandardError
    []
  end

  # Evaluates one module file, recording any error to the log instead of aborting the rest.
  def self.load_module(path)
    eval(File.read(path), TOPLEVEL_BINDING, path)
  rescue Exception => e
    raise if e.is_a?(SystemExit)
    log("#{path}: #{e.class}: #{e.message}\n#{(e.backtrace || []).join("\n")}")
  end

  # Appends msg to loader_error.txt in the data dir (Paths::DATA once Paths has loaded, else accessibility/data).
  def self.log(msg)
    dir = (defined?(PokeAccess::Paths) && PokeAccess::Paths.const_defined?(:DATA)) ? PokeAccess::Paths::DATA : "#{ROOT}/data"
    File.open("#{dir}/loader_error.txt", "a") { |fh| fh.write("#{msg}\n\n") }
  rescue StandardError
  end
end

PokeAccessBoot.run
