# The test runner: loads the toolkit under the engine stubs, runs every spec's suites under a fresh reset, then in
# the gen6 pass runs the static checks and re-invokes itself for gamedata. Exits non-zero on any failed assertion.
#   ruby test/run_all.rb                  # both engines + static checks
#   ruby test/run_all.rb behavior/battle  # specs whose path matches, in both engines (no static checks)
SUPPORT = File.expand_path("support", File.dirname(__FILE__))
require File.join(SUPPORT, "harness")
require File.join(SUPPORT, "framework")
require File.join(SUPPORT, "speak_capture")
require File.join(SUPPORT, "reset")
require File.join(SUPPORT, "poke_builder")
require File.join(SUPPORT, "world_builder")
require File.join(SUPPORT, "tile_world")
require File.join(SUPPORT, "hpa_helpers")
require File.join(SUPPORT, "route_helpers")
require File.join(SUPPORT, "replay")
require File.join(SUPPORT, "game_functions")

PROFILE = (ENGINE == :gamedata ? "anil" : "pokemon_z")
FILTER = ARGV.find { |a| a !~ /^--/ }

# Loads the toolkit; a load error aborts the run.
load_errors = Harness.load_all(PROFILE)
unless load_errors.empty?
  puts "[#{ENGINE}] LOAD FAILED:"
  load_errors.first(10).each { |e| puts "  #{e}" }
  exit 1
end
SpeakCapture.install
SpeakCapture.clear_all

# The spec files for this engine: gamedata runs the *_gd_spec files, gen6 all the others. A filter matching no spec
# in either engine fails; matching none in just this one is fine.
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

# The spec files must match the committed census (test/static/spec_census.txt), so a glob that stops matching fails
# instead of shrinking the suite. Regenerate with: ruby test/static/build_reader_census.rb
if ENGINE == :gen6
  census_path = File.join(testdir, "static", "spec_census.txt")
  unless File.exist?(census_path)
    puts "[gen6] SPEC CENSUS MISSING: test/static/spec_census.txt (ruby test/static/build_reader_census.rb)"
    exit 1
  end
  census = File.read(census_path).split("\n").map { |l| l.strip }.reject { |l| l.empty? || l[0, 1] == "#" }
  found = specs_all.map { |p| p[(testdir.length + 1)..-1].tr("\\", "/") }.sort
  census_missing = census - found
  census_extra = found - census
  unless census_missing.empty? && census_extra.empty?
    puts "[gen6] SPEC CENSUS MISMATCH (ruby test/static/build_reader_census.rb):"
    census_missing.first(10).each { |m| puts "  censused but not on disk: #{m}" }
    census_extra.first(10).each { |m| puts "  on disk but not censused: #{m}" }
    exit 1
  end
end

Assert.pass = 0; Assert.fail = 0; Assert.failures = []

# A spec whose top-level code raises is a failure of that file, not the end of the run (SystemStackError is not a
# StandardError or ScriptError, so it is named too).
specs.each do |f|
  begin
    require f
  rescue StandardError, ScriptError, SystemStackError => e
    Assert.suite = File.basename(f)
    Assert.check("spec failed to load", false, "#{e.class}: #{e.message}")
    puts "  FAIL(load)  #{File.basename(f)}"
  end
end

# Runs each suite under a fresh reset; a suite that asserts nothing is a failure.
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
  if added == 0 && added_fail == 0
    Assert.check("la suite asevera algo", false, "0 asserts: un cuerpo que no comprueba nada")
    added_fail = Assert.fail - before
  end
  status = added_fail > 0 ? "FAIL(#{added_fail})" : "ok"
  puts "  #{status}  #{name}"
end

# The raw-code net (test/support/speak_capture.rb), checked once per pass: no reader may hand speak a text with
# control codes, which the captured log would show already cleaned.
Assert.suite = "speak capture"
eq("no reader passes raw control codes to speak (use speak_clean)", SpeakCapture.raw_offenders, [])

puts "\n[#{ENGINE}] #{Assert.pass} ok, #{Assert.fail} fail"
Assert.failures.each { |f| puts "  #{f}" }
engine_fail = Assert.fail

# Only the gen6 invocation runs the static checks (skipped on a filtered run) and then the gamedata pass, forwarding
# the filter to it:
# - ruby187 reports check187.py's own last line (a real 1.8.7 parse, or a pattern-only pass without that
#   interpreter), not a verdict made from its exit code.
# - the manifest check runs as a subprocess, whose verdict counts as an assertion of its own suite.
# - the second total, statics included, adds extra_fail for these subprocess checks, which do not go through Assert.
extra_fail = 0
if ENGINE == :gen6
  if FILTER
    puts "\n=== static checks skipped (filtered run) ==="
  else
    puts "\n=== static checks ==="
    out187 = `python "#{File.join(File.dirname(__FILE__), "check187.py")}" 2>&1`
    ok187 = $?.success?
    puts out187 unless ok187
    puts "ruby187: #{ok187 ? out187.to_s.strip.split("\n").last.to_s.sub(/\AOK:\s*/, "") : 'FAIL'}"
    extra_fail += 1 unless ok187
    outman = `ruby "#{File.join(File.dirname(__FILE__), "static", "manifest_check.rb")}" 2>&1`
    okman = $?.success?
    Assert.suite = "static/manifiestos: manifiestos contra disco"
    Assert.check("cada manifest.rb casa con los ficheros y con el catalogo", okman,
                 outman.to_s.strip.split("\n").reject { |l| l =~ /\AOK/ }.first(10).join(" | "))
    puts outman.to_s.strip.split("\n").first
    extra_fail += 1 unless okman
    par = (PokeAccess::I18n.parity_issues rescue [])
    puts(par.empty? ? "i18n parity: OK" : "i18n parity WARNING (no rompe CI): #{par.first(10).join(', ')}")
  end

  puts "\n[#{ENGINE}] total con estaticos: #{Assert.pass} ok, #{Assert.fail + extra_fail} fail"
  Assert.failures[engine_fail..-1].to_a.each { |f| puts "  #{f}" }
  engine_fail = Assert.fail

  puts "\n=== gamedata engine ==="
  ok_gd = system({ "PA_ENGINE" => "gamedata" }, "ruby", __FILE__, *ARGV)
  extra_fail += 1 unless ok_gd
end

exit((engine_fail + extra_fail) == 0 ? 0 : 1)
