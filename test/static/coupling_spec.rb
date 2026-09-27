require File.expand_path(File.join(File.dirname(__FILE__), "imports"))
# No constant crosses layers: one core version, profile or plugin never names another's, shared core names no
# version, plugins name no profile and nothing else names a plugin; a name core also defines is core's. A profile
# naming what a common it imports defines is no coupling: the common is loaded for it. Strings couple by name, which
# is allowed; only their #{} interpolations count as code.
Suite.define("static: no undeclared coupling between versions, profiles, or shared->version") do
  root = File.expand_path("../..", File.dirname(__FILE__))
  versions = [:gen6, :v21, :v22]

  # [file, name] => why that file may name that module across layers. Empty, and meant to stay so.
  whitelist = {}

  imported = {}
  Imports.folders.each { |p| Imports.of(p).each { |c| imported["#{p}/#{c}"] = true } }
  game_of = lambda { |rel| rel =~ %r{\Agames/([^/]+)/} ? $1 : nil }

  layer_of = lambda do |rel|
    if rel =~ %r{\Acore/}
      rel =~ %r{core/[^/]+/(gen6|v21|v22)/} ? $1.to_sym : :shared
    elsif rel =~ %r{\Aplugins/}
      :plugins
    elsif rel =~ %r{\Agames/([^/]+)/}
      :"game_#{$1}"
    end
  end

  files = Dir.glob(File.join(root, "core", "**", "*.rb")) + Dir.glob(File.join(root, "games", "**", "*.rb")) +
          Dir.glob(File.join(root, "plugins", "**", "*.rb"))
  files = files.map { |f| f[(root.length + 1)..-1].tr("\\", "/") }
  files = files.reject { |f| f == "core/manifest.rb" || f == "plugins/manifest.rb" || f =~ %r{games/[^/]+/manifest\.rb} }

  defs = {}
  mod_defs = {}
  files.each do |rel|
    File.read(File.join(root, rel)).each_line do |line|
      if line =~ /\A  (?:module|class) (\w+)/
        (defs[$1] ||= []) << rel
        (mod_defs[$1] ||= []) << rel
      elsif line =~ /\A  ([A-Z][A-Za-z0-9_]*) *=/
        (defs[$1] ||= []) << rel
      end
    end
  end
  owner = {}
  defs.each do |name, places|
    core_def = places.find { |p| p =~ %r{\Acore/} }
    owner[name] = core_def || places.first
  end

  violations = []
  files.each do |rel|
    from = layer_of.call(rel)
    next unless from
    code = File.read(File.join(root, rel)).gsub(/#(?!\{).*/, "")
    code = code.gsub(/"(?:\\.|[^"\\])*"/) { |m| m.scan(/\#\{([^}]*)\}/).join(" ") }
    code = code.gsub(/'(?:\\.|[^'\\])*'/, "''")
    code.scan(/\b([A-Z][A-Za-z0-9_]*)\b/).flatten.uniq.each do |id|
      deff = owner[id]
      next if deff.nil? || deff == rel
      to = layer_of.call(deff)
      next unless to
      next if whitelist[[rel, id]]
      next if imported["#{game_of.call(rel)}/#{game_of.call(deff)}"]
      if versions.include?(from) && versions.include?(to) && from != to
        violations << "version cross: #{rel} (#{from}) uses #{id} defined in #{deff} (#{to})"
      elsif from.to_s.index("game_") == 0 && to.to_s.index("game_") == 0 && from != to
        violations << "profile cross: #{rel} uses #{id} defined in #{deff}"
      elsif from == :shared && versions.include?(to)
        violations << "shared->version: #{rel} uses #{id} defined in #{deff} (#{to})"
      elsif from == :plugins && (to.to_s.index("game_") == 0)
        violations << "plugin->profile: #{rel} uses #{id} defined in #{deff}"
      elsif from == :plugins && to == :plugins && deff != rel
        violations << "plugin->plugin: #{rel} uses #{id} defined in #{deff}"
      elsif to == :plugins && from != :plugins
        violations << "#{from}->plugin: #{rel} uses #{id} defined in #{deff}"
      end
    end
  end

  # No profile reopens a core module (a replacement goes through Hooks.override), except Config for its constants.
  mod_defs.each do |name, places|
    next if name == "Config"
    next unless places.any? { |p| p =~ %r{\Acore/} }
    places.each do |p|
      next unless layer_of.call(p).to_s.index("game_") == 0
      next if whitelist[[p, name]]
      violations << "profile reopens core module: #{p} redefines #{name} (use Hooks.override)"
    end
  end

  truthy "the scan saw a realistic module census", defs.length > 100
  eq "no undeclared cross-layer references", violations.sort, []
end

# No capitalized string in core/ names a class only one surveyed fangame defines (fangame_classes.txt); such a file
# moves to its profile or plugins/, or is declared below with its reason.
Suite.define("static: no core/ file names a class only one fangame has") do
  root = File.expand_path("../..", File.dirname(__FILE__))

  # [file, class name] => why that core file may name a single-game class. Empty, and meant to stay so.
  declared = {}

  census = {}
  PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "fangame_classes.txt")) { |k, v| census[k] = v }
  truthy "the fangame class census loaded", census.length > 300

  hits = []
  found = {}
  Dir.glob(File.join(root, "core", "**", "*.rb")).sort.each do |f|
    rel = f[(root.length + 1)..-1].tr("\\", "/")
    code = File.read(f).gsub(/#(?!\{).*/, "")
    code.scan(/["']([A-Z][A-Za-z0-9_:]*)["']/).flatten.uniq.each do |raw|
      name = raw.split("::").last
      next unless census[name]
      found[[rel, name]] = true
      next if declared[[rel, name]]
      hits.push("#{rel} names #{name} (only in #{census[name]})")
    end
  end
  eq "no core/ file names an undeclared single-game class", hits.sort, []
  stale = declared.keys.reject { |k| found[k] }
  eq "every declared exception is still a real reference", stale.map { |k| k.join(" -> ") }.sort, []
end
