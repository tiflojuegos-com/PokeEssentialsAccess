# The "hooked the loop" check: no after-style hook may be bound to a method that IS the screen's own
# blocking loop.
#
# An after hook runs when its method returns. In Essentials it is completely normal for the method that runs
# a screen -- often called main or pbUpdate, sometimes initialize itself -- to be the loop that keeps running
# until the player leaves. Bound there, a reader is correct in every respect and still useless: it speaks on
# the way out, and the screen is silent for exactly as long as somebody is in it. It looks like a working
# reader in the source and like a dead one in play, which is why it survived three separate reviews.
#
# The answer is always the same shape: hold the scene with around and read from the per-frame poll, or hook
# before if one read at the start is enough.
#
# The facts come from a committed census (test/static/loop_census.txt, written by build_reader_census.rb)
# because the dumps live outside the repo and are absent on CI.
require File.expand_path("reader_sites", File.dirname(__FILE__))

Suite.define("static: no after hook is bound to a method that blocks until the player leaves") do
  census_path = File.join(ReaderSites::ROOT, "test", "static", "loop_census.txt")
  truthy "the blocking-loop census is committed", File.file?(census_path)

  census = {}
  File.read(census_path).each_line do |line|
    next if line =~ /\A\s*#/ || line.strip.empty?
    site, profiles = line.split("=", 2)
    next unless profiles
    census[site.strip] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
  end

  declarations = ReaderSites.declarations
  missing_from_census = []
  offenders = []

  ReaderSites.after_hooks_by_file.each do |path, sites|
    targets = ReaderSites.profiles_for(path, declarations)
    sites.each do |site|
      blocks_in = census[site]
      if blocks_in.nil?
        missing_from_census.push("#{path}: #{site}")
        next
      end
      hit = (targets == :all) ? blocks_in : (targets & blocks_in)
      offenders.push("#{path}: #{site} blocks in #{hit.join('/')}") unless hit.empty?
    end
  end

  eq "the census covers every after hook (else: ruby test/static/build_reader_census.rb)",
     missing_from_census.sort, []
  eq "and none of them is the screen's own loop", offenders.sort, []
end
