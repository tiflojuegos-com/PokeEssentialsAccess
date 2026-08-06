# Boot: the mod loader. Evaluates the toolkit in an explicit, dependency-ordered manifest -- core first,
# then the bundled game folder, then user settings on top. One shared mechanism for both loaders (mkxp-z
# preload and native RMXP injection). eval is intentional and safe: it loads our own trusted files shipped
# with the mod, in a fixed local folder, the same way RGSS runs every game script.
module PokeAccessBoot
  ROOT = "accessibility"

  # Loads core (by its manifest), then the third-party plugin readers this game DECLARES, then the bundled
  # game (by its manifest), then applies user settings on top so they override the per-game defaults.
  #
  # Plugins sit between core and the profile on purpose: they may use core, and the profile loads after so
  # it can override a plugin reader that does not fit its own copy of that plugin.
  def self.run
    load_manifest("#{ROOT}/core")
    load_plugins(declared_plugins("#{ROOT}/game"))
    load_manifest("#{ROOT}/game")
    (PokeAccess::Settings.apply rescue nil) if defined?(PokeAccess) && PokeAccess.const_defined?(:Settings)
    miss = (PokeAccess::Hooks.missing rescue [])
    log("[diag] enganches sin metodo (posible typo): #{miss.join(', ')}") if miss && !miss.empty?
    if defined?(PokeAccess::Data) && (PokeAccess::Data.active_priority rescue nil).to_i <= 0
      log("[diag] PokeAccess::Data en modo emergencia: ningun provider de motor registrado (datos = id crudo)")
    end
    par = (PokeAccess::I18n.parity_issues rescue [])
    log("[diag] i18n sin paridad (clave en un idioma y no en otro): #{par.join(', ')}") if par && !par.empty?
  end

  # Reads <dir>/manifest.rb (an ordered array of "subsystem/name" entries) and evals each <dir>/<entry>.rb
  # in that order -- the manifest's order, never the filesystem's, so adding or moving a module is a
  # one-line edit and never depends on filename prefixes or glob ordering.
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

  # The manifest's value, or nil. Two shapes are accepted, and BOTH are current: an Array is the plain
  # module list every profile has always had, and a Hash ({:modules => [...], :plugins => [...]}) is the
  # extended form a profile uses only when it declares third-party plugin readers. Tolerating both is what
  # keeps twelve untouched profiles out of a change that, done wrong here, does not mute a screen: it stops
  # the mod from booting at all.
  #
  # eval, as everywhere in this loader (see the file header): the manifest is a Ruby literal shipped inside
  # the mod's own folder, not user input, and RGSS has no JSON parser to read it with instead.
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

  # The plugin readers a profile declares: a list of names, or :auto. Never inferred from anything else --
  # a reader must only run where someone decided it fits, because two games can ship the same plugin CLASS
  # with different internals, and only a person can check that.
  #
  # :auto is that same rule for the one profile it cannot apply to. The generic profile is the fallback for
  # games nobody has written a profile for, so there is nobody who decided: naming plugins by hand there
  # means either listing every plugin the mod knows (and an unknown game pays for all of them) or leaving a
  # screen silent on every unsupported fangame until somebody remembers to edit that file. Asking the
  # running game is the honest third answer, and silence is the failure a blind player cannot diagnose.
  def self.declared_plugins(dir)
    mf = "#{dir}/manifest.rb"
    return [] unless File.exist?(mf)
    value = read_manifest(mf)
    return [] unless value.is_a?(Hash)
    list = value[:plugins]
    return :auto if list == :auto
    list.is_a?(Array) ? list : []
  end

  # Loads the plugin readers. A declared file that is NOT there is logged and skipped, never fatal: an
  # interrupted install, or a mod newer than the launcher that copied it, must cost the player one silent
  # screen -- not the whole mod.
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

  # The plugins this game actually has, asked of the running game through the same detection table the
  # diagnostic already uses. No new data and no second probe: the table maps each plugin to the class (or
  # the "Class#method") that gives it away, and the game itself answers.
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

  # Appends a boot error to the log file. Uses the resolved data dir once Paths has loaded (it may pick a
  # writable AppData dir when the game folder is read-only), falling back to the default before then.
  def self.log(msg)
    dir = (defined?(PokeAccess::Paths) && PokeAccess::Paths.const_defined?(:DATA)) ? PokeAccess::Paths::DATA : "#{ROOT}/data"
    File.open("#{dir}/loader_error.txt", "a") { |fh| fh.write("#{msg}\n\n") }
  rescue StandardError
  end
end

PokeAccessBoot.run
