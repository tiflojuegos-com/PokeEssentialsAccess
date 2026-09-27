require "rbconfig"

# Every profile loads whole without an error, core, plugins and the commons it imports first as the loader does, in
# its own process under each engine: a misspelt DSL method only shows when a Game.define block runs. A common also
# loads on its own, as it must: its importers' modules only come after it.
Suite.define("static: every profile loads whole, under either engine's stubs, without an error") do
  harness = File.join(Harness::ROOT, "test", "support", "harness")
  failures = []
  Dir.glob(File.join(Harness::ROOT, "games", "*", "manifest.rb")).sort.each do |mf|
    game = File.basename(File.dirname(mf))
    %w[gen6 gamedata].each do |engine|
      script = "require #{harness.inspect}; e = Harness.load_all(#{game.inspect}); " \
               "puts 'LOAD_ERRORS=' + e.length.to_s; e.first(3).each { |x| puts 'LOAD_ERROR ' + x }"
      out = IO.popen([{ "PA_ENGINE" => engine }, RbConfig.ruby, "-e", script], :err => [:child, :out]) { |io| io.read }
      count = out.to_s[/LOAD_ERRORS=(\d+)/, 1]
      next if count == "0"
      errors = out.to_s.scan(/^LOAD_ERROR (.*)$/).flatten
      failures.push("#{game} (#{engine}): #{count ? errors.join(' | ') : out.to_s.strip[0, 200]}")
    end
  end
  eq "no profile raises while it loads", failures, []
end
