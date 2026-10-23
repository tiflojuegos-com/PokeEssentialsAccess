# Runs one engine's tests in this process (PA_ENGINE: gen6 by default, gamedata): gamedata runs the *_gd_test.rb
# files, gen6 all the others. The first argument that is not an option narrows them to the paths containing it, or
# any of its comma-separated fragments; the rest go to minitest (--seed, -n, -v). After the tests come the two nets
# that watch the whole run: no text reaches speak with raw control codes, and no one-parameter block of the mod is
# handed several values. With PA_SWALLOWED set, it also lists the failures the mod's rescues swallowed.
TESTDIR = File.expand_path(File.dirname(__FILE__))
VALUED = %w[--seed -s --name -n --exclude -e].freeze

args = ARGV.dup
filter = nil
i = 0
while i < args.length
  if VALUED.include?(args[i])
    i += 2
  elsif args[i].start_with?("-")
    i += 1
  else
    filter = args.delete_at(i)
    break
  end
end

require File.join(TESTDIR, "test_helper")

all = Dir.glob(File.join(TESTDIR, "{unit,behavior,static}", "**", "*_test.rb")).sort
mine = all.select { |p| (p =~ /_gd_test\.rb\z/ ? :gamedata : :gen6) == ENGINE }

if ENGINE == :gen6
  census = File.read(File.join(TESTDIR, "static", "test_census.txt")).split("\n").map { |l| l.strip }
  census = census.reject { |l| l.empty? || l.start_with?("#") }
  found = all.map { |p| p[(TESTDIR.length + 1)..-1] }
  unless census == found
    puts "[gen6] the test files differ from test/static/test_census.txt (ruby test/static/build_census.rb):"
    (census - found).first(10).each { |m| puts "  in the census, not on disk: #{m}" }
    (found - census).first(10).each { |m| puts "  on disk, not in the census: #{m}" }
    exit 1
  end
  puts "[gen6] the whole suite: #{all.length} test files" unless filter
end
if filter
  parts = filter.split(",")
  missing = parts.reject { |part| all.any? { |p| p.include?(part) } }
  unless missing.empty?
    puts "[#{ENGINE}] no test file matches '#{missing.join("', '")}'"
    exit 1
  end
  mine = mine.select { |p| parts.any? { |part| p.include?(part) } }
end

load_failures = []
mine.each do |f|
  begin
    require f
  rescue StandardError, ScriptError, SystemStackError => e
    load_failures.push("#{f[(TESTDIR.length + 1)..-1]}: #{e.class}: #{e.message}")
  end
end

ok = Minitest.run(args)

nets = {
  "texts that reached speak with raw control codes (use speak_clean)" =>
    SpeakCapture.raw_offenders.map { |test, text| "#{test}: #{text.inspect}" },
  "one-parameter blocks of the mod handed several values" => ArityNet.offenders,
  "test files that failed to load" => load_failures
}
nets.each do |what, found|
  next if found.empty?
  ok = false
  puts "\n[#{ENGINE}] #{what}:"
  found.first(20).each { |f| puts "  #{f}" }
end

if ENV["PA_SWALLOWED"]
  sites = PokeAccess.swallowed_sites
  puts "\n[#{ENGINE}] failures the mod's rescues swallowed during the run (#{sites.length} places):"
  sites.each { |site, n, first| puts "  #{site} x#{n}: #{first}" }
end

exit(ok ? 0 : 1)
