require "rbconfig"
require "json"
require "tmpdir"

# Every profile, and every common on its own, loads whole as the loader loads it (core, plugins, the commons it imports
# first), in a Ruby process of its own under each engine's stubs: a misspelt DSL method only shows when its block runs.
class ProfileLoadTest < PokeAccessTest
  HARNESS = File.join(Harness::ROOT, "test", "support", "harness")
  ENGINES = %w[gen6 gamedata].freeze

  test "loads every profile and common without an error under either engine" do
    games = Dir.glob(File.join(Harness::ROOT, "games", "*", "manifest.rb")).sort.map { |mf| File.basename(File.dirname(mf)) }
    assert_operator games.length, :>=, 20, "the sweep found the profiles"
    assert_equal [], load_failures(games)
  end

  test "reports a profile whose define block calls a DSL method that does not exist, with the file it is in" do
    rel = "games/uranium/#{first_module('uranium')}.rb"
    failures = with_planted(rel, "PokeAccess::Game.define(\"uranium\") { planted_dsl_call(\"Probe\") }\n") do |env|
      load_failures(["uranium"], env)
    end
    assert_equal ENGINES.length, failures.length, failures.inspect
    ENGINES.each_with_index do |engine, i|
      assert_match(/\Auranium \(#{engine}\): #{Regexp.escape(rel)}: NoMethodError: .*planted_dsl_call/, failures[i])
    end
  end

  test "reports a failure only one engine's stubs raise against that engine alone" do
    rel = "games/uranium/#{first_module('uranium')}.rb"
    failures = with_planted(rel, "raise 'planted gamedata failure' if ENGINE == :gamedata\n") do |env|
      load_failures(["uranium"], env)
    end
    assert_equal ["uranium (gamedata): #{rel}: RuntimeError: planted gamedata failure"], failures
  end

  test "reports a load that ends before it counts its errors, with what it printed" do
    Dir.mktmpdir("pa_profile_load") do |dir|
      File.write(File.join(dir, "planted_exit.rb"), "puts 'planted early exit'\nexit(3)\n")
      failures = load_failures(["uranium"], "RUBYOPT" => "-I#{dir} -rplanted_exit")
      assert_equal ["uranium (gen6): planted early exit", "uranium (gamedata): planted early exit"], failures
    end
  end

  private

  # The load failures of the games under every engine, each in a process of its own with env added to it.
  def load_failures(games, env = {})
    games.product(ENGINES).map { |game, engine| load_failure(game, engine, env) }.compact
  end

  # nil when game loads clean under engine in a process of its own (env added to it), else "game (engine): " and its
  # first three load errors, or what the process printed when it ended before counting them.
  def load_failure(game, engine, env = {})
    script = "require #{HARNESS.inspect}; e = Harness.load_all(#{game.inspect}); " \
             "puts 'LOAD_ERRORS=' + e.length.to_s; e.first(3).each { |x| puts 'LOAD_ERROR ' + x }"
    out = IO.popen([{ "PA_ENGINE" => engine }.merge(env), RbConfig.ruby, "-e", script], :err => [:child, :out]) do |io|
      io.read
    end.to_s
    count = out[/LOAD_ERRORS=(\d+)/, 1]
    return nil if count == "0"
    errors = out.scan(/^LOAD_ERROR (.*)$/).flatten
    "#{game} (#{engine}): #{count ? errors.join(' | ') : out.strip[0, 200]}"
  end

  # The first module game's manifest lists.
  def first_module(game)
    mf = File.join(Harness::ROOT, "games", game, "manifest.rb")
    value = eval(Harness.source(mf), TOPLEVEL_BINDING, mf)
    (value.is_a?(Hash) ? value[:modules] : value).first
  end

  # Yields the environment that makes the harness load rel with text put before its first line, as tools/mutate.rb
  # plants a mutant; the file on disk is never touched.
  def with_planted(rel, text)
    Dir.mktmpdir("pa_profile_plant") do |dir|
      plant = File.join(dir, "plant.json")
      File.write(plant, JSON.generate("path" => File.join(Harness::ROOT, rel), "start" => 0, "end" => 0, "text" => text))
      yield("PA_MUTANT" => plant)
    end
  end
end
