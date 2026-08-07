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
SpeakCapture.clear_all

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

# A suite that asserts NOTHING (an early return, a helper that stopped registering asserts) prints the same
# "ok" as one that verified twenty things, so silent coverage loss looks like success. Counting
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

# The raw-code net (see test/support/speak_capture.rb). Checked once for the whole pass, because the
# list accumulates across suites: a reader that hands speak a text the game has not had cleaned
# sounds the control code out loud, and every assertion on the captured log sees that text already
# cleaned, so nothing else in the harness can see it.
Assert.suite = "speak capture"
eq("no reader passes raw control codes to speak (use speak_clean)", SpeakCapture.raw_offenders, [])

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
    # The check's OWN last line, not a verdict invented from the exit code. It has three of them, and they
    # do not mean the same thing: a real 1.8.7 parse of every file, a pattern-only pass when that
    # interpreter is missing (CI, or a checkout without the sibling tools/ folder), or a failure. Printing
    # "ruby187: OK" for all three turned a maybe into a promise.
    out187 = `python "#{File.join(File.dirname(__FILE__), "check187.py")}" 2>&1`
    ok187 = $?.success?
    puts out187 unless ok187
    puts "ruby187: #{ok187 ? out187.to_s.strip.split("\n").last.to_s.sub(/\AOK:\s*/, "") : 'FAIL'}"
    extra_fail += 1 unless ok187
    # Capturado y contado, no lanzado y olvidado. Como subproceso suelto su veredicto no entraba en
    # Assert.pass/fail (el total de la suite lo subcontaba), sus problemas se imprimian sin decir de que
    # comprobacion venian, y no aparecian en el resumen de fallos del final con los demas.
    outman = `ruby "#{File.join(File.dirname(__FILE__), "static", "manifest_check.rb")}" 2>&1`
    okman = $?.success?
    Assert.suite = "static/manifiestos: manifiestos contra disco"
    Assert.check("cada manifest.rb casa con los ficheros y con el catalogo", okman,
                 outman.to_s.strip.split("
").reject { |l| l =~ /\AOK/ }.first(10).join(" | "))
    puts outman.to_s.strip.split("
").first
    extra_fail += 1 unless okman
    par = (PokeAccess::I18n.parity_issues rescue [])
    puts(par.empty? ? "i18n parity: OK" : "i18n parity WARNING (no rompe CI): #{par.first(10).join(', ')}")
  end

  # Los estaticos corren DESPUES del resumen de arriba, asi que sus aserciones no entran en aquel numero.
  # En vez de reordenar el fichero, se reimprime el total ya completo: el de arriba cuenta las suites, este
  # cuenta la pasada entera, y cualquier fallo estatico sale nombrado aqui.
  # extra_fail cuenta aqui, no solo en el codigo de salida. Los estaticos que corren como subproceso
  # (ruby187, manifest_check) no pasan por Assert, asi que un FAIL suyo dejaba la linea diciendo "0 fail"
  # mientras el run salia con codigo 1: quien mira la consola y no el codigo se lo cree.
  puts "
[#{ENGINE}] total con estaticos: #{Assert.pass} ok, #{Assert.fail + extra_fail} fail"
  Assert.failures[engine_fail..-1].to_a.each { |f| puts "  #{f}" }
  engine_fail = Assert.fail

  puts "\n=== gamedata engine ==="
  ok_gd = system({ "PA_ENGINE" => "gamedata" }, "ruby", __FILE__, *ARGV)
  extra_fail += 1 unless ok_gd
end

exit((engine_fail + extra_fail) == 0 ? 0 : 1)
