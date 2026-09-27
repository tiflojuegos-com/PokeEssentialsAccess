# Loads the toolkit (core, then optionally a game profile) under the engine stubs ENGINE picks (:gen6 by default,
# :gamedata), in boot.rb's manifest order and through eval as boot.rb does, collecting each file's load error.
ENGINE = (ENV["PA_ENGINE"] || "gen6").to_sym

# Runtime files (markers, settings, recordings) go to a throwaway folder in the system temp dir, out of the repo.
require "tmpdir"
ENV["POKEACCESS_DATA_DIR"] ||= File.join(Dir.tmpdir, "pokeaccess-test-data")

require File.expand_path(ENGINE == :gamedata ? "stubs/engine_gamedata" : "stubs/engine_gen6", File.dirname(__FILE__))

module Harness
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  @errors = []

  # The load errors collected while loading the toolkit.
  def self.errors; @errors; end

  # Loads, once, every plugin reader the harness profile did not declare, so specs can exercise any of them; safe
  # since plugin hooks are :optional, while the static specs still check the declarations.
  def self.load_remaining_plugins
    return if @remaining_done
    @remaining_done = true
    @plugins_loaded ||= {}
    Dir.glob(File.join(ROOT, "plugins", "*.rb")).sort.each do |f|
      name = File.basename(f, ".rb")
      next if name == "manifest" || @plugins_loaded[name]
      @plugins_loaded[name] = true
      begin
        eval(File.read(f), TOPLEVEL_BINDING, f)
      rescue Exception => e
        @errors << "plugins/#{name}.rb: #{e.class}: #{e.message}"
      end
    end
  end

  # The evaluated <rel>/manifest.rb, or nil when it fails; false when there is none.
  def self.manifest_of(rel)
    mf = File.join(ROOT, rel, "manifest.rb")
    return false unless File.file?(mf)
    (eval(File.read(mf), TOPLEVEL_BINDING, mf) rescue nil)
  end

  # The repo folders of the commons a profile manifest imports, in its order and once each; a missing one is
  # recorded against rel and skipped, as loader/boot.rb logs and skips it.
  def self.imported_dirs(rel, value)
    names = (value.is_a?(Hash) && value[:imports].is_a?(Array)) ? value[:imports].map { |n| n.to_s }.uniq : []
    names.map { |n| "games/#{n}" }.select do |d|
      found = File.file?(File.join(ROOT, d, "manifest.rb"))
      @errors << "#{rel}/manifest.rb: import declarado pero ausente: #{d}" unless found
      found
    end
  end

  # Loads the plugin readers a Hash manifest of rel declares, each once; a missing one is recorded against rel.
  def self.load_declared_plugins(rel, value)
    declared = value.is_a?(Hash) ? value[:plugins] : nil
    return unless declared.is_a?(Array)
    declared.each do |name|
      f = File.join(ROOT, "plugins", "#{name}.rb")
      unless File.file?(f)
        @errors << "#{rel}/manifest.rb: plugin declarado pero ausente: plugins/#{name}.rb"
        next
      end
      @plugins_loaded ||= {}
      next if @plugins_loaded[name]
      @plugins_loaded[name] = true
      begin
        eval(File.read(f), TOPLEVEL_BINDING, f)
      rescue Exception => e
        @errors << "plugins/#{name}.rb: #{e.class}: #{e.message}"
      end
    end
  end

  # Evaluates the modules a manifest of rel lists, in its order, collecting each file's load error.
  def self.load_modules(rel, value)
    list = value.is_a?(Hash) ? value[:modules] : value
    unless list.is_a?(Array)
      @errors << "#{rel}/manifest.rb: did not evaluate to an Array of module paths (got #{list.class})"
      return
    end
    list.each do |entry|
      f = File.join(ROOT, rel, "#{entry}.rb")
      begin
        eval(File.read(f), TOPLEVEL_BINDING, f)
      rescue Exception => e
        @errors << "#{rel}/#{entry}.rb: #{e.class}: #{e.message}"
      end
    end
  end

  # Evaluates <rel> as loader/boot.rb does: the plugins its manifest and the commons it imports declare (and, for a
  # profile, the undeclared ones), then each common's modules, then its own.
  def self.load_dir(rel)
    value = manifest_of(rel)
    return if value == false
    commons = imported_dirs(rel, value)
    load_declared_plugins(rel, value)
    commons.each { |c| load_declared_plugins(c, manifest_of(c)) }
    load_remaining_plugins if rel =~ %r{\Agames/}
    commons.each { |c| load_modules(c, manifest_of(c)) }
    load_modules(rel, value)
  end

  # Loads a common's declared plugins and modules once per process, for the specs of the games that import it.
  def self.load_common(name)
    @commons_loaded ||= {}
    return if @commons_loaded[name]
    @commons_loaded[name] = true
    rel = "games/#{name}"
    value = manifest_of(rel)
    load_declared_plugins(rel, value)
    load_modules(rel, value)
  end

  # Runs the block with provider serving the data as an engine's own would, then takes it back out.
  def self.with_provider(provider, priority = 15)
    PokeAccess::Data.register(priority, provider)
    yield
  ensure
    PokeAccess::Data.instance_variable_get(:@providers).reject! { |pr| pr[1].equal?(provider) }
    PokeAccess::Data.instance_variable_set(:@active_entry, nil)
  end

  # Loads core and, if given, a game profile, each via its manifest.
  def self.load_all(game = nil)
    load_dir("core")
    load_dir("games/#{game}") if game
    @errors
  end
end
