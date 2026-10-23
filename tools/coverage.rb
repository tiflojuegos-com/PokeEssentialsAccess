# Line and branch coverage of the mod (core, games, plugins, loader) by the test suite, both engines merged.
#   ruby tools/coverage.rb                         # the whole suite; a table of the least covered files
#   ruby tools/coverage.rb behavior/nav            # only the tests whose path contains it
#   ruby tools/coverage.rb --out cov.json          # also keep the merged result
#   ruby tools/coverage.rb --compare base.json     # the files whose coverage fell against a kept result
#   ruby tools/coverage.rb --lines core/nav/guide.rb   # the lines of one file no test runs
require "json"
require "tmpdir"

ROOT = File.expand_path("..", File.dirname(__FILE__))

# The value after flag in args, removed with it.
def take(args, flag)
  i = args.index(flag)
  return nil unless i
  args.delete_at(i)
  args.delete_at(i)
end

# The merged coverage: { path => { "lines" => [counts], "branches" => { branch key => count } } }.
def merge(results)
  out = {}
  results.each do |res|
    res.each do |path, cov|
      cur = (out[path] ||= { "lines" => [], "branches" => {} })
      cov["lines"].each_with_index do |n, i|
        next if n.nil?
        cur["lines"][i] = (cur["lines"][i] || 0) + n
      end
      (cov["branches"] || {}).each { |k, n| cur["branches"][k] = (cur["branches"][k] || 0) + n }
    end
  end
  out
end

# [covered, total] lines and [covered, total] branches of one file's coverage.
def tally(cov)
  lines = cov["lines"].compact
  br = cov["branches"].values
  [[lines.count { |n| n > 0 }, lines.length], [br.count { |n| n > 0 }, br.length]]
end

def pct(part, whole)
  whole.zero? ? 100.0 : (100.0 * part / whole).round(1)
end

args = ARGV.dup
out_path = take(args, "--out")
base_path = take(args, "--compare")
lines_of = take(args, "--lines")

dir = Dir.mktmpdir("pa-coverage")
env = { "PA_COVERAGE" => File.join(dir, "cov") }
system(env, "ruby", File.join(ROOT, "test", "run_all.rb"), *args)
parts = Dir.glob(File.join(dir, "cov*.json")).map { |f| JSON.parse(File.read(f)) }
abort "no coverage was written (did the suite load?)" if parts.empty?
merged = merge(parts)
File.write(out_path, JSON.generate(merged)) if out_path

if lines_of
  cov = merged[lines_of] or abort "#{lines_of}: not loaded by these tests"
  src = File.readlines(File.join(ROOT, lines_of))
  cov["lines"].each_with_index { |n, i| puts format("%5d  %s", i + 1, src[i].to_s.chomp) if n == 0 }
  exit 0
end

rows = merged.map { |path, cov| [path, *tally(cov)] }
total_l = rows.inject([0, 0]) { |a, r| [a[0] + r[1][0], a[1] + r[1][1]] }
total_b = rows.inject([0, 0]) { |a, r| [a[0] + r[2][0], a[1] + r[2][1]] }
puts format("\n%-60s %8s %8s", "file", "lines %", "branch %")
rows.sort_by { |_p, l, b| [pct(l[0], l[1]), pct(b[0], b[1])] }.first(40).each do |path, l, b|
  puts format("%-60s %8.1f %8.1f", path, pct(l[0], l[1]), pct(b[0], b[1]))
end
puts format("%-60s %8.1f %8.1f   (%d files)", "TOTAL", pct(*total_l), pct(*total_b), rows.length)

if base_path
  base = JSON.parse(File.read(base_path))
  fell = rows.map do |path, l, b|
    old = base[path] ? tally(base[path]) : [[0, l[1]], [0, b[1]]]
    [path, pct(*old[0]), pct(*l), pct(*old[1]), pct(*b)]
  end.select { |_p, ol, nl, ob, nb| nl < ol || nb < ob }
  puts(fell.empty? ? "\nno file lost coverage" : "\nfiles that lost coverage (lines old -> new, branches old -> new):")
  fell.each { |p, ol, nl, ob, nb| puts format("  %-58s %5.1f -> %5.1f   %5.1f -> %5.1f", p, ol, nl, ob, nb) }
  exit(fell.empty? ? 0 : 1)
end
