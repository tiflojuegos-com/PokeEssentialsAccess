# The plugins/ layer: readers for THIRD-PARTY plugins, loaded only by the profiles that declare them.
#
# Two rules make the layer safe, and neither survives on discipline alone:
#
#   1. A declared plugin must EXIST. A profile that names a file nobody wrote loses that screen in silence
#      -- the loader logs it and carries on, by design, so nothing else would ever complain.
#   2. Every hook in plugins/ is :optional. The plugin may be absent, or be a version that never had the
#      method: a non-optional registration would park a permanent entry in Hooks.missing, which by contract
#      is the list of TYPOS. Filling it with expected absences is how a real typo stops being noticed.
#
# The detection table is checked too: it is what lets the diagnostic tell a player "this game ships a plugin
# we know and your profile never declared it", so a plugin missing from the table is a hole in that net.
#
# eval reads the mod's OWN manifests, which are Ruby literals committed in this repo -- the same way the
# loader reads them, because RGSS has no JSON parser to use instead. No external input reaches it.
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

  # What the profiles declare has to be real, or the screen goes quiet with only a line in the log.
  #
  # Two tallies, deliberately. :auto is the generic profile asking the running game instead of naming names,
  # so for "is this reader reachable at all" it counts as declaring every one of them -- but folding it into
  # the same tally as the named ones made the second check below unfalsifiable, since it then contained
  # every file by construction. At runtime :auto loads only what detection finds, so a plugin no profile
  # names and whose probe never resolves would be invisible to both checks at once.
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

  # A plugin nobody loads is dead weight; worse, it reads as covered when no game actually uses it.
  eq "and every plugin file is named by at least one profile",
     (files - by_name.keys).sort, []

  # Rule 2, read off the source: an after/before/around/read_on_open registration without :optional.
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

