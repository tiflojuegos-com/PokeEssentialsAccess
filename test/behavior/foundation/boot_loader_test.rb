# The mod's loader (loader/boot.rb, evaluated from its source): the module list a manifest gives, the plugin readers
# and commons a profile declares, and a whole boot of a game folder in that order, logging what it skips.
class BootLoaderTest < PokeAccessTest
  BOOT_RB = File.join(Harness::ROOT, "loader", "boot.rb")
  eval(Harness.source(BOOT_RB), TOPLEVEL_BINDING, BOOT_RB)
  Boot = ::PokeAccessBoot
  NOT_A_LIST = "no devolvio una lista de modulos ni un hash con :modules"
  HARNESS_RB = File.join(Harness::ROOT, "test", "support", "harness.rb")
  # A preload where nothing of the mod has loaded yet: the engine stubs, the harness's mutant, then the loader.
  BARE_BOOT = "require ARGV[0]\neval(Harness.source(ARGV[1]), TOPLEVEL_BINDING, ARGV[1])\n"

  class << self
    # What the modules a boot under test evaluated recorded, in the order they ran.
    def trace; @trace ||= []; end
  end

  test "takes the module list from either manifest shape" do
    { %w[a b c] => %w[a b c], { :modules => %w[x y], :plugins => ["p"] } => %w[x y] }.each do |value, want|
      assert_equal want, Boot.modules_of(value, "mf"), "for #{value.inspect}"
    end
  end

  test "gives no module list for a manifest of neither shape, and logs why" do
    { { :plugins => ["p"] } => "mf: la clave :modules no es una lista",
      { :modules => "x" } => "mf: la clave :modules no es una lista",
      "nope" => "mf: #{NOT_A_LIST}",
      nil => "mf: #{NOT_A_LIST}" }.each do |value, line|
      got = :unset
      assert_equal "#{line}\n\n", logged { got = Boot.modules_of(value, "mf") }, "logged for #{value.inspect}"
      assert_nil got, "for #{value.inspect}"
    end
  end

  test "reads a manifest that fails as nil, logging its error" do
    in_tree("manifest.rb" => "{ :modules => [") do |root|
      mf = File.join(root, "manifest.rb")
      got = :unset
      log = logged { got = Boot.read_manifest(mf) }
      assert_nil got
      assert_match(/\A#{Regexp.escape(mf)}: SyntaxError: /, log)
    end
  end

  test "lets the game's exit through while it reads a manifest or loads a module" do
    in_tree("manifest.rb" => "exit", "module.rb" => "exit") do |root|
      assert_raises(SystemExit) { Boot.read_manifest(File.join(root, "manifest.rb")) }
      assert_raises(SystemExit) { Boot.load_module(File.join(root, "module.rb")) }
    end
  end

  test "declares the plugin readers a profile lists, or :auto, and never infers them" do
    { '{ :modules => ["m"], :plugins => ["one", "two"] }' => %w[one two],
      '{ :modules => ["m"], :plugins => :auto }' => :auto,
      '{ :modules => ["m"] }' => [],
      '{ :modules => ["m"], :plugins => "one" }' => [],
      '["m"]' => [],
      "{ :modules => [" => [] }.each do |manifest, want|
      in_tree("profile/manifest.rb" => manifest) do |root|
        assert_equal want, Boot.declared_plugins(File.join(root, "profile")), "for #{manifest}"
      end
    end
  end

  test "declares nothing for a folder without a manifest, and logs nothing" do
    in_tree({}) do |root|
      got = nil
      assert_equal "", logged { got = Boot.declared_plugins(File.join(root, "profile")) }
      assert_equal [], got
    end
  end

  test "joins the plugin readers of the commons a profile imports after its own, in import order and once each" do
    commons = { "a_common" => '["a_p", "shared"]', "b_common" => '["b_p"]', "c_common" => ":auto" }
    { '["own", "shared"]' => %w[own shared b_p a_p], ":auto" => :auto, nil => %w[b_p a_p shared] }.each do |own, want|
      plugins = own ? ", :plugins => #{own}" : ""
      files = common_files(commons)
      files["profile/manifest.rb"] = "{ :imports => %w[b_common c_common a_common], :modules => []#{plugins} }"
      in_tree(files) do |root|
        dirs = Boot.imported_dirs(File.join(root, "profile"), File.join(root, "common"))
        assert_equal want, Boot.declared_plugins(File.join(root, "profile"), dirs), "for the profile's #{own.inspect}"
      end
    end
  end

  test "imports the commons a profile names, in its order and once each, by string or symbol" do
    files = common_files("a_common" => "[]", "b_common" => "[]")
    files["profile/manifest.rb"] = '{ :imports => [:b_common, "a_common", "b_common"], :modules => [] }'
    in_tree(files) do |root|
      base = File.join(root, "common")
      assert_equal ["#{base}/b_common", "#{base}/a_common"], Boot.imported_dirs(File.join(root, "profile"), base)
    end
  end

  test "imports no common from a manifest without a list of them" do
    ['{ :modules => [] }', '{ :imports => "a_common", :modules => [] }', '["m"]'].each do |manifest|
      in_tree(common_files("a_common" => "[]").merge("profile/manifest.rb" => manifest)) do |root|
        assert_equal [], Boot.imported_dirs(File.join(root, "profile"), File.join(root, "common")), "for #{manifest}"
      end
    end
  end

  test "skips an import with no folder, logging it, and keeps the rest" do
    files = common_files("a_common" => "[]")
    files["profile/manifest.rb"] = '{ :imports => %w[x_common a_common], :modules => [] }'
    in_tree(files) do |root|
      base = File.join(root, "common")
      dirs = nil
      log = logged { dirs = Boot.imported_dirs(File.join(root, "profile"), base) }
      assert_equal ["#{base}/a_common"], dirs
      assert_equal "import declarado pero ausente: #{base}/x_common\n\n", log
    end
  end

  test "boots core, the plugin readers, the commons and the profile, each in its manifest's order" do
    files = {
      "core/manifest.rb" => '["zz", "aa"]', "core/zz.rb" => traced("core/zz"), "core/aa.rb" => traced("core/aa"),
      "plugins/own_p.rb" => traced("plugins/own_p"), "plugins/common_p.rb" => traced("plugins/common_p"),
      "common/c2/manifest.rb" => '{ :modules => ["c"], :plugins => ["common_p"] }', "common/c2/c.rb" => traced("c2"),
      "common/c1/manifest.rb" => '{ :modules => ["c"] }', "common/c1/c.rb" => traced("c1"),
      "game/manifest.rb" => '{ :imports => ["c2", "c1"], :modules => ["g"], :plugins => ["own_p"] }',
      "game/g.rb" => traced("game/g")
    }
    assert_equal %w[core/zz core/aa plugins/own_p plugins/common_p c2 c1 game/g], boot(files)
  end

  test "records the plugin readers it loads, and the game's plugins left without one" do
    files = { "plugins/manifest.rb" => '{ "alfa" => "String", "beta" => "Object", "gamma" => "NoSuchPlugin" }',
              "plugins/alfa.rb" => "", "game/manifest.rb" => '{ :modules => [], :plugins => ["alfa"] }' }
    assert_equal [["alfa"], ["beta"]], boot(files) { [PokeAccess::Plugins.loaded, PokeAccess::Plugins.undeclared] }
  end

  test "loads the plugins its detection table finds for a profile that says :auto, in name order" do
    files = { "plugins/manifest.rb" => '{ "zeta" => "String", "alfa" => "String#upcase", "nope" => "String#nope" }',
              "plugins/zeta.rb" => traced("zeta"), "plugins/alfa.rb" => traced("alfa"),
              "plugins/nope.rb" => traced("nope"), "game/manifest.rb" => '{ :modules => [], :plugins => :auto }' }
    trace = nil
    log = logged { trace = boot(files) }
    assert_equal %w[alfa zeta], trace
    assert_includes log, "plugins detectados: alfa, zeta\n\n"
  end

  test "loads no plugin for a profile that says :auto when the probe of its detection table fails" do
    files = { "plugins/manifest.rb" => '{ "alfa" => "String" }', "plugins/alfa.rb" => traced("alfa"),
              "game/manifest.rb" => '{ :modules => [], :plugins => :auto }' }
    trace = nil
    log = stubbing(PokeAccess::Engine, :has? => lambda { |_probe| raise ArgumentError, "probe" }) do
      logged { trace = boot(files) }
    end
    assert_equal [], trace
    refute_match(/plugins detectados/, log)
  end

  test "loads no plugin for a profile that says :auto when the detection table is missing or finds none" do
    [nil, '{ "alfa" => "String#nope" }'].each do |table|
      files = { "plugins/alfa.rb" => traced("alfa"), "game/manifest.rb" => '{ :modules => [], :plugins => :auto }' }
      files["plugins/manifest.rb"] = table if table
      trace = nil
      log = logged { trace = boot(files) }
      assert_equal [], trace, "with the table #{table.inspect}"
      refute_match(/plugins detectados/, log, "with the table #{table.inspect}")
    end
  end

  test "skips a declared plugin reader that is missing, logging it, and loads the rest" do
    files = { "plugins/b.rb" => traced("b"), "game/manifest.rb" => '{ :modules => [], :plugins => ["a", "b"] }' }
    trace = nil
    log = logged { trace = boot(files) }
    assert_equal ["b"], trace
    assert_includes log, "plugin declarado pero ausente: accessibility/plugins/a.rb\n\n"
  end

  test "logs a module that fails, with where it failed, and loads the ones after it" do
    files = { "core/manifest.rb" => '["one", "broken", "two"]', "core/one.rb" => traced("one"),
              "core/broken.rb" => 'raise "boom"', "core/two.rb" => traced("two") }
    trace = nil
    log = logged { trace = boot(files) }
    assert_equal %w[one two], trace
    assert_match(%r{^accessibility/core/broken\.rb: RuntimeError: boom\naccessibility/core/broken\.rb:1:in }, log)
  end

  test "loads nothing from a folder whose manifest is missing or of neither shape, and logs it" do
    { {} => "accessibility/core: sin manifest.rb",
      { "core/manifest.rb" => '"one"' } => "accessibility/core/manifest.rb: #{NOT_A_LIST}" }.each do |manifest, line|
      trace = nil
      log = logged { trace = boot(manifest.merge("core/one.rb" => traced("one"))) }
      assert_equal [], trace, "for #{manifest.inspect}"
      assert_includes log, "#{line}\n\n", "for #{manifest.inspect}"
    end
  end

  test "applies the player's settings over what the profile set" do
    files = { "game/manifest.rb" => '["g"]', "data/settings.ini" => "auto_guide=false\n",
              "game/g.rb" => "PokeAccess::Config.auto_guide = true\nPokeAccess::Config.guide_distance = 5\n" }
    assert_equal [false, 5], boot(files) { [PokeAccess::Config.auto_guide, PokeAccess::Config.guide_distance] }
  end

  test "logs the hooks that found no method and the groups that bound to no class" do
    { [["Foo#bar"], ["Baz"]] => "Foo#bar, Baz", [["Foo#bar"], []] => "Foo#bar", [[], ["Baz"]] => "Baz",
      [[], []] => nil }.each do |(missing, unbound), names|
      log = stubbing(PokeAccess::Hooks, :missing => missing, :unbound => unbound) { logged { boot({}) } }
      want = names ? ["[diag] enganches sin metodo (posible typo): #{names}"] : []
      assert_equal want, log.split("\n").grep(/enganches/), "for #{missing + unbound}"
    end
  end

  test "logs that no engine provider serves the game's data" do
    { 0 => true, nil => true, 1 => false, 20 => false }.each do |priority, logs|
      log = stubbing(PokeAccess::Data, :active_priority => priority) { logged { boot({}) } }
      assert_equal logs, log.include?("[diag] PokeAccess::Data en modo emergencia"), "for priority #{priority.inspect}"
    end
  end

  test "logs into the game folder's accessibility/data while the mod's data folder is unknown" do
    in_tree("accessibility/data/.keep" => "") do |root|
      without_data_path { Dir.chdir(root) { Boot.log("sonda") } }
      path = File.join(root, "accessibility", "data", "loader_error.txt")
      assert_equal "sonda\n\n", (File.binread(path).gsub("\r\n", "\n") if File.file?(path))
    end
  end

  test "finishes a boot whose core never loaded, logging each folder without a manifest into the game folder" do
    finished, log, out = bare_boot({})
    assert_equal [true, "accessibility/core: sin manifest.rb\n\naccessibility/game: sin manifest.rb\n\n"],
                 [finished, log], out
  end

  test "finishes a boot whose core never loaded when the game ships its plugin detection table" do
    files = { "plugins/manifest.rb" => '{ "alfa" => "String" }', "plugins/alfa.rb" => "",
              "game/manifest.rb" => '{ :modules => [], :plugins => :auto }' }
    finished, log, out = bare_boot(files)
    assert_equal [true, "accessibility/core: sin manifest.rb\n\n"], [finished, log], out
  end

  test "leaves the languages' parity to the suite: the boot neither checks it nor logs it" do
    asked = []
    log = stubbing(PokeAccess::I18n, :parity_issues => lambda { asked.push(:parity); ["en:k: missing"] }) do
      logged { boot({}) }
    end
    assert_equal [[], []], [asked, log.split("\n").grep(/i18n/)]
  end

  private

  # Boots a game folder made of files (paths under accessibility/) as the game's preload does, its settings.ini and
  # the plugin records its own; returns the block's value, or what the evaluated modules recorded.
  def boot(files)
    self.class.trace.clear
    tree = {}
    files.each { |path, body| tree["accessibility/#{path}"] = body }
    in_tree(tree) do |root|
      FileUtils.mkdir_p(File.join(root, "accessibility", "data"))
      with_plugin_records do
        with_settings_file(File.join(root, "accessibility", "data", "settings.ini")) do
          Dir.chdir(root) { Boot.run }
          block_given? ? yield : self.class.trace.dup
        end
      end
    end
  end

  # Boots a game folder made of files (paths under accessibility/) in a Ruby of its own that holds the engine stubs
  # and nothing of the mod; returns whether it finished, what it logged into the game folder, and what it printed.
  def bare_boot(files)
    tree = { "accessibility/data/.keep" => "" }
    files.each { |path, body| tree["accessibility/#{path}"] = body }
    in_tree(tree) do |root|
      argv = [RbConfig.ruby, "-e", BARE_BOOT, HARNESS_RB, BOOT_RB]
      out = IO.popen(argv, :chdir => root, :err => [:child, :out]) { |io| io.read }
      path = File.join(root, "accessibility", "data", "loader_error.txt")
      [$?.success?, (File.binread(path).gsub("\r\n", "\n") if File.file?(path)), out]
    end
  end

  # A module body that records name when the loader evaluates it.
  def traced(name)
    "BootLoaderTest.trace.push(#{name.inspect})\n"
  end

  # The files of commons named with their :plugins literal, each manifest under common/<name>.
  def common_files(commons)
    out = {}
    commons.each { |name, plugins| out["common/#{name}/manifest.rb"] = "{ :modules => [], :plugins => #{plugins} }" }
    out
  end

  # Runs the block with a scratch folder holding files (relative path => contents), yielding its path.
  def in_tree(files)
    Dir.mktmpdir do |root|
      files.each do |rel, body|
        path = File.join(root, rel)
        FileUtils.mkdir_p(File.dirname(path))
        File.open(path, "w") { |f| f.write(body) }
      end
      yield root
    end
  end

  # What the loader appended to loader_error.txt while the block ran, with Windows' line ends as "\n".
  def logged
    path = File.join(PokeAccess::Paths::DATA, "loader_error.txt")
    size = File.file?(path) ? File.size(path) : 0
    yield
    File.file?(path) ? File.binread(path)[size..-1].to_s.force_encoding("UTF-8").gsub("\r\n", "\n") : ""
  end

  # Runs the block with no plugin reader recorded as loaded and no detection table, both put back afterwards.
  def with_plugin_records
    plugins = PokeAccess::Plugins
    loaded = plugins.loaded
    table = plugins.table
    plugins.instance_variable_set(:@loaded, [])
    plugins.instance_variable_set(:@table, {})
    yield
  ensure
    plugins.instance_variable_set(:@loaded, loaded)
    plugins.instance_variable_set(:@table, table)
  end

  # Runs the block with the mod's data folder unknown, as before core's paths load; put back afterwards.
  def without_data_path
    was = PokeAccess::Paths::DATA
    PokeAccess::Paths.send(:remove_const, :DATA)
    yield
  ensure
    PokeAccess::Paths.const_set(:DATA, was) unless PokeAccess::Paths.const_defined?(:DATA, false)
  end

  # Runs the block with Settings reading and writing file, put back afterwards.
  def with_settings_file(file)
    was = PokeAccess::Settings::FILE
    PokeAccess::Settings.send(:remove_const, :FILE)
    PokeAccess::Settings.const_set(:FILE, file)
    yield
  ensure
    PokeAccess::Settings.send(:remove_const, :FILE)
    PokeAccess::Settings.const_set(:FILE, was)
  end

  # Runs the block with each named singleton method of mod answering its value (a Proc is called with the arguments
  # instead), the methods put back afterwards.
  def stubbing(mod, answers)
    saved = {}
    answers.each do |meth, value|
      saved[meth] = mod.method(meth)
      mod.define_singleton_method(meth) { |*args| value.is_a?(Proc) ? value.call(*args) : value }
    end
    yield
  ensure
    saved.each { |meth, m| mod.define_singleton_method(meth, m) }
  end
end
