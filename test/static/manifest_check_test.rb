# Every manifest against the disk and the catalog against the profiles (manifest_check.rb, a pure filesystem check
# run as a process of its own): the real tree passes, and a scratch tree with planted gaps has each one named.
require "json"
require "fileutils"
require "rbconfig"
require "tmpdir"

class ManifestCheckTest < PokeAccessTest
  SCRIPT = File.expand_path("manifest_check.rb", File.dirname(__FILE__))

  # A catalog manifest_check.rb accepts: a profile with a compat script, one that converts, the generic one.
  SOUND = [
    { "key" => "alpha", "display" => "Pokemon Alpha", "titles" => ["pokemon alpha"], "detect" => "alpha",
      "exes" => ["Alpha.exe"], "engine" => "gen6", "compat" => "alpha_compat.rb" },
    { "key" => "beta", "display" => "Pokemon Beta", "titles" => ["pokemon beta"], "detect" => "beta", "exes" => [],
      "engine" => "gamedata", "convert" => "mkxp-z-1.3", "markers" => ["Game.rgssad"] },
    { "key" => "generic", "display" => "Perfil generico", "titles" => [], "detect" => nil, "exes" => [],
      "engine" => "any" }
  ]

  DEAD_DETECT_TAIL = 'matches nothing, not even its own display (a JSON escape like \b eaten down to a control char ' \
                     'looks exactly like this)'

  test "the real manifests list exactly the files on disk, and the catalog matches the profiles" do
    ok, problems, out = run_check(SCRIPT)
    assert_equal [], problems
    assert ok, out
  end

  test "a tree whose manifests and catalog agree passes, a common without a catalog entry included" do
    ok, problems, out = check(tree)
    assert_equal [true, []], [ok, problems]
    assert_match(/\Amanifest_check: OK \(core 1 entries \+ 4 profile manifests/, out)
  end

  test "names each manifest's gap by its folder" do
    ok, problems, _out = check(tree("core/manifest.rb" => "%w[\n  foundation/a\n  foundation/gone\n  foundation/a\n]\n",
                                    "core/foundation/extra.rb" => "",
                                    "games/alpha/manifest.rb" => "{ :plugins => [] }\n",
                                    "games/beta/manifest.rb" => "{ :modules => %w[\n  menus\n] }\n",
                                    "games/beta/menus.rb" => "",
                                    "games/beta/sub/reader.rb" => ""))
    refute ok, "the check fails"
    assert_equal ["core: listed but no file: foundation/gone",
                  "core: on disk but not listed: foundation/extra",
                  "core: listed more than once: foundation/a",
                  "games/alpha: manifest.rb has no %w[...] module list",
                  "games/beta: on disk but not listed: sub/reader"], problems
  end

  test "matches the catalog to the profile folders, commons aside" do
    ghost = { "key" => "ghost", "titles" => ["pokemon ghost"], "engine" => "gen6" }
    files = { "games/delta/manifest.rb" => "{ :modules => %w[] }\n", "games/ghost/manifest.rb" => nil }
    _ok, problems, _out = check(tree(files, SOUND + [ghost]))
    assert_equal ["games/ folder without a catalog entry: delta", "catalog entry without a games/ folder: ghost"],
                 problems
  end

  test "requires each profile's engine to be gen6, gamedata or any" do
    profiles = [SOUND[0].merge("engine" => "gen7"), SOUND[1], SOUND[2], { "key" => "xi", "titles" => ["pokemon xi"] }]
    _ok, problems, _out = check(tree({}, profiles))
    assert_equal ["profile alpha engine invalid or missing (\"gen7\")", "profile xi engine invalid or missing (nil)"],
                 problems
  end

  test "requires a compat to be a bare lowercase .rb name, even when the file it names exists" do
    compats = { "psi" => "../shared_common/reader.rb", "chi" => "Chi_Compat.rb", "phi" => "phi_compat.rb.bak" }
    profiles = SOUND + compats.map do |key, compat|
      { "key" => key, "titles" => ["pokemon #{key}"], "engine" => "gen6", "compat" => compat }
    end
    files = { "games/chi/Chi_Compat.rb" => "", "games/phi/phi_compat.rb.bak" => "" }
    _ok, problems, _out = check(tree(files, profiles))
    want = compats.map { |key, compat| "profile #{key} compat is not a .rb file of its folder (#{compat.inspect})" }
    assert_equal want, problems
  end

  test "requires a compat's file in its profile's own folder, not elsewhere under games/" do
    _ok, problems, _out = check(tree("games/alpha/alpha_compat.rb" => nil, "games/alpha_compat.rb" => ""))
    assert_equal ["profile alpha compat is not a .rb file of its folder (\"alpha_compat.rb\")"], problems
  end

  test "requires a conversion to name an engine folder and the bare file names that mark the game" do
    converts = { "mu" => ["MKXP", ["Game.ini"]], "nu" => ["mkxp-z", ["data/Game.ini"]], "xi" => ["mkxp-z", []],
                 "pi" => ["mkxp-z", "Game.ini"], "rho" => ["mkxp-z", ["Game.ini", "..Game.ini"]],
                 "sigma" => ["mkxp-z", ["sub\\Game.ini"]], "tau" => ["mkxp-z", ["  "]], "upsilon" => ["mkxp-z", [7]] }
    profiles = SOUND + converts.map do |key, (engine, markers)|
      { "key" => key, "titles" => ["pokemon #{key}"], "engine" => "gen6", "convert" => engine, "markers" => markers }
    end
    _ok, problems, _out = check(tree({}, profiles))
    want = converts.keys.map { |k| "profile #{k} convert does not name an engine and the files that mark the game" }
    assert_equal want, problems
  end

  test "requires some profile to offer a conversion" do
    _ok, problems, _out = check(tree({}, [SOUND[0], SOUND[1].reject { |k, _v| k == "convert" }, SOUND[2]]))
    assert_equal ["no catalog profile offers a conversion"], problems
  end

  test "requires an identity layer of every profile but generic" do
    _ok, problems, _out = check(tree({}, SOUND + [{ "key" => "epsilon", "engine" => "gen6" }]))
    assert_equal ["profile epsilon has no identity layer (titles/detect/exes all empty)"], problems
  end

  test "reports a detect that does not parse, which then matches nothing" do
    zeta = { "key" => "zeta", "display" => "Pokemon Zeta", "detect" => "(", "engine" => "gen6" }
    _ok, problems, _out = check(tree({}, SOUND + [zeta]))
    assert_equal ["invalid detect regex (zeta): #{regexp_error('(')}", "dead detect: '(' (zeta) #{DEAD_DETECT_TAIL}"],
                 problems
  end

  test "counts an empty detect as no identity layer" do
    _ok, problems, _out = check(tree({}, SOUND + [{ "key" => "omega", "detect" => "", "engine" => "gen6" }]))
    assert_equal ["profile omega has no identity layer (titles/detect/exes all empty)"], problems
  end

  test "matches a detect against its display lowercased and stripped of its accents" do
    accented = { "key" => "omicron", "display" => "Pokémon Ómicron Ñandú", "detect" => "omicron nandu",
                 "engine" => "gen6" }
    _ok, problems, _out = check(tree({}, SOUND + [accented]))
    assert_equal [], problems
  end

  test "resolves each title, detect and exe to its own profile alone" do
    profiles = SOUND + [{ "key" => "eta", "titles" => ["pokemon alpha"], "engine" => "gen6" },
                        { "key" => "theta", "display" => "Pokemon Alphabet", "detect" => "bet", "engine" => "gen6" },
                        { "key" => "iota", "display" => "Pokemon Iota", "detect" => "omega", "engine" => "gen6" },
                        { "key" => "kappa", "exes" => ["Game.exe"], "engine" => "gen6" },
                        { "key" => "lambda", "exes" => ["alpha.EXE"], "engine" => "gen6" }]
    _ok, problems, _out = check(tree({}, profiles))
    assert_equal ["title collision: 'pokemon alpha' (eta) resolves to 'alpha' under longest-match",
                  "detect collision: display 'Pokemon Alphabet' resolves to 'alpha', not its own 'theta'",
                  "dead detect: 'omega' (iota) #{DEAD_DETECT_TAIL}",
                  "generic exe in catalog: 'Game.exe' (kappa) can never identify a game",
                  "exe claimed twice: 'alpha.EXE' by alpha and lambda"], problems
  end

  test "a catalog it cannot read is reported, not raised" do
    ok, problems, _out = check(tree("games/catalog.json" => "{ not json", "games/alpha/alpha_compat.rb" => nil))
    refute ok, "the check fails"
    assert_equal 1, problems.length, problems.inspect
    assert_match(/\Acatalog check failed to run: JSON::ParserError: /, problems[0])
  end

  private

  # The scratch tree manifest_check.rb accepts with SOUND as its catalog: core with one module, a folder per
  # profile (alpha's with its compat script) and a common; files maps relative paths to texts, nil to remove one.
  def tree(files = {}, profiles = SOUND)
    out = { "core/manifest.rb" => "%w[\n  foundation/a\n]\n", "core/foundation/a.rb" => "",
            "games/alpha/alpha_compat.rb" => "",
            "games/shared_common/manifest.rb" => "{ :modules => %w[\n  reader\n] }\n",
            "games/shared_common/reader.rb" => "",
            "games/catalog.json" => JSON.generate("profiles" => profiles) }
    profiles.each { |p| out["games/#{p['key']}/manifest.rb"] = "{ :modules => %w[] }\n" }
    out.merge(files)
  end

  # Runs manifest_check.rb, as Harness.source gives it (tools/mutate.rb plants its change there), from a scratch
  # folder holding the files (relative path => text): see run_check.
  def check(files)
    Dir.mktmpdir("pa-manifest-check") do |dir|
      files.merge("test/static/manifest_check.rb" => Harness.source(SCRIPT)).each do |rel, text|
        next if text.nil?
        path = File.join(dir, rel)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, text)
      end
      run_check(File.join(dir, "test", "static", "manifest_check.rb"))
    end
  end

  # [whether the script passed, the problem lines it listed, its whole output].
  def run_check(script)
    out = IO.popen([RbConfig.ruby, script, :err => [:child, :out]], &:read)
    [$?.success?, out.split("\n").map { |l| l.strip }.select { |l| l.start_with?("- ") }.map { |l| l[2..-1] }, out]
  end

  # The message Ruby gives for a detect pattern that does not compile, as the check builds it.
  def regexp_error(pattern)
    Regexp.new(pattern, Regexp::IGNORECASE)
    nil
  rescue RegexpError => e
    e.message
  end
end
