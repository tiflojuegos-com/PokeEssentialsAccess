# A report on a fangame, new to the mod or already profiled: the engine it runs on, its Essentials version and era, the
# plugins it ships against the readers the mod has, the Ruby methods it redefines, its screens no reader hooks, those
# with their own input loop no loaded file names (tools/silent_screens.rb), what its passability reads beyond the
# map, and the profile the launcher would give it today.
#   ruby tools/onboard.rb "<game folder>"                     # the report on stdout
#   ruby tools/onboard.rb "<game folder>" --out report.md     # the report to a file
#   ruby tools/onboard.rb "<game folder>" --scripts <dump>    # reuse a dump instead of extracting the scripts
#   ruby tools/onboard.rb "<game folder>" --profile <name>    # counts that profile's hooks; writes games/<name>/ (manifest
#                                                             # and constants) when it does not exist yet
# Without --profile, the profile the catalog gives the game is counted, if any.
require "json"
require "tmpdir"
require "prism"
require_relative "dump_scripts"
require_relative "game_overrides"
require_relative "silent_screens"

SCREEN_NAME = /(Scene|Screen|Menu|Window|Panel|UI)\z|\A(Scene|Window)_|_(Scene|Screen|Menu)/
SCREEN_ENTRY = %w[pbStartScene pbStartScreen main pbMain update pbUpdate].freeze
# The registrations that name the class they read by a string, besides the hooks: declared readers, extractors,
# information windows and the hall of fame's binding.
NAMED_READERS = /\b(?:FocusReader\.define|focus_reader|def_extractor|screen_reader|SceneWatcher\.reader|info_window|
                  InfoWindow\.watch|hall_of_fame)\(?\s*"([A-Z][\w:]*)"/x
PASSABILITY = %w[passable? passableEx? playerPassable? passable_ex? can_move_in_direction? can_move_from_coordinate?
                 terrain_tag pbIsPassableWaterTag? check_event_trigger_touch].freeze
STATE_READ = /\$game_switches\[[^\]]+\]|\$game_variables\[[^\]]+\]|\$PokemonGlobal\.\w+|\$PokemonMap\.\w+|\$game_system\.\w+/
TOOLING = /Editor|Debug|Compiler|Tileset|_Main\.rb\z/
BASE_WINDOWS = %w[Window SpriteWindow IconWindow PictureWindow EventScene].freeze
# Engine classes named like screens that show nothing of their own to read.
PLUMBING = %w[Game_Screen Scene_Map Scene_DebugIntro].freeze

def option(name)
  i = ARGV.index(name)
  i ? ARGV[i + 1] : nil
end

# What the game folder says about the engine it runs on.
def engine_facts(game)
  facts = []
  exe = File.join(game, "Game.exe")
  facts << "Game.exe: #{(File.size(exe) / 1048576.0).round(1)} MB" if File.file?(exe)
  facts << "mkxp.json: present (mkxp-z)" if File.file?(File.join(game, "mkxp.json"))
  ini = File.join(game, "Game.ini")
  if File.file?(ini)
    text = File.read(ini, :encoding => "BINARY")
    facts << "Game.ini library: #{text[/^Library=(.*)$/, 1].to_s.strip}" if text =~ /^Library=/
    facts << "Game.ini title: #{text[/^Title=(.*)$/, 1].to_s.strip}" if text =~ /^Title=/
  end
  Dir.glob(File.join(game, "*ruby*.dll")).each do |f|
    v = File.basename(f)[/ruby(\d)(\d)(\d)/] ? "Ruby #{$1}.#{$2}" : "?"
    facts << "#{File.basename(f)}: #{v}"
  end
  facts << "Game.rgssad: the data is packed" if File.file?(File.join(game, "Game.rgssad"))
  facts << "accessibility/: the mod is installed" if File.directory?(File.join(game, "accessibility"))
  facts
end

# Every class body of the scripts as { "Path::Name" => { :file, :methods => [names] } }, through Prism (an older
# Ruby's syntax still yields what it can).
def index_scripts(dir)
  classes = {}
  Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |f|
    src = File.binread(f).force_encoding("UTF-8")
    src = src.encode("UTF-8", "binary", :invalid => :replace, :undef => :replace) unless src.valid_encoding?
    walk_classes(Prism.parse(src).value, [], File.basename(f), classes)
  end
  classes
end

def walk_classes(node, path, file, classes)
  if node.is_a?(Prism::ClassNode) || node.is_a?(Prism::ModuleNode)
    name = node.constant_path.slice.sub(/\A::/, "")
    full = (name.include?("::") ? [name] : path + [name]).join("::")
    entry = (classes[full] ||= { :file => file, :methods => [] })
    entry[:super] ||= node.superclass.slice.split("::").last if node.is_a?(Prism::ClassNode) && node.superclass
    body = node.body ? node.body.compact_child_nodes : []
    body.each do |c|
      entry[:methods] << c.name.to_s if c.is_a?(Prism::DefNode) && c.receiver.nil?
      walk_classes(c, full.split("::"), file, classes)
    end
    return
  end
  node.compact_child_nodes.each { |c| walk_classes(c, path, file, classes) }
