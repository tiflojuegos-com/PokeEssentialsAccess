# The silent-nil check: every instance variable a reader takes off a game object must actually exist in a
# game that reader can run in.
#
# This is the failure mode nothing else in the suite can see. The class exists, the method exists, the hook
# binds, and the ivar is named something else in that game -- so the read answers nil forever, raises
# nothing, logs nothing, and the screen is simply quiet. A behaviour spec cannot catch it either, because a
# stub has exactly the ivars the spec gave it: the fixture agrees with the reader and both are wrong.
#
# The dumps live outside the repo and are absent on CI, so the facts come from a committed census
# (test/static/ivar_census.txt, written by build_reader_census.rb) rather than a live scan. Adding a reader
# that names a new ivar fails here until the census is regenerated, which is the point: regenerating is what
# asks the games the question.
require File.expand_path("reader_sites", File.dirname(__FILE__))

Suite.define("static: every ivar a reader takes off a game object exists in that game") do
  census_path = File.join(ReaderSites::ROOT, "test", "static", "ivar_census.txt")
  truthy "the ivar census is committed", File.file?(census_path)

  census = {}
  File.read(census_path).each_line do |line|
    next if line =~ /\A\s*#/ || line.strip.empty?
    name, rest = line.split("=", 2)
    next unless rest
    # Everything past the bar is the informational class list, not profiles.
    profiles = rest.split("|", 2)[0].to_s
    census[name.strip.sub(/\A@/, "")] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
  end
  truthy "and it has entries", census.length > 50

  # Two exemptions, both structural rather than a list of awkward names.
  #
  # The diagnostic and the recorder introspect the MOD's own modules by ivar -- that is what they are for,
  # and those modules expose no accessors on purpose. Nothing in a game has to have those names.
  #
  # The v22 readers target an Essentials generation no surveyed game runs, so the census cannot answer for
  # them either way. They are reported below rather than silently skipped, and the exemption disappears by
  # itself the day a v22 dump joins the survey.
  self_introspection = ["core/input/diag.rb", "core/util/recorder.rb"]
  unsurveyed = %r{/v22/}

  declarations = ReaderSites.declarations
  missing_from_census = []
  unverifiable = []
  offenders = []

  ReaderSites.ivars_by_file.each do |path, names|
    next if self_introspection.include?(path)
    targets = ReaderSites.profiles_for(path, declarations)
    names.each do |n|
      have = census[n]
      if have.nil?
        missing_from_census.push("#{path}: @#{n}")
      elsif path =~ unsurveyed
        unverifiable.push("#{path}: @#{n}") if have.empty?
      elsif targets == :all
        offenders.push("#{path}: @#{n} is in no surveyed game") if have.empty?
      elsif (targets & have).empty?
        offenders.push("#{path}: @#{n} is in #{have.empty? ? 'no game' : have.join('/')}, not in #{targets.join('/')}")
      end
    end
  end

  eq "the census covers every ivar the mod reads (else: ruby test/static/build_reader_census.rb)",
     missing_from_census.sort, []
  eq "and no reader takes an ivar its game does not have", offenders.sort, []

  # Not a failure, and not hidden either: these are the reads the survey cannot speak to.
  puts "  note: #{unverifiable.length} ivar reads target an engine no surveyed game runs" unless unverifiable.empty?
end
