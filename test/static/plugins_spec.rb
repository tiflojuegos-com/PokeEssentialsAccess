# The plugins/ layer: the manifest table and the files match, every declared plugin exists and is named by some
# profile, and every hook in plugins/ is :optional (an expected absence must not fill Hooks.missing, the typo list).
require File.expand_path("imports", File.dirname(__FILE__))

Suite.define("static: the plugins layer is declared, complete and optional") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  pdir = File.join(root, "plugins")

  files = Dir.glob(File.join(pdir, "*.rb")).map { |p| File.basename(p, ".rb") }.reject { |n| n == "manifest" }
  table = eval(File.read(File.join(pdir, "manifest.rb")))

  truthy "the plugins manifest is a name => detection-class table", table.is_a?(Hash)
  eq "every plugin file is in the table",
     files.reject { |n| table.has_key?(n.to_sym) }.sort, []
  eq "and every table entry has its file",
     table.keys.map { |k| k.to_s }.reject { |n| files.include?(n) }.sort, []
  falsy "each entry names a class to detect it by",
        table.values.any? { |v| v.nil? || v.to_s.strip.empty? }

  # Two tallies: :auto counts as declaring every plugin, but only named declarations prove a file is used.
  declared = {}
  by_name = {}
  Dir.glob(File.join(root, "games", "*", "manifest.rb")).sort.each do |mf|
    value = eval(File.read(mf))
    next unless value.is_a?(Hash)
    prof = File.basename(File.dirname(mf))
    auto = value[:plugins] == :auto
    names = auto ? files : value[:plugins]
    next unless names.is_a?(Array)
    names.each do |n|
      (declared[n.to_s] ||= []).push(prof)
      (by_name[n.to_s] ||= []).push(prof) unless auto
    end
  end
  eq "every plugin a profile declares exists in plugins/",
     declared.keys.reject { |n| files.include?(n) }.sort, []

  eq "and every plugin file is named by at least one profile",
     (files - by_name.keys).sort, []

  offenders = []
  Dir.glob(File.join(pdir, "*.rb")).each do |path|
    next if File.basename(path) == "manifest.rb"
    File.read(path).each_line.with_index(1) do |line, i|
      next if line.strip.start_with?("#")
      next unless line =~ /\b(after_hook|before_hook|around_hook|read_on_open|after|before|around)\s*\(\s*"/
      next if line.include?("optional")
      offenders.push("#{File.basename(path)}:#{i}")
    end
  end
  eq "every hook in plugins/ is :optional", offenders, []
end

# No two plugin readers claim the same class and method (the generic profile loads them all, so both would bind),
# nor two table entries the same detection probe. A file counts as registered once any form matches once; further
# unmatched forms in that file do not mark it silent.
Suite.define("static: no two plugin readers claim the same class and method") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  pdir = File.join(root, "plugins")

  # The shapes a reader claims a slot with; a file matching none is a failure, not clean.
  forms = [
    /(?:after_hook|before_hook|around_hook|read_on_open|override)\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /SceneWatcher\.reader\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /def_extractor\(\s*"([A-Za-z_:][\w:]*)"()/,
    # A bag decorator claims its own module, pushed into Menus.bag_decorators.
    /bag_decorators\.push\(\s*([A-Za-z_:][\w:]*)()/,
    # An override of the mod's own method: visible, but claiming no slot, since such overrides chain.
    /override\(\s*(PokeAccess::[A-Za-z_:][\w:]*)\s*,\s*:(\w[\w?!=]*)/,
    # A route-finder rule: visible, but claiming no slot, since those rules add up.
    /(PokeAccess::Pathfinder)\.(touch_source|arrival_rule|assist_source|leave_rule)\b/,
    # A top-level function's wrap: visible, but claiming no slot, since its bodies add up.
    /(PokeAccess::Hooks)\.wrap_kernel\(\s*"(\w+)"/,
    # A hook in a loop records its method variable's name, so two loops on one class under different variable
    # names, or a loop and a plain hook, are not seen to collide.
    /(?:after_hook|before_hook|around_hook|read_on_open|override)\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*([a-z_]\w*)\s*[,)]/
  ]

  claims = {}
  silent_files = []
  Dir.glob(File.join(pdir, "*.rb")).sort.each do |path|
    name = File.basename(path, ".rb")
    next if name == "manifest"
    body = File.read(path).gsub(/^\s*#.*$/, "")
    found = 0
    forms.each do |re|
      body.scan(re) do |klass, meth|
        found += 1
        (claims["#{klass}##{meth}"] ||= []) << name unless klass.start_with?("PokeAccess::")
      end
    end
    silent_files.push(name) if found == 0
  end

  eq "every plugin file registers through at least one form this check understands", silent_files, []

  shared = claims.select { |_slot, files| files.uniq.length > 1 }
  eq "and no slot is claimed by two different plugins",
     shared.map { |slot, files| "#{slot} <- #{files.uniq.sort.join(', ')}" }.sort, []

  table = eval(File.read(File.join(pdir, "manifest.rb")))
  dup_probes = table.values.map { |v| v.to_s }.group_by { |v| v }.select { |_k, v| v.length > 1 }
  eq "nor do two table entries share a detection probe", dup_probes.keys.sort, []
end

# The diagnostic reports a plugin the game has and no profile declared.
Suite.define("plugins: a plugin the game has but nobody declared shows up in the diagnostic") do
  pl = PokeAccess::Plugins
  saved_loaded = pl.loaded.dup
  saved_table = pl.table
  begin
    Object.const_set(:PaSpecPluginScene, Class.new) unless Object.const_defined?(:PaSpecPluginScene)
    pl.table = { :spec_present => "PaSpecPluginScene", :spec_absent => "PaSpecNoSuchScene" }
    pl.loaded.clear

    eq "a plugin whose class IS in the game and was never declared is reported",
       pl.undeclared, ["spec_present"]

    pl.note_loaded("spec_present")
    eq "once declared and loaded it stops being reported", pl.undeclared, []
    eq "and noting it twice does not duplicate it",
       (pl.note_loaded("spec_present"); pl.loaded.grep(/spec_present/).length), 1

    pl.loaded.clear
    pl.table = { :spec_absent => "PaSpecNoSuchScene" }
    eq "a plugin the game does NOT have is never reported, declared or not", pl.undeclared, []

    pl.table = "no soy un hash"
    eq "a broken table degrades to reporting nothing instead of raising in the diag", pl.undeclared, []
  ensure
    pl.loaded.replace(saved_loaded)
    pl.table = saved_table
  end
end

# A plugin that only reopens an engine class is detected by a "Class#method" probe (through Engine.has?), since its
# class is in every game.
Suite.define("plugins: a plugin that reopens an engine class is detected by its method") do
  pl = PokeAccess::Plugins
  saved_loaded = pl.loaded.dup
  saved_table = pl.table
  begin
    unless Object.const_defined?(:PaSpecHostScene)
      Object.const_set(:PaSpecHostScene, Class.new { def pa_spec_added_by_plugin; end })
    end
    pl.loaded.clear

    pl.table = { :spec_reopener => "PaSpecHostScene#pa_spec_added_by_plugin" }
    eq "the plugin is found by the method it adds", pl.undeclared, ["spec_reopener"]

    pl.table = { :spec_reopener => "PaSpecHostScene#pa_spec_never_defined" }
    eq "and the same class WITHOUT the method is not reported", pl.undeclared, []

    pl.table = { :spec_plain => "PaSpecHostScene" }
    eq "a plain class name still works exactly as before", pl.undeclared, ["spec_plain"]
  ensure
    pl.loaded.replace(saved_loaded)
    pl.table = saved_table
  end
end

# Every profile with a plugin list declares exactly the plugins its game ships, per plugin_census.txt (from
# build_fangame_census.rb): a missing one is a silent screen, a spurious one a false claim about the game.
Suite.define("static: every profile declares the plugins its game actually ships, and only those") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  table = eval(File.read(File.join(root, "plugins", "manifest.rb")))

  census = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "plugin_census.txt")) do |cls, profs|
    census[cls] = profs.to_s.split(",").map { |p| p.strip }.reject { |p| p.empty? }
  end
  truthy "the census was read and is not empty", census.length > 5

  # The census key for a probe: a plain class by its short name, a Class#method probe with both halves (its class
  # alone is in every game).
  probe_key = lambda do |v|
    s = v.to_s
    s.include?("#") ? "#{s.split('#').first.split('::').last}##{s.split('#').last}" : s.split("::").last
  end
  unknown = table.values.map { |v| probe_key.call(v) }.uniq.reject { |c| census.key?(c) }
  eq "every detection class is in the census (regenerate it after adding a plugin)", unknown.sort, []

  declared = {}
  Imports.folders.reject { |f| Imports.common?(f) }.each do |prof|
    list = Imports.plugins(prof)
    declared[prof] = list if list.is_a?(Array)
  end

  missing = []
  spurious = []
  table.each do |name, probe|
    ships = census[probe_key.call(probe)] || []
    declared.each do |prof, list|
      has = ships.include?(prof)
      said = list.include?(name.to_s)
      missing.push("#{prof} ships #{name} and does not declare it") if has && !said
      spurious.push("#{prof} declares #{name} and does not ship it") if !has && said
    end
  end
  eq "no profile is missing a declaration for a plugin it ships", missing.sort, []
  eq "and none declares a plugin its game does not ship", spurious.sort, []
end

Suite.define("plugins: the game's own register is read, and absent is not the same as empty") do
  pl = PokeAccess::Plugins

  falsy "a game with no plugin manager answers nil, not an empty list", pl.game_plugins

  begin
    Object.const_set(:PluginManager, Module.new do
      def self.plugins; ["Deluxe Battle Kit", "Sin Version"]; end
      def self.version(n); n == "Deluxe Battle Kit" ? "1.3.0.4" : nil; end
    end)
    got = pl.game_plugins
    eq "the register is read, sorted, with the version where there is one",
       got, ["Deluxe Battle Kit 1.3.0.4", "Sin Version"]
  ensure
    Object.send(:remove_const, :PluginManager) if Object.const_defined?(:PluginManager)
  end
end
