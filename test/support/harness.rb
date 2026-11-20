# Loads the toolkit (core, then optionally a game profile) under the engine stubs ENGINE picks (:gen6 by default,
# :gamedata), in boot.rb's manifest order and through eval as boot.rb does, collecting each file's load error.
ENGINE = (ENV["PA_ENGINE"] || "gen6").to_sym

# Runtime files (markers, settings, recordings) go to a throwaway folder of this process in the system temp dir, out
# of the repo, so runs side by side never share one; a process a test starts inherits it, and its maker removes it.
require "tmpdir"
require "fileutils"
unless ENV["POKEACCESS_DATA_DIR"]
  ENV["POKEACCESS_DATA_DIR"] = File.join(Dir.tmpdir, "pokeaccess-test-data-#{Process.pid}")
  data_dir = ENV["POKEACCESS_DATA_DIR"]
  at_exit { FileUtils.rm_rf(data_dir) }
end

require File.expand_path(ENGINE == :gamedata ? "stubs/engine_gamedata" : "stubs/engine_gen6", File.dirname(__FILE__))

module Harness
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  @errors = []

  # The load errors collected while loading the toolkit.
  def self.errors; @errors; end

  # The source evaluated for path: the file, or the file with the one change tools/mutate.rb asks for (PA_MUTANT
  # names a JSON file with the path, a byte range and its replacement).
  def self.source(path)
    src = File.read(path)
    m = mutant
    return src unless m && File.expand_path(path) == File.expand_path(m["path"])
    raw = src.b
    out = raw.byteslice(0, m["start"]) + m["text"].b + raw.byteslice(m["end"], raw.bytesize - m["end"])
    out.force_encoding(src.encoding)
  end

  # The mutant PA_MUTANT asks for, or nil.
  def self.mutant
    return @mutant if defined?(@mutant)
    require "json" if ENV["PA_MUTANT"]
    @mutant = ENV["PA_MUTANT"] ? JSON.parse(File.read(ENV["PA_MUTANT"])) : nil
  end

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
        eval(source(f), TOPLEVEL_BINDING, f)
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
        eval(source(f), TOPLEVEL_BINDING, f)
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
        eval(source(f), TOPLEVEL_BINDING, f)
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

  # Declares a profile's puzzles again, through source so a mutant of one is the one tested, for a test whose reset dropped them;
  # a function or method hook already added by an earlier load stays added once, as in the game, which loads each file once,
  # a reader or rule the files register again takes the place of the one an earlier load left (renew_registered), and the
  # constants it sets again raise no warning.
  def self.load_puzzles(game)
    chains = PokeAccess::Hooks.instance_variable_get(:@chains)
    added = {}
    linked = {}
    PokeAccess::Hooks.fn_bodies.each { |key, list| added[key] = list.length }
    chains.each { |key, list| linked[key] = list.length }
    before = registries.map { |list| [list, list.dup] }
    paths = []
    verbose = $VERBOSE
    $VERBOSE = nil
    manifest_of("games/#{game}")[:modules].select { |entry| entry =~ %r{\Apuzzles/} }.each do |entry|
      path = File.join(ROOT, "games", game, "#{entry}.rb")
      paths.push(path)
      eval(source(path), TOPLEVEL_BINDING, path)
    end
    added.each { |key, n| PokeAccess::Hooks.fn_bodies[key].slice!(n..-1) if n > 0 }
    linked.each { |key, n| chains[key].slice!(n..-1) if n > 0 && chains[key] }
    before.each { |list, old| renew_registered(list, old, paths) }
  ensure
    $VERBOSE = verbose
  end

  # Every list a PokeAccess module keeps in an instance variable: where the mod's readers, rules and listeners are registered.
  def self.registries
    out = []
    seen = {}
    stack = [PokeAccess]
    real_name = Module.instance_method(:name)
    until stack.empty?
      mod = stack.pop
      next if seen[mod]
      seen[mod] = true
      mod.instance_variables.each do |iv|
        v = mod.instance_variable_get(iv)
        out.push(v) if v.is_a?(Array) && !v.frozen?
      end
      mod.constants.each do |c|
        k = (mod.const_get(c) rescue nil)
        stack.push(k) if k.is_a?(Module) && real_name.bind(k).call.to_s.start_with?("PokeAccess")
      end
    end
    out.uniq { |l| l.object_id }
  end

  # In list, the entries a reload of paths added stand where the ones from those same lines stood before it (old, the
  # list as it was), in the same order, and those are dropped: one reader or rule per declaration, the newest.
  def self.renew_registered(list, old, paths)
    return if list.length <= old.length
    kept = {}
    old.each { |e| kept[e.object_id] = true }
    fresh = list.reject { |e| kept[e.object_id] }
    by_line = {}
    fresh.each { |e| (loc = registered_at(e, paths)) && (by_line[loc] ||= []).push(e) }
    by_line.each do |loc, news|
      olds = list.select { |e| kept[e.object_id] && registered_at(e, paths) == loc }
      next if olds.empty?
      news.each { |e| list.delete_if { |x| x.equal?(e) } }
      olds.each_with_index do |e, i|
        at = list.index { |x| x.equal?(e) }
        i < news.length ? list[at] = news[i] : list.delete_at(at)
      end
      list.push(*news[olds.length..-1]) if news.length > olds.length
    end
  end

  # The [file, line] of the block an entry of a registry holds, when one of paths declared it, else nil.
  def self.registered_at(entry, paths)
    parts = [entry]
    parts.concat(entry) if entry.is_a?(Array)
    parts.concat(entry.to_a) if entry.is_a?(Struct)
    blk = parts.find { |x| x.is_a?(Proc) }
    loc = blk && blk.source_location
    loc && paths.include?(loc[0]) ? loc : nil
  end

  # The first declaration of a map's mechanics, or nil.
  def self.declared(map_id)
    list = PokeAccess::World::Mechanics.instance_variable_get(:@defs)[map_id]
    list && !list.empty? ? list[0][1] : nil
  end

  # Loads core and, if given, a game profile, each via its manifest.
  def self.load_all(game = nil)
    load_dir("core")
    load_dir("games/#{game}") if game
    @errors
  end
end