# Two readers on the same slot. The generic profile declares every plugin, because it is the fallback for
# games with no profile of their own and anything it leaves out is a screen an unknown fangame silently
# loses. That is the right trade -- silence is the failure a blind player cannot diagnose -- but it has one
# sharp edge: if two plugins ever claim the SAME class and method, both readers bind on every game and the
# screen is read twice, or read by the copy that does not fit. Neither is silence; both are worse.
#
# There is no machinery to arbitrate that, on purpose: it has never happened, and a rule nobody needs yet
# is a rule that rots. What there is instead is this -- the day it happens, it fails here rather than in
# somebody's ears. The invariant for that day is that a reader in the generic set must identify ITS OWN
# plugin (an ivar, a method only its copy has) before speaking, not merely find the class.
Suite.define("static: no two plugin readers claim the same class and method") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  pdir = File.join(root, "plugins")

  # The four ways a reader claims a slot today. A file that matches none of them is not "clean", it is
  # invisible to this check, so the assertion below treats that as the failure it is.
  forms = [
    /(?:after_hook|before_hook|around_hook|read_on_open|override)\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /SceneWatcher\.reader\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /def_extractor\(\s*"([A-Za-z_:][\w:]*)"()/,
    # A hook registered in a loop names its method through a variable. What gets recorded is the VARIABLE's
    # name, not a wildcard: the class is claimed and the registration is visible, but two readers looping
    # over the same class under different variable names will not be seen to collide, and neither will a
    # loop and a plain hook on that class. The check is narrower here than everywhere else, and knowing
    # where it is blind is the point of saying so.
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
        (claims["#{klass}##{meth}"] ||= []) << name
      end
    end
    # One visible registration is enough to clear the file. A file with five of which four are invisible
    # still passes, so this catches a reader that registers in a shape nothing here parses -- not a reader
    # that registers mostly in such a shape.
    silent_files.push(name) if found == 0
  end

  eq "every plugin file registers through at least one form this check understands", silent_files, []

  shared = claims.select { |_slot, files| files.uniq.length > 1 }
  eq "and no slot is claimed by two different plugins",
     shared.map { |slot, files| "#{slot} <- #{files.uniq.sort.join(', ')}" }.sort, []

  # The detection table has the same requirement one level up: two entries answering to the same probe
  # would report each other's plugin as present.
  table = eval(File.read(File.join(pdir, "manifest.rb")))
  dup_probes = table.values.map { |v| v.to_s }.group_by { |v| v }.select { |_k, v| v.length > 1 }
  eq "nor do two table entries share a detection probe", dup_probes.keys.sort, []
end

# The detection net. Declaring by hand has one failure mode -- forgetting -- and it is SILENT: the screen
# just says nothing. This is what makes it speak up, so it has to work on the two cases that matter.
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

# The blind spot in detecting a plugin by its class: some plugins do not bring one. Deluxe Battle Kit and
# Modular UI Scenes reopen Battle and PokemonPokedexInfo_Scene instead, classes every game already has, so a
# class check answers "present" on all thirteen games and detects nothing at all. Those need a METHOD probe,
# which is why the table goes through Engine.has? and accepts the "Class#method" form.
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

    # The half a class check cannot do: same class, no plugin. Getting this wrong would report the plugin on
    # every game that merely has the class -- which is all of them.
    pl.table = { :spec_reopener => "PaSpecHostScene#pa_spec_never_defined" }
    eq "and the same class WITHOUT the method is not reported", pl.undeclared, []

    pl.table = { :spec_plain => "PaSpecHostScene" }
    eq "a plain class name still works exactly as before", pl.undeclared, ["spec_plain"]
  ensure
    pl.loaded.replace(saved_loaded)
    pl.table = saved_table
  end
end

# The generic profile does not name its plugins: it asks the running game, through the same table the
# diagnostic uses. Two things have to hold for that to be safe, and neither is obvious from reading it.
# The declaration itself, checked against the games. Everything else in this file checks the layer is
# internally consistent -- files exist, entries have files, hooks are optional. None of that catches the one
# mistake the layer actually trades for: a profile whose game SHIPS a plugin and does not declare it. That
# game loses the screen, and loses it silently -- the class is there, no hook is missing, nothing raises.
#
# plugin_census.txt says which profile ships each detection class, built from the script dumps (which live
# outside the repo, hence a committed census rather than a live scan; regenerate with
# build_fangame_census.rb). The check runs both ways, because over-declaring is not free either: harmless at
# runtime, since every hook here is :optional, but it is a false claim about a game, and the next person
# reads the manifest as documentation.
Suite.define("static: every profile declares the plugins its game actually ships, and only those") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  table = eval(File.read(File.join(root, "plugins", "manifest.rb")))

  census = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "plugin_census.txt")) do |cls, profs|
    census[cls] = profs.to_s.split(",").map { |p| p.strip }.reject { |p| p.empty? }
  end
  truthy "the census was read and is not empty", census.length > 5

  # A probe with no census line means the census predates the plugin: the check would pass by knowing
  # nothing, which is the failure mode this whole block exists to avoid.
  # The census key for a probe. A plain class keeps its short name; a Class#method probe keeps BOTH halves,
  # because the class alone would be a lie: the multi-save plugin only reopens the engine's save scene, so
  # its class is in every modern game whether the plugin is installed or not. Collapsing to the class here
  # made a method probe silently degrade into a check that could never fail.
  probe_key = lambda do |v|
    s = v.to_s
    s.include?("#") ? "#{s.split('#').first.split('::').last}##{s.split('#').last}" : s.split("::").last
  end
  unknown = table.values.map { |v| probe_key.call(v) }.uniq.reject { |c| census.key?(c) }
  eq "every detection class is in the census (regenerate it after adding a plugin)", unknown.sort, []

  declared = {}
  Dir.glob(File.join(root, "games", "*", "manifest.rb")).sort.each do |mf|
    value = eval(File.read(mf))
    next unless value.is_a?(Hash)
    # :auto asks the running game instead of naming names, so there is nothing to check against a census.
    next unless value[:plugins].is_a?(Array)
    declared[File.basename(File.dirname(mf))] = value[:plugins].map { |n| n.to_s }
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

  # No PluginManager at all is the older games' shape -- plugin code pasted into the script list, nothing
  # registered. Answering [] there would read as "this game has no plugins", which is a lie and exactly
  # the kind that sends a bug report down the wrong path.
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
