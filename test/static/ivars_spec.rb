# Every instance variable a reader takes off a game object exists in a game that reader runs in (ivar_census.txt,
# from build_reader_census.rb); one the game names otherwise reads nil forever, silently. Each census line's tail
# past the bar is the informational class list, not profiles.
require File.expand_path("reader_sites", File.dirname(__FILE__))

Suite.define("static: every ivar a reader takes off a game object exists in that game") do
  census_path = File.join(ReaderSites::ROOT, "test", "static", "ivar_census.txt")
  truthy "the ivar census is committed", File.file?(census_path)

  census = {}
  File.read(census_path).each_line do |line|
    next if line =~ /\A\s*#/ || line.strip.empty?
    name, rest = line.split("=", 2)
    next unless rest
    profiles = rest.split("|", 2)[0].to_s
    census[name.strip.sub(/\A@/, "")] = profiles.split(",").map { |p| p.strip }.reject { |p| p.empty? }
  end
  truthy "and it has entries", census.length > 50

  # The diagnostic and the recorder read the mod's own modules by ivar, names no game has to carry.
  self_introspection = ["core/input/diag.rb", "core/util/recorder.rb"]

  declarations = ReaderSites.declarations
  missing_from_census = []
  partial = []
  offenders = []

  ReaderSites.ivars_by_file.each do |path, names|
    next if self_introspection.include?(path)
    targets = ReaderSites.profiles_for(path, declarations)
    names.each do |n|
      have = census[n]
      if have.nil?
        missing_from_census.push("#{path}: @#{n}")
      elsif targets == :all
        offenders.push("#{path}: @#{n} is in no surveyed game") if have.empty?
      elsif (targets & have).empty?
        offenders.push("#{path}: @#{n} is in #{have.empty? ? 'no game' : have.join('/')}, not in #{targets.join('/')}")
      elsif !(targets - have).empty?
        partial.push("#{path}: @#{n} missing in #{(targets - have).sort.join('/')}")
      end
    end
  end

  eq "the census covers every ivar the mod reads (else: ruby test/static/build_reader_census.rb)",
     missing_from_census.sort, []
  eq "and no reader takes an ivar its game does not have", offenders.sort, []

  # A name found in only some target games passes (readers branch between plugin copies), and is listed.
  unless partial.empty?
    puts "  note: #{partial.length} ivar reads are present in some of their target games but not all"
    partial.sort.each { |p| puts "    #{p}" }
  end
end
