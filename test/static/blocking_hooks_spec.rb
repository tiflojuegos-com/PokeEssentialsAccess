# No after hook is bound to a method that is the screen's own blocking loop (it would speak only on the way out);
# the facts come from test/static/loop_census.txt, written by build_reader_census.rb, as the dumps are not on CI.
# Each line splits on " = ", not "=", since a setter hook's key itself ends in "=" (Class#selected=).
require File.expand_path("reader_sites", File.dirname(__FILE__))

Suite.define("static: no after hook is bound to a method that blocks until the player leaves") do
  census_path = File.join(ReaderSites::ROOT, "test", "static", "loop_census.txt")
  truthy "the blocking-loop census is committed", File.file?(census_path)

  census = {}
  no_dump = []
  File.read(census_path).each_line do |line|
    next if line =~ /\A\s*#/ || line.strip.empty?
    site, profiles = line.split(" = ", 2)
    next unless profiles
    key = site.strip
    if profiles.strip == "NO-DUMP"
      census[key] = []
      no_dump.push(key)
    else
      census[key] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
    end
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

  unresolved = ReaderSites.unresolved_after_sites.values.flatten.length
  truthy "no new after hook with a computed class or method (was #{unresolved}, ceiling 44)", unresolved <= 44
  # The no-dump rows by name, not count, so a new one needs its reason here: royal's Puntos scene defines
  # pbChangeSelection but not updateDescription, hence both bound :optional.
  KNOWN_NO_DUMP = ["PokemonOptionPuntos_Scene#updateDescription"]
  eq "no new after hook that no dump can corroborate", no_dump.sort, KNOWN_NO_DUMP.sort
end
