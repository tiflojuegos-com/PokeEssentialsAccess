# Runs the whole suite: each engine's tests in a process of its own (test/run.rb), gen6 first, both under one seed so
# a failing order can be replayed. The arguments go to both: a path fragment narrows the tests, options go to
# minitest. Exits non-zero when either engine fails.
#   ruby test/run_all.rb                   # every test
#   ruby test/run_all.rb behavior/battle   # the tests whose path contains it
#   ruby test/run_all.rb --seed 1234       # replay an order
args = ARGV.dup
unless args.include?("--seed")
  args += ["--seed", (ENV["SEED"] || rand(0xFFFF)).to_s]
end
runner = File.expand_path("run.rb", File.dirname(__FILE__))

results = [:gen6, :gamedata].map do |engine|
  puts "\n=== #{engine} ==="
  [engine, system({ "PA_ENGINE" => engine.to_s }, "ruby", runner, *args)]
end

puts "\n#{results.map { |engine, ok| "#{engine}: #{ok ? 'ok' : 'FAIL'}" }.join('  ')}  (seed #{args[args.index('--seed') + 1]})"
exit(results.all? { |_e, ok| ok } ? 0 : 1)