end

# The plugin readers of plugins/manifest.rb whose probe the scripts define: a class name, or "Class#method".
def matching_readers(classes)
  table = eval(File.read(File.join(ROOT, "plugins", "manifest.rb")))
  by_last = Hash.new { |h, k| h[k] = [] }
  classes.each { |full, e| by_last[full.split("::").last] << e }
  table.select do |_name, probe|
    cls, meth = probe.to_s.split("#")
    hits = classes[cls] ? [classes[cls]] : by_last[cls.split("::").last]
    meth ? hits.any? { |e| e[:methods].include?(meth) } : !hits.empty?
  end.keys.map { |k| k.to_s }.sort
end

# The nearest ancestor of a class that the mod hooks, followed through the game's own superclasses, or nil.
def hooked_ancestor(name, supers, hooked)
  seen = {}
  sup = supers[name]
  while sup && !seen[sup]
    return sup if hooked.include?(sup)
    seen[sup] = true
    sup = supers[sup]
  end
  nil
end

# A profile's folders (its own and the commons it imports) and the plugin readers its manifest lists; [[], []] for a
# profile that does not exist yet.
def profile_parts(name)
  path = File.join(ROOT, "games", name.to_s, "manifest.rb")
  return [[], []] unless File.file?(path)
  m = eval(File.read(path))
  [[name.to_s] + (m[:imports] || []), m[:plugins].is_a?(Array) ? m[:plugins] : []]
end

# The class names the mod hooks in this game, by their last segment: core's, the plugin readers it loads and its
# profile's with the commons it imports (games/generic without one), never another game's.
def hooked_classes(profile, readers)
  require File.join(ROOT, "test", "static", "reader_sites")
  dirs, listed = profile ? profile_parts(profile) : [["generic"], []]
  plugins = readers | listed
  sources = ReaderSites.sources.select do |path, _body|
    path.start_with?("core/") || plugins.include?(path[%r{\Aplugins/(\w+)\.rb\z}, 1].to_s) ||
      dirs.any? { |d| path.start_with?("games/#{d}/") }
  end
  named = sources.values.map { |body| body.scan(NAMED_READERS).flatten }.flatten
  (ReaderSites.hooked_pairs(sources).keys.map { |k| k.split("#").first } + named).map { |c| c.split("::").last }.uniq
end

# The definitions of the passability methods, each with the state it reads beyond the map.
def passability_reads(dir)
  out = []
  Dir.glob(File.join(dir, "**", "*.rb")).sort.each do |f|
    src = File.binread(f).force_encoding("UTF-8")
    src = src.encode("UTF-8", "binary", :invalid => :replace, :undef => :replace) unless src.valid_encoding?
    stack = [Prism.parse(src).value]
    until stack.empty?
      n = stack.pop
      if n.is_a?(Prism::DefNode) && PASSABILITY.include?(n.name.to_s)
        reads = n.slice.scan(STATE_READ).uniq
        out << "#{File.basename(f)}:#{n.location.start_line} #{n.name}#{reads.empty? ? '' : ' reads ' + reads.join(', ')}"
      end
      stack.concat(n.compact_child_nodes)
    end
  end
  out
end

# The catalog profile the launcher would pick by title or folder name, or nil.
def catalog_match(game, title)
  catalog = JSON.parse(File.read(File.join(ROOT, "games", "catalog.json")))["profiles"]
  t = title.to_s.downcase
  by_title = catalog.map { |p| [p, (p["titles"] || []).select { |x| t.include?(x) }.map { |x| x.length }.max] }
  best = by_title.select { |_p, n| n }.max_by { |_p, n| n }
  return [best[0]["key"], "title"] if best
  name = File.basename(game).downcase
  hit = catalog.select { |p| p["detect"] && name =~ Regexp.new(p["detect"], Regexp::IGNORECASE) }.first
  hit ? [hit["key"], "folder name"] : nil
end

