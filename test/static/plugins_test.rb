# The plugins/ layer: the manifest table and the files match, every declared plugin exists and is named by some
# profile (or, shipped by no surveyed game, has a reference copy), every hook in plugins/ is :optional (an expected
# absence must not fill Hooks.missing, the typo list), no two readers claim one slot, each profile declares what its
# game ships or reads it in its own copy; and the diagnostic's view of them (Plugins.undeclared, Plugins.game_plugins).
require File.expand_path("imports", File.dirname(__FILE__))
require File.expand_path("reference_names", File.dirname(__FILE__))

class PluginsTest < PokeAccessTest
  ROOT = File.expand_path("../..", File.dirname(__FILE__))
  PDIR = File.join(ROOT, "plugins")
  CENSUS = File.join(File.dirname(__FILE__), "plugin_census.txt")

  # A hook registration on a class named in quotes, which a game may lack: its line must carry :optional.
  HOOK_RE = /\b(after_hook|before_hook|around_hook|read_on_open|override|after|before|around)\s*\(\s*"/

  # Plugins a game ships in a copy it edited, read by its own profile instead (the version rule): its :plugins list
  # leaves them out on purpose, and they count as declared.
  OWN_COPIES = { "revival" => %w[modular_menu] }

  # The shapes a reader claims a slot ("Class#method") with; a file matching none is a failure, not clean. A claim on
  # the mod's own PokeAccess:: methods counts as registering but claims no slot, since those add up or chain.
  FORMS = [
    /(?:after_hook|before_hook|around_hook|read_on_open|override)\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /SceneWatcher\.reader\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*:(\w[\w?!=]*)/,
    /def_extractor\(\s*"([A-Za-z_:][\w:]*)"()/,
    # A bag decorator claims its own module, pushed into Menus.bag_decorators.
    /bag_decorators\.push\(\s*([A-Za-z_:][\w:]*)()/,
    # An override of the mod's own method.
    /override\(\s*(PokeAccess::[A-Za-z_:][\w:]*)\s*,\s*:(\w[\w?!=]*)/,
    # A route-finder rule.
    /(PokeAccess::Routes::(?:Moves|Effects))\.(touch_source|arrival_rule|assist_source|leave_rule)\b/,
    # A locator event rule (a name, category, hiding or mark).
    /(PokeAccess::Locator)\.register_rule\(\s*:(\w+)/,
    # A top-level function's wrap, whose bodies add up.
    /(PokeAccess::Hooks)\.wrap_kernel\(\s*"(\w+)"/,
    # A hook in a loop records its method variable's name, so two loops on one class under different variable
    # names, or a loop and a plain hook, are not seen to collide.
    /(?:after_hook|before_hook|around_hook|read_on_open|override)\(\s*"([A-Za-z_:][\w:]*)"\s*,\s*([a-z_]\w*)\s*[,)]/
  ]

  test "the manifest table and the plugin files match one to one, each entry with a probe" do
    assert_equal [], table_gaps(plugin_files, table)
  end

  test "a plugin file out of the table, an entry with no file and one with no probe are reported" do
    got = table_gaps(["alpha", "beta", "delta"], { :beta => "Beta", :gamma => "Gamma", :delta => " " })
    assert_equal ["alpha.rb is not in the table", "gamma has no file", "delta names no probe"], got
  end

  test "every plugin a profile names exists in plugins/" do
    assert_equal [], (named_plugins(manifests).keys - plugin_files).sort
  end

  test "a profile names its plugins by an explicit list; :auto and a manifest without one name none" do
    got = named_plugins("alpha" => { :plugins => [:one, "two"] }, "beta" => { :plugins => :auto },
                        "gamma" => { :modules => [] }, "delta" => { :plugins => ["two"] })
    assert_equal({ "one" => ["alpha"], "two" => ["alpha", "delta"] }, got)
  end

  test "every plugin file is named by a profile, or is a generic-only reader with a reference copy" do
    reference = lambda { |probe| ReferenceNames.probe?(probe) }
    assert_equal [], unnamed(plugin_files, named_plugins(manifests).keys, table, shipped, reference)
  end

  test "a reader nobody names passes only when no surveyed game ships its probe and a reference copy defines it" do
    table = { :named => "Named", :shipped => "Shipped", :copied => "Copied#m", :lost => "Lost",
              :spaced => "Ns::Spaced#m" }
    reference = lambda { |probe| ["Shipped", "Copied#m", "Ns::Spaced#m"].include?(probe) }
    got = unnamed(table.keys.map { |k| k.to_s }, ["named"], table, { "Shipped" => true, "Spaced#m" => true }, reference)
    assert_equal ["lost", "shipped", "spaced"], got, "a probe counts as shipped under its census key"
  end

  test "every hook in plugins/ is optional" do
    assert_equal [], non_optional_hooks(plugin_sources)
  end

  test "a hook without :optional is reported by file and line, past comments" do
    src = "# after(\"Scene\", :update) do\n" \
          "after(\"Scene\", :update, :optional) do\nend\n" \
          "PokeAccess::Hooks.after_hook(\"Scene\", :refresh) do\nend\n" \
          "around (\"Other\", :run) { |m| m.call }\n"
    assert_equal ["reader.rb:4", "reader.rb:6"], non_optional_hooks("reader.rb" => src)
  end

  test "checks every hook form on a quoted class, and none on the mod's own module" do
    %w[after before around PokeAccess::Hooks.after_hook PokeAccess::Hooks.before_hook PokeAccess::Hooks.around_hook
       PokeAccess::Hooks.read_on_open PokeAccess::Hooks.override].each do |form|
      assert_equal ["reader.rb:1"], non_optional_hooks("reader.rb" => "#{form}(\"Scene\", :run) { }\n"), form
      assert_equal [], non_optional_hooks("reader.rb" => "#{form}(\"Scene\", :run, :optional) { }\n"), form
    end
    assert_equal [], non_optional_hooks("reader.rb" => "PokeAccess::Hooks.override(PokeAccess::Info, :speak) { }\n")
  end

  test "every plugin file registers through a form this check understands" do
    assert_equal [], slot_claims(plugin_sources)[1]
  end

  test "no slot is claimed by two plugins" do
    assert_equal [], shared_slots(slot_claims(plugin_sources)[0])
  end

  test "two readers on one class and method collide, the mod's own methods and a silent file do not" do
    sources = {
      "a.rb" => "PokeAccess::Hooks.after_hook(\"Battle::Scene\", :pbUpdate, :optional) do\nend\n",
      "b.rb" => "# after_hook(\"Other\", :run)\nafter_hook(\"Battle::Scene\", :pbUpdate, :optional) { }\n",
      "c.rb" => "override(PokeAccess::Info, :speak) { }\nafter_hook(\"Mine\", :run, :optional) { }\n",
      "d.rb" => "override(PokeAccess::Info, :speak) { }\n",
      "quiet.rb" => "# after_hook(\"Battle::Scene\", :pbUpdate)\nx = 1\n"
    }
    claims, silent = slot_claims(sources)
    assert_equal ["quiet"], silent, "a file with no registration, its comment aside"
    assert_equal ["Battle::Scene#pbUpdate <- a, b"], shared_slots(claims)
  end

  test "reads each registration form, a game class's claiming its slot and the mod's own claiming none" do
    {
      "PokeAccess::SceneWatcher.reader(\"PokemonMart_Scene\", :pbStartBuyScene, :optional => true) { }" =>
        ["PokemonMart_Scene#pbStartBuyScene"],
      "PokeAccess::Menus.def_extractor(\"Window_Pokedex\") { }" => ["Window_Pokedex#"],
      "PokeAccess::Menus.bag_decorators.push(BerryTags)" => ["BerryTags#"],
      "PokeAccess::Hooks.read_on_open(\"Scene_Map\", :main, :optional) { }" => ["Scene_Map#main"],
      "PokeAccess::Hooks.override(\"RC\", :show, :optional => true) { }" => ["RC#show"],
      "[:a, :b].each { |m| PokeAccess::Hooks.after_hook(\"Scene\", m, :optional) { } }" => ["Scene#m"],
      "PokeAccess::Hooks.override(PokeAccess::Info, :speak) { }" => [],
      "PokeAccess::Routes::Moves.touch_source(:ice) { }" => [],
      "PokeAccess::Routes::Effects.leave_rule { }" => [],
      "PokeAccess::Locator.register_rule(:name) { }" => [],
      "PokeAccess::Hooks.wrap_kernel(\"pbMessage\", \"tag\") { }" => []
    }.each do |line, want|
      claims, silent = slot_claims("x.rb" => line)
      assert_equal [want, []], [claims.keys, silent], "for #{line}"
    end
  end

  test "no two table entries share a detection probe" do
    assert_equal [], shared_probes(table)
  end

  test "two table entries with the same probe are reported by it" do
    assert_equal ["Scene#run"], shared_probes(:a => "Scene#run", :b => "Other", :c => "Scene#run")
  end

  test "every detection probe is in the plugin census" do
    census = census_profiles
    assert_operator census.length, :>, 5, "the census was read"
    assert_equal [], table.values.map { |v| probe_key(v) }.uniq.reject { |c| census.key?(c) }.sort,
                 "regenerate it after adding a plugin"
  end

  test "a probe's census key is its class's last segment, with the method of a Class#method probe" do
    {
      "BetterRegionMap" => "BetterRegionMap",
      "GameData::TerrainTag#slide_up" => "TerrainTag#slide_up",
      "Battle::Scene#pbGetFinalModifiers" => "Scene#pbGetFinalModifiers",
      "UI::PokedexVisuals" => "PokedexVisuals"
    }.each { |probe, want| assert_equal want, probe_key(probe), "for #{probe}" }
  end

  test "no profile misses a declaration for a plugin its game ships" do
    assert_equal [], declaration_gaps(table, census_profiles, declared_lists)[0]
  end

  test "a game that reads its own copy of a plugin does not load the plugin's reader too" do
    loaded = OWN_COPIES.map { |prof, names| (names & (Imports.plugins(prof) || [])).map { |n| "#{prof}: #{n}" } }
    assert_equal [], loaded.flatten
  end

  test "no profile declares a plugin its game does not ship" do
    assert_equal [], declaration_gaps(table, census_profiles, declared_lists)[1]
  end

  test "a shipped plugin left undeclared and a declared one not shipped are both reported" do
    table = { :dbk => "Battle#pbToggle", :album => "AlbumFotos_Scene" }
    census = { "Battle#pbToggle" => ["anil", "royal"], "AlbumFotos_Scene" => [] }
    gaps = declaration_gaps(table, census, "anil" => ["dbk"], "royal" => [], "uranium" => ["album"])
    assert_equal [["royal ships dbk and does not declare it"], ["uranium declares album and does not ship it"]], gaps
  end

  test "reports a plugin the game has whose reader was not loaded" do
    with_const(:PaSpecPluginScene, Class.new) do
      with_plugins(:spec_present => "PaSpecPluginScene", :spec_absent => "PaSpecNoSuchScene") do |pl|
        assert_equal ["spec_present"], pl.undeclared
      end
    end
  end

  test "stops reporting a plugin once its reader is loaded" do
    with_const(:PaSpecPluginScene, Class.new) do
      with_plugins(:spec_present => "PaSpecPluginScene") do |pl|
        pl.note_loaded("spec_present")
        assert_equal [], pl.undeclared
      end
    end
  end

  test "notes a loaded reader once, by its name as a string" do
    with_plugins({}) do |pl|
      pl.note_loaded(:spec_present)
      pl.note_loaded("spec_present")
      assert_equal ["spec_present"], pl.loaded
    end
  end

  test "lists the unloaded plugins in name order" do
    with_const(:PaSpecPluginScene, Class.new) do
      with_plugins(:zeta => "PaSpecPluginScene", :alpha => "PaSpecPluginScene") do |pl|
        assert_equal ["alpha", "zeta"], pl.undeclared
      end
    end
  end

  test "finds a plugin that reopens an engine class by the method it adds, not by the class alone" do
    with_const(:PaSpecHostScene, Class.new { def pa_spec_added_by_plugin; end }) do
      {
        "PaSpecHostScene#pa_spec_added_by_plugin" => ["spec"],
        "PaSpecHostScene#pa_spec_never_defined" => [],
        "PaSpecHostScene" => ["spec"],
        "PaSpecNoSuchScene#pa_spec_added_by_plugin" => []
      }.each do |probe, want|
        with_plugins(:spec => probe) { |pl| assert_equal want, pl.undeclared, "for #{probe}" }
      end
    end
  end

  test "a probe that cannot be read is not reported" do
    unreadable = Object.new
    def unreadable.to_s; raise ArgumentError, "unreadable probe"; end
    with_plugins(:spec_odd => unreadable) { |pl| assert_equal [], pl.undeclared }
  end

  test "a table that is not a hash leaves an empty one, which reports nothing" do
    with_plugins("no table") do |pl|
      assert_equal({}, pl.table)
      assert_equal [], pl.undeclared
    end
  end

  test "reads the game's plugin register, sorted, with each version where there is one" do
    manager = Module.new do
      def self.plugins; ["Sin Version", "Deluxe Battle Kit"]; end
      def self.version(n); n == "Deluxe Battle Kit" ? "1.3.0.4" : nil; end
    end
    with_const(:PluginManager, manager) do
      assert_equal ["Deluxe Battle Kit 1.3.0.4", "Sin Version"], PokeAccess::Plugins.game_plugins
    end
  end

  test "names a registered plugin alone when its version is empty or cannot be read" do
    manager = Module.new do
      def self.plugins; ["Blank", "Broken", "None"]; end
      def self.version(n)
        raise "no version" if n == "Broken"
        n == "Blank" ? "" : nil
      end
    end
    with_const(:PluginManager, manager) do
      assert_equal ["Blank", "Broken", "None"], PokeAccess::Plugins.game_plugins
    end
  end

  test "a game with no plugin manager answers nil, and an empty register an empty list" do
    without_const(:PluginManager) { assert_nil PokeAccess::Plugins.game_plugins, "absent" }
    with_const(:PluginManager, Module.new { def self.plugins; []; end }) do
      assert_equal [], PokeAccess::Plugins.game_plugins, "empty"
    end
  end

  test "a register that is missing, raises, is no list or holds an entry with no name answers nil" do
    {
      "no plugins method" => Module.new,
      "plugins raises" => Module.new { def self.plugins; raise "broken"; end },
      "plugins is no list" => Module.new { def self.plugins; "Deluxe Battle Kit"; end },
      "an entry with no name" => Module.new { def self.plugins; [BasicObject.new]; end }
    }.each do |what, manager|
      with_const(:PluginManager, manager) { assert_nil PokeAccess::Plugins.game_plugins, what }
    end
  end

  private

  # The plugin readers' names, the files in plugins/ but the manifest.
  def plugin_files
    Dir.glob(File.join(PDIR, "*.rb")).map { |p| File.basename(p, ".rb") }.reject { |n| n == "manifest" }.sort
  end

  # { file name => text } of every plugin reader.
  def plugin_sources
    plugin_files.each_with_object({}) { |n, out| out["#{n}.rb"] = File.read(File.join(PDIR, "#{n}.rb")) }
  end

  # The plugins manifest: name => the probe that gives the plugin away.
  def table
    eval(Harness.source(File.join(PDIR, "manifest.rb")))
  end

  # { profile or common => its evaluated manifest } for every games/*/manifest.rb.
  def manifests
    Dir.glob(File.join(ROOT, "games", "*", "manifest.rb")).sort.each_with_object({}) do |mf, out|
      out[File.basename(File.dirname(mf))] = eval(Harness.source(mf))
    end
  end

  # { probe census key => true when some surveyed game ships it }.
  def shipped
    census_profiles.each_with_object({}) { |(key, profs), out| out[key] = !profs.empty? }
  end

  # { probe census key => [profiles that ship it] }.
  def census_profiles
    out = {}
    PokeAccess::KVFile.each(CENSUS) do |key, profs|
      out[key] = profs.to_s.split(",").map { |p| p.strip }.reject { |p| p.empty? }
    end
    out
  end

  # { playable profile => the plugins it loads, its commons' joined, and the ones it reads in its own copy } for the
  # profiles with an explicit list.
  def declared_lists
    Imports.folders.reject { |f| Imports.common?(f) }.each_with_object({}) do |prof, out|
      list = Imports.plugins(prof)
      out[prof] = list + (OWN_COPIES[prof] || []) if list.is_a?(Array)
    end
  end

  # The key a probe has in the census: a plain class by its short name, a Class#method probe with both halves (its
  # class alone is in every game).
  def probe_key(probe)
    s = probe.to_s
    s.include?("#") ? "#{s.split('#').first.split('::').last}##{s.split('#').last}" : s.split("::").last
  end

  # The mismatches of the plugin files and the manifest table: a file out of it, an entry with no file, an entry
  # with no probe.
  def table_gaps(files, table)
    files.reject { |n| table.has_key?(n.to_sym) }.sort.map { |n| "#{n}.rb is not in the table" } +
      table.keys.map { |k| k.to_s }.reject { |n| files.include?(n) }.sort.map { |n| "#{n} has no file" } +
      table.select { |_k, v| v.nil? || v.to_s.strip.empty? }.keys.map { |k| "#{k} names no probe" }.sort
  end

  # { plugin name => [profiles] } from the manifests that list their plugins; :auto names none.
  def named_plugins(manifests)
    out = {}
    manifests.each do |prof, value|
      names = value.is_a?(Hash) ? value[:plugins] : nil
      names.each { |n| (out[n.to_s] ||= []).push(prof) } if names.is_a?(Array)
    end
    out
  end

  # The plugin files no profile names, but those whose probe no surveyed game ships and a reference copy defines.
  def unnamed(files, named, table, shipped, reference)
    (files - named).reject do |n|
      probe = table[n.to_sym]
      !shipped[probe_key(probe)] && reference.call(probe)
    end.sort
  end

  # "file:line" of each hook registration that is not :optional, comment lines skipped.
  def non_optional_hooks(sources)
    out = []
    sources.keys.sort.each do |name|
      sources[name].each_line.with_index(1) do |line, i|
        next if line.strip.start_with?("#")
        out.push("#{name}:#{i}") if line =~ HOOK_RE && !line.include?("optional")
      end
    end
    out
  end

  # [{ "Class#method" => [plugin, ...] }, the plugins that register through no form], comment lines dropped.
  def slot_claims(sources)
    claims = {}
    silent = []
    sources.keys.sort.each do |file|
      name = File.basename(file, ".rb")
      body = sources[file].gsub(/^\s*#.*$/, "")
      found = 0
      FORMS.each do |re|
        body.scan(re) do |klass, meth|
          found += 1
          (claims["#{klass}##{meth}"] ||= []) << name unless klass.start_with?("PokeAccess::")
        end
      end
      silent.push(name) if found == 0
    end
    [claims, silent]
  end

  # The slots two different plugins claim, as "slot <- plugins".
  def shared_slots(claims)
    shared = claims.select { |_slot, files| files.uniq.length > 1 }
    shared.map { |slot, files| "#{slot} <- #{files.uniq.sort.join(', ')}" }.sort
  end

  # The probes two table entries share.
  def shared_probes(table)
    table.values.map { |v| v.to_s }.group_by { |v| v }.select { |_k, v| v.length > 1 }.keys.sort
  end

  # [missing, spurious]: the profiles that ship a plugin and do not declare it, and those that declare one their game
  # does not ship, per the census.
  def declaration_gaps(table, census, declared)
    missing = []
    spurious = []
    table.each do |name, probe|
      ships = census[probe_key(probe)] || []
      declared.each do |prof, list|
        has = ships.include?(prof)
        said = list.include?(name.to_s)
        missing.push("#{prof} ships #{name} and does not declare it") if has && !said
        spurious.push("#{prof} declares #{name} and does not ship it") if !has && said
      end
    end
    [missing.sort, spurious.sort]
  end

  # Runs the block with the plugin table set to table and no reader noted, both put back after.
  def with_plugins(table)
    pl = PokeAccess::Plugins
    loaded = pl.loaded.dup
    saved = pl.table
    pl.table = table
    pl.loaded.clear
    yield pl
  ensure
    pl.loaded.replace(loaded)
    pl.table = saved
  end

  # Runs the block with the top-level constant name set to value, the one it had (or none) put back after.
  def with_const(name, value)
    had = Object.const_defined?(name, false)
    was = Object.const_get(name) if had
    Object.send(:remove_const, name) if had
    Object.const_set(name, value)
    yield
  ensure
    Object.send(:remove_const, name) if Object.const_defined?(name, false)
    Object.const_set(name, was) if had
  end

  # Runs the block with the top-level constant name undefined, the one it had put back after.
  def without_const(name)
    had = Object.const_defined?(name, false)
    was = Object.send(:remove_const, name) if had
    yield
  ensure
    Object.const_set(name, was) if had && !Object.const_defined?(name, false)
  end
end
