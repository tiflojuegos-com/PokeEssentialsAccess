# No constant crosses layers: one core version, profile or plugin never names another's, shared core names no
# version, plugins name no profile and nothing else names a plugin, and a name core also defines is core's; a profile
# naming what a common it imports defines is no coupling. Strings couple by name, which is allowed: only their #{}
# interpolations count as code. No profile reopens a core module, and no core file names a class one fangame alone has.
require File.expand_path(File.join(File.dirname(__FILE__), "imports"))

class CouplingTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  VERSIONS = [:gen6, :v21, :v22].freeze
  # [file, name] => why that file may name that module across layers. Empty, and meant to stay so.
  ALLOWED_CROSSINGS = {}.freeze
  # [core file, class name] => why that core file may name a single-game class. Empty, and meant to stay so.
  SINGLE_GAME_NAMES = {}.freeze
  # A small tree with one crossing of each kind.
  CROSSED = [
    ["core/battle/gen6/a.rb", "module PokeAccess\n  module GenSix\n  end\nend\n"],
    ["core/battle/v21/b.rb", "module PokeAccess\n  module VTwentyOne\n    X = GenSix\n  end\nend\n"],
    ["core/util/shared.rb", "module PokeAccess\n  module Shared\n    Y = VTwentyOne\n  end\nend\n"],
    ["games/anil/a.rb", "module PokeAccess\n  module AnilOnly\n  end\nend\n"],
    ["games/royal/r.rb", "module PokeAccess\n  module RoyalOnly\n    Z = AnilOnly\n  end\nend\n"],
    ["plugins/p1.rb", "module PokeAccess\n  module PluginOne\n    W = RoyalOnly\n  end\nend\n"],
    ["plugins/p2.rb", "module PokeAccess\n  module PluginTwo\n    V = PluginOne\n  end\nend\n"],
    ["games/emerald/e.rb", "PokeAccess::PluginTwo.go\n"],
    ["core/util/c.rb", "PokeAccess::PluginOne.go\n"]
  ].freeze

  test "names no constant another layer defines, past what a profile's imports bring" do
    tree = mod_tree
    assert_operator owners(tree).length, :>, 100, "the scan saw a realistic module census"
    assert_equal [], crossings(tree, imported_commons)
  end

  test "no profile reopens a core module but Config" do
    assert_equal [], reopened(mod_tree)
  end

  test "names in core no class that only one surveyed fangame defines" do
    census = fangame_census
    assert_operator census.length, :>, 300, "the fangame class census loaded"
    core = Dir.glob(File.join(ROOT, "core", "**", "*.rb")).sort.map { |f| [f.sub(ROOT + "/", ""), File.read(f)] }
    assert_equal [], single_game_names(core, census)
  end

  test "reports a constant each layer may not take from another, with both files" do
    assert_equal ["game_emerald->plugin: games/emerald/e.rb uses PluginTwo defined in plugins/p2.rb",
                  "plugin->plugin: plugins/p2.rb uses PluginOne defined in plugins/p1.rb",
                  "plugin->profile: plugins/p1.rb uses RoyalOnly defined in games/royal/r.rb",
                  "profile cross: games/royal/r.rb uses AnilOnly defined in games/anil/a.rb",
                  "shared->plugin: core/util/c.rb uses PluginOne defined in plugins/p1.rb",
                  "shared->version: core/util/shared.rb uses VTwentyOne defined in core/battle/v21/b.rb (v21)",
                  "version cross: core/battle/v21/b.rb (v21) uses GenSix defined in core/battle/gen6/a.rb (gen6)"],
                 crossings(CROSSED, {})
  end

  test "spares a crossing the allow table declares" do
    allowed = { ["games/royal/r.rb", "AnilOnly"] => "planted" }
    found = crossings(CROSSED, {}, allowed)
    assert_equal [], found.grep(/AnilOnly/), "the declared crossing"
    assert_equal 6, found.length, "the others stay"
  end

  test "spares a name in a comment or a string, and counts one a string interpolates" do
    anil = ["games/anil/a.rb", "module PokeAccess\n  module AnilOnly\n  end\nend\n"]
    quoted = ['# AnilOnly', 'x = "AnilOnly"', "y = 'AnilOnly'"].join("\n")
    assert_equal [], crossings([anil, ["games/royal/r.rb", quoted]], {})
    interpolated = 'z = "#{AnilOnly.name}"'
    assert_equal ["profile cross: games/royal/r.rb uses AnilOnly defined in games/anil/a.rb"],
                 crossings([anil, ["games/royal/r.rb", interpolated]], {})
  end

  test "spares a profile naming what a common it imports defines" do
    tree = [["games/rv_common/a.rb", "module PokeAccess\n  module RvThing\n  end\nend\n"],
            ["games/reborn/b.rb", "PokeAccess::RvThing.go\n"]]
    assert_equal ["profile cross: games/reborn/b.rb uses RvThing defined in games/rv_common/a.rb"], crossings(tree, {})
    assert_equal [], crossings(tree, "reborn/rv_common" => true)
  end

  test "takes a name core also defines as core's, wherever it comes first" do
    tree = [["games/anil/a.rb", "module PokeAccess\n  module Shared\n  end\nend\n"],
            ["core/util/s.rb", "module PokeAccess\n  module Shared\n  end\nend\n"],
            ["games/royal/r.rb", "PokeAccess::Shared.go\n"]]
    assert_equal [], crossings(tree, {})
  end

  test "reports a profile reopening a core module, Config and plugins aside" do
    tree = [["core/a.rb", "module PokeAccess\n  module Battle\n  end\n  module Config\n  end\nend\n"],
            ["games/anil/b.rb", "module PokeAccess\n  module Battle\n  end\n  module Config\n  end\nend\n"],
            ["plugins/p.rb", "module PokeAccess\n  module Battle\n  end\nend\n"]]
    assert_equal ["profile reopens core module: games/anil/b.rb redefines Battle (use Hooks.override)"], reopened(tree)
  end

  test "reports a core string naming a single-game class by its last segment, comments aside" do
    core = [["core/x.rb", "after(\"PlantedOnlyScene\", :x)\n# \"PlantedCommented\"\nPlantedBare = 1\n"],
            ["core/y.rb", "k = 'Planted::PlantedOnlyScene'\n"]]
    census = { "PlantedOnlyScene" => "anil, script", "PlantedCommented" => "royal, plugin",
               "PlantedBare" => "z, script" }
    assert_equal ["core/x.rb names PlantedOnlyScene (only in anil, script)",
                  "core/y.rb names PlantedOnlyScene (only in anil, script)"], single_game_names(core, census)
  end

  test "spares a declared single-game name and reports a declaration nothing uses" do
    core = [["core/x.rb", "after(\"PlantedOnlyScene\", :x)\n"]]
    census = { "PlantedOnlyScene" => "anil, script" }
    declared = { ["core/x.rb", "PlantedOnlyScene"] => "planted", ["core/y.rb", "PlantedGone"] => "planted" }
    assert_equal ["declared but not named: core/y.rb -> PlantedGone"], single_game_names(core, census, declared)
  end

  private

  # The mod's files, manifests aside, as [relative path, text].
  def mod_tree
    files = %w[core games plugins].map { |d| Dir.glob(File.join(ROOT, d, "**", "*.rb")) }.flatten.sort
    rels = files.map { |f| f[(ROOT.length + 1)..-1].tr("\\", "/") }
    rels = rels.reject { |f| %w[core/manifest.rb plugins/manifest.rb].include?(f) || f =~ %r{games/[^/]+/manifest\.rb} }
    rels.map { |rel| [rel, File.read(File.join(ROOT, rel))] }
  end

  # { "profile/common" => true } for each common a profile's manifest imports.
  def imported_commons
    out = {}
    Imports.folders.each { |p| Imports.of(p).each { |c| out["#{p}/#{c}"] = true } }
    out
  end

  # { class name => "game, origin" } from fangame_classes.txt.
  def fangame_census
    out = {}
    PokeAccess::KVFile.each(File.join(File.dirname(__FILE__), "fangame_classes.txt")) { |k, v| out[k] = v }
    out
  end

  # A file's layer: a core version, shared core, plugins or its profile, or nil.
  def layer_of(rel)
    if rel =~ %r{\Acore/}
      rel =~ %r{core/[^/]+/(gen6|v21|v22)/} ? $1.to_sym : :shared
    elsif rel =~ %r{\Aplugins/}
      :plugins
    elsif rel =~ %r{\Agames/([^/]+)/}
      :"game_#{$1}"
    end
  end

  # The profile folder a games/ file sits in, or nil.
  def game_of(rel)
    rel =~ %r{\Agames/([^/]+)/} ? $1 : nil
  end

  # { name => [file, ...] } of the modules, classes and constants defined at the mod's top level (two spaces in), and
  # the modules and classes alone.
  def definitions(tree)
    defs = {}
    mods = {}
    tree.each do |rel, text|
      text.each_line do |line|
        if line =~ /\A  (?:module|class) (\w+)/
          (defs[$1] ||= []) << rel
          (mods[$1] ||= []) << rel
        elsif line =~ /\A  ([A-Z][A-Za-z0-9_]*) *=/
          (defs[$1] ||= []) << rel
        end
      end
    end
    [defs, mods]
  end

  # { name => file } owning each top-level name: core's definition when core has one, else the first.
  def owners(tree)
    out = {}
    definitions(tree)[0].each { |name, places| out[name] = places.find { |p| p =~ %r{\Acore/} } || places.first }
    out
  end

  # The code of a file as the scan reads it: comments gone, strings reduced to their #{} interpolations.
  def code_of(text)
    code = text.gsub(/#(?!\{).*/, "")
    code = code.gsub(/"(?:\\.|[^"\\])*"/) { |m| m.scan(/\#\{([^}]*)\}/).join(" ") }
    code.gsub(/'(?:\\.|[^'\\])*'/, "''")
  end

  # Each name a file takes from a layer it may not, sorted; imported names a profile's commons, allowed the declared
  # crossings.
  def crossings(tree, imported, allowed = ALLOWED_CROSSINGS)
    owner = owners(tree)
    out = []
    tree.each do |rel, text|
      from = layer_of(rel)
      next unless from
      code_of(text).scan(/\b([A-Z][A-Za-z0-9_]*)\b/).flatten.uniq.each do |id|
        deff = owner[id]
        next if deff.nil? || deff == rel
        to = layer_of(deff)
        next if to.nil? || allowed[[rel, id]] || imported["#{game_of(rel)}/#{game_of(deff)}"]
        why = crossing(rel, from, id, deff, to)
        out << why if why
      end
    end
    out.sort
  end

  # What is wrong with rel (in layer from) naming id, defined in deff (in layer to), or nil.
  def crossing(rel, from, id, deff, to)
    if VERSIONS.include?(from) && VERSIONS.include?(to) && from != to
      "version cross: #{rel} (#{from}) uses #{id} defined in #{deff} (#{to})"
    elsif from.to_s.index("game_") == 0 && to.to_s.index("game_") == 0 && from != to
      "profile cross: #{rel} uses #{id} defined in #{deff}"
    elsif from == :shared && VERSIONS.include?(to)
      "shared->version: #{rel} uses #{id} defined in #{deff} (#{to})"
    elsif from == :plugins && to.to_s.index("game_") == 0
      "plugin->profile: #{rel} uses #{id} defined in #{deff}"
    elsif from == :plugins && to == :plugins
      "plugin->plugin: #{rel} uses #{id} defined in #{deff}"
    elsif to == :plugins && from != :plugins
      "#{from}->plugin: #{rel} uses #{id} defined in #{deff}"
    end
  end

  # Each profile file that reopens a module or class core defines, Config (for its constants) aside.
  def reopened(tree, allowed = ALLOWED_CROSSINGS)
    out = []
    definitions(tree)[1].each do |name, places|
      next if name == "Config" || places.none? { |p| p =~ %r{\Acore/} }
      places.each do |p|
        next unless layer_of(p).to_s.index("game_") == 0 && !allowed[[p, name]]
        out << "profile reopens core module: #{p} redefines #{name} (use Hooks.override)"
      end
    end
    out.sort
  end

  # Each quoted name (its last segment) a core file gives that the census has one game define, and each declared
  # exception no core file names any more.
  def single_game_names(core, census, declared = SINGLE_GAME_NAMES)
    hits = []
    found = {}
    core.each do |rel, text|
      text.gsub(/#(?!\{).*/, "").scan(/["']([A-Z][A-Za-z0-9_:]*)["']/).flatten.uniq.each do |raw|
        name = raw.split("::").last
        next unless census[name]
        found[[rel, name]] = true
        hits.push("#{rel} names #{name} (only in #{census[name]})") unless declared[[rel, name]]
      end
    end
    stale = declared.keys.reject { |k| found[k] }.map { |k| "declared but not named: #{k.join(' -> ')}" }
    hits.sort + stale.sort
  end
end