game = ARGV[0]
abort "usage: ruby tools/onboard.rb \"<game folder>\" [--out file] [--scripts dump] [--profile name]" unless game && File.directory?(game)
report = []
Dir.mktmpdir("pa-onboard") do |tmp|
  dump = option("--scripts")
  unless dump
    dump = File.join(tmp, "scripts")
    ScriptDumper.dump(game, dump)
  end
  all_src = Dir.glob(File.join(dump, "**", "*.rb")).map { |f| File.binread(f) }.join("\n")
  version = all_src[/ESSENTIALS_?VERSION\s*=\s*"([^"]+)"/, 1]
  era = all_src =~ /^\s*module\s+GameData\b/ ? "gamedata" : "gen6"
  title = engine_facts(game).map { |l| l[/\AGame\.ini title: (.*)/, 1] }.compact.first
  if File.file?(File.join(game, "mkxp.json"))
    title = File.read(File.join(game, "mkxp.json"), :encoding => "UTF-8")[/"windowTitle"\s*:\s*"([^"]+)"/, 1] || title
  end
  classes = index_scripts(dump)
  readers = matching_readers(classes)
  shipped = Dir.glob(File.join(dump, "_PluginScripts", "*")).map { |d| File.basename(d) }.sort
  match = catalog_match(game, title)
  profile = option("--profile") || (match && match[0])
  hooked = hooked_classes(profile, readers)
  screens = classes.select do |full, e|
    last = full.split("::").last
    scene = [last.sub(/Screen\z/, "Scene"), last.sub(/Screen\z/, "_Scene"), "#{last}_Scene", last.sub(/Screen\z/, "")]
    last =~ SCREEN_NAME && !(e[:methods] & SCREEN_ENTRY).empty? && !hooked.include?(last) &&
      (scene & hooked).empty? && e[:file] !~ TOOLING && !BASE_WINDOWS.include?(last) && !PLUMBING.include?(last)
  end

  report << "# #{title || File.basename(game)}"
  report << "" << "## Engine" << ""
  engine_facts(game).each { |l| report << "- #{l}" }
  report << "- Essentials version: #{version || 'not declared (v18 or older; script names tell the era)'}"
  report << "- Era for the mod: #{era}"
  report << "- The launcher's catalog would give it: #{match ? "#{match[0]} (by #{match[1]})" : 'nothing (it would ask)'}"
  report << "" << "## Plugins" << ""
  report << "- Readers the mod has whose probe this game defines: #{readers.empty? ? 'none' : readers.join(' ')}"
  report << "- Plugins the game ships (PluginScripts): #{shipped.empty? ? 'none (or scripts pasted into the editor)' : shipped.join(', ')}"
  report << "" << "## Ruby methods the game redefines" << ""
  lines = summary_lines(redefinitions(dump))
  report.concat(lines.empty? ? ["- none"] : lines.map { |l| "- #{l}" })
  report << "" << "Check them: `ruby tools/game_overrides.rb <dump> --run`." unless lines.empty?
  supers = {}
  classes.each { |full, e| supers[full.split("::").last] ||= e[:super] }
  inherited = {}
  screens.keys.each { |full| (a = hooked_ancestor(full.split("::").last, supers, hooked)) && inherited[full] = a }
  bare = screens.keys.reject { |full| inherited[full] }.sort
  counted = profile ? "core, its plugin readers and the #{profile} profile" : "core, its plugin readers and games/generic"
  report << "" << "## Screens no reader hooks (#{bare.length}, counting #{counted})" << ""
  bare.each { |full| report << "- #{full} (#{screens[full][:file]})" }
  looping = SilentScreens.candidates(dump, profile || "generic")
  report << "" << "## Screens with their own input loop no loaded file names (#{looping.length})" << ""
  triage_keys = [File.basename(dump), profile] + ReaderSites::PROFILE_OF.select { |_d, p| p == profile }.keys
  looping.each do |r|
    why = triage_keys.compact.map { |k| SilentScreens.checked_why(r[:name], k) }.compact.first
    report << "- #{SilentScreens.line(r)}#{why ? " -- checked: #{why}" : ''}"
  end
  report << "" << "## Screens read only through a hooked ancestor (#{inherited.length}: read when they call up to it)" << ""
  inherited.keys.sort.each { |full| report << "- #{full} < #{inherited[full]} (#{screens[full][:file]})" }
  report << "" << "## Passability (what it reads beyond the map, for plain_passability)" << ""
  passability_reads(dump).each { |l| report << "- #{l}" }

  name = option("--profile")
  if name && !File.exist?(File.join(ROOT, "games", name))
    dir = File.join(ROOT, "games", name)
    Dir.mkdir(dir)
    File.binwrite(File.join(dir, "manifest.rb"),
               "# Load order for the #{name} game modules (no .rb), loaded after core, and the plugin readers it takes\n" \
               "# from plugins/.\n{\n  :modules => %w[\n    constants\n  ],\n  :plugins => %w[#{readers.join(' ')}]\n}\n")
    File.binwrite(File.join(dir, "constants.rb"),
               "# #{title || name}: the profile's name and its game-wide settings.\n" \
               "PokeAccess::Game.define(#{name.inspect}) do\nend\n")
    report << "" << "## Profile" << "" << "- Wrote games/#{name}/manifest.rb and constants.rb; add its entry to games/catalog.json:"
    report << "  `{\"key\": \"#{name}\", \"display\": \"#{title}\", \"titles\": [\"#{title.to_s.downcase}\"], " \
              "\"detect\": \"\", \"exes\": [], \"engine\": \"#{era}\"}`"
  end
end

out = option("--out")
if out
  File.binwrite(out, report.join("\n") + "\n")
  puts "wrote #{out}"
else
  puts report
end
