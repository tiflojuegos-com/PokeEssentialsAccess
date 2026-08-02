# The single test runner: loads the toolkit under the chosen engine stubs, requires every spec (which
# register suites), runs each suite under a fresh reset, and tallies pass/fail with traceable output.
# Then, only in the default (gen6) pass, runs the static checks (manifest, i18n parity warning, ruby187)
# and re-invokes itself for the gamedata engine. Usage:
#   ruby test/run_all.rb                  # both engines + static checks
#   ruby test/run_all.rb behavior/battle  # only specs whose path matches the filter, in BOTH engines
#                                         # (static checks skipped; a filter matching nothing fails)
# Exit code is non-zero if any assertion failed. That includes i18n parity: the static spec asserts
# it, so a drifted lang/ key fails CI on purpose (the runner's own parity print is just a warning).
SUPPORT = File.expand_path("support", File.dirname(__FILE__))
require File.join(SUPPORT, "harness")
require File.join(SUPPORT, "framework")
require File.join(SUPPORT, "speak_capture")
require File.join(SUPPORT, "reset")
require File.join(SUPPORT, "poke_builder")
require File.join(SUPPORT, "world_builder")
require File.join(SUPPORT, "hpa_helpers")
require File.join(SUPPORT, "replay")

PROFILE = (ENGINE == :gamedata ? "anil" : "pokemon_z")
FILTER = ARGV.find { |a| a !~ /^--/ }

# Loads the toolkit; a load error is reported as a failed implicit suite and aborts (nothing else can run).
load_errors = Harness.load_all(PROFILE)
unless load_errors.empty?
  puts "[#{ENGINE}] LOAD FAILED:"
  load_errors.first(10).each { |e| puts "  #{e}" }
  exit 1
end
SpeakCapture.install

# Requires the spec files for this engine. gen6 runs unit + the gen6/agnostic behaviour; gamedata runs the
# behaviour specs tagged _gd (the modern path). A path filter narrows the glob for focused local runs; a
# filter that selects nothing in EITHER engine is a typo, reported as a failure instead of a green no-op.
# Matching zero specs in just this engine is fine (e.g. a gen6-only filter during the gamedata pass).
testdir = File.expand_path(File.dirname(__FILE__))
specs_all = Dir.glob(File.join(testdir, "{unit,behavior,static}", "**", "*_spec.rb")).sort
specs = specs_all.select { |p| ENGINE == :gamedata ? p =~ /_gd_spec\.rb$/ : p !~ /_gd_spec\.rb$/ }
if FILTER
  if specs_all.none? { |p| p.include?(FILTER) }
    puts "[#{ENGINE}] FILTER '#{FILTER}' matches no spec file in any engine"
    exit 1
  end
  specs = specs.select { |p| p.include?(FILTER) }
  puts "[#{ENGINE}] filter matches no specs for this engine (nothing to run)" if specs.empty?
end

Assert.pass = 0; Assert.fail = 0; Assert.failures = []

# Loading a spec runs its top-level code (requires, target class/method setup). A failure there -- a renamed
# game file required by a spec, a typo in a spec's top-level, a syntax error, runaway recursion -- must be
# attributed to that file and not abort the whole run: without this the exception propagates, sibling specs
# never load, the gamedata pass is skipped and no summary prints. ScriptError covers SyntaxError/LoadError;
# SystemStackError descends from Exception directly, so both need naming. Mirrors how harness reports a
# toolkit load error as its own failure, not a crash.
specs.each do |f|
  begin
    require f
  rescue StandardError, ScriptError, SystemStackError => e
    Assert.suite = File.basename(f)
    Assert.check("spec failed to load", false, "#{e.class}: #{e.message}")
    puts "  FAIL(load)  #{File.basename(f)}"
  end
end

# A suite that asserts NOTHING (an early return, a helper that stopped registering asserts) used to print
# the same "ok" as one that verified twenty things, so silent coverage loss looked like success. Counting
# the asserts it added names it -- a warning, not a failure: a suite may legitimately be a no-op on an
# engine, and the run should say so rather than break.
Suite.all.each do |name, body|
  Reset.between_suites
  Assert.suite = name
  before = Assert.fail
  before_pass = Assert.pass
  begin
    body.call
  rescue StandardError, ScriptError, SystemStackError => e
    Assert.check("suite raised", false, "#{e.class}: #{e.message}")
  end
  added_fail = Assert.fail - before
  added = (Assert.pass - before_pass) + added_fail
  status = added_fail > 0 ? "FAIL(#{added_fail})" : (added == 0 ? "ok(0 asserts!)" : "ok")
  puts "  #{status}  #{name}"
end

puts "\n[#{ENGINE}] #{Assert.pass} ok, #{Assert.fail} fail"
Assert.failures.each { |f| puts "  #{f}" }
engine_fail = Assert.fail

# The static checks and the second engine pass run only in the primary (gen6) invocation. A filtered run
# skips the statics (they scan the whole tree, defeating the point of a focused run) but still forwards the
# filter to the gamedata child, so one filtered invocation covers the matching specs of BOTH engines.
extra_fail = 0
if ENGINE == :gen6
  if FILTER
    puts "\n=== static checks skipped (filtered run) ==="
  else
    puts "\n=== static checks ==="
    ok187 = system("python", File.join(File.dirname(__FILE__), "check187.py"))
    puts "ruby187: #{ok187 ? 'OK' : 'FAIL'}"; extra_fail += 1 unless ok187
    okman = system("ruby", File.join(File.dirname(__FILE__), "static", "manifest_check.rb"))
    extra_fail += 1 unless okman
    par = (PokeAccess::I18n.parity_issues rescue [])
    puts(par.empty? ? "i18n parity: OK" : "i18n parity WARNING (no rompe CI): #{par.first(10).join(', ')}")
  end

  puts "\n=== gamedata engine ==="
  ok_gd = system({ "PA_ENGINE" => "gamedata" }, "ruby", __FILE__, *ARGV)
  extra_fail += 1 unless ok_gd
end

exit((engine_fail + extra_fail) == 0 ? 0 : 1)
