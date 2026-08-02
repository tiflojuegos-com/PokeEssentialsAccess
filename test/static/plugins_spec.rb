# The plugins/ layer: readers for THIRD-PARTY plugins, loaded only by the profiles that declare them.
#
# Two rules make the layer safe, and neither survives on discipline alone:
#
#   1. A declared plugin must EXIST. A profile that names a file nobody wrote loses that screen in silence
#      -- the loader logs it and carries on, by design, so nothing else would ever complain.
#   2. Every hook in plugins/ is :optional. The plugin may be absent, or be a version that never had the
#      method: a non-optional registration would park a permanent entry in Hooks.missing, which by contract
#      is the list of TYPOS. Filling it with expected absences is how a real typo stops being noticed.
#
# The detection table is checked too: it is what lets the diagnostic tell a player "this game ships a plugin
# we know and your profile never declared it", so a plugin missing from the table is a hole in that net.
#
# eval reads the mod's OWN manifests, which are Ruby literals committed in this repo -- the same way the
# loader reads them, because RGSS has no JSON parser to use instead. No external input reaches it.
Suite.define("static: the plugins layer is declared, complete and optional") do
  root = File.expand_path(File.join(File.dirname(__FILE__), "..", ".."))
  pdir = File.join(root, "plugins")

  files = Dir.glob(File.join(pdir, "*.rb")).map { |p| File.basename(p, ".rb") }.reject { |n| n == "manifest" }
  table = eval(File.read(File.join(pdir, "manifest.rb")))

  truthy "the plugins manifest is a name => detection-class table", table.is_a?(Hash)
  eq "every plugin file is in the table",
     files.reject { |n| table.has_key?(n.to_sym) }.sort, []
  eq "and every table entry has its file",
     table.keys.map { |k| k.to_s }.reject { |n| files.include?(n) }.sort, []
  falsy "each entry names a class to detect it by",
        table.values.any? { |v| v.nil? || v.to_s.strip.empty? }

  # What the profiles declare has to be real, or the screen goes quiet with only a line in the log.
  declared = {}
  Dir.glob(File.join(root, "games", "*", "manifest.rb")).sort.each do |mf|
    value = eval(File.read(mf))
    next unless value.is_a?(Hash)
    (value[:plugins] || []).each { |n| (declared[n.to_s] ||= []).push(File.basename(File.dirname(mf))) }
  end
  eq "every plugin a profile declares exists in plugins/",
     declared.keys.reject { |n| files.include?(n) }.sort, []

  # A plugin nobody loads is dead weight; worse, it reads as covered when no game actually uses it.
  eq "and every plugin file is declared by at least one profile",
     (files - declared.keys).sort, []

  # Rule 2, read off the source: an after/before/around/read_on_open registration without :optional.
  offenders = []
  Dir.glob(File.join(pdir, "*.rb")).each do |path|
    next if File.basename(path) == "manifest.rb"
    File.read(path).each_line.with_index(1) do |line, i|
      next if line.strip.start_with?("#")
      next unless line =~ /\b(after_hook|before_hook|around_hook|read_on_open|after|before|around)\s*\(\s*"/
      next if line.include?("optional")
      offenders.push("#{File.basename(path)}:#{i}")
    end
  end
  eq "every hook in plugins/ is :optional", offenders, []
end

# The detection net. Declaring by hand has one failure mode -- forgetting -- and it is SILENT: the screen
# just says nothing. This is what makes it speak up, so it has to work on the two cases that matter.
Suite.define("plugins: a plugin the game has but nobody declared shows up in the diagnostic") do
  pl = PokeAccess::Plugins
  saved_loaded = pl.loaded.dup
  saved_table = pl.table
  begin
    Object.const_set(:PaSpecPluginScene, Class.new) unless Object.const_defined?(:PaSpecPluginScene)
    pl.table = { :spec_present => "PaSpecPluginScene", :spec_absent => "PaSpecNoSuchScene" }
    pl.loaded.clear

    eq "a plugin whose class IS in the game and was never declared is reported",
       pl.undeclared, ["spec_present"]

    pl.note_loaded("spec_present")
    eq "once declared and loaded it stops being reported", pl.undeclared, []
    eq "and noting it twice does not duplicate it",
       (pl.note_loaded("spec_present"); pl.loaded.grep(/spec_present/).length), 1

    pl.loaded.clear
    pl.table = { :spec_absent => "PaSpecNoSuchScene" }
    eq "a plugin the game does NOT have is never reported, declared or not", pl.undeclared, []

    pl.table = "no soy un hash"
    eq "a broken table degrades to reporting nothing instead of raising in the diag", pl.undeclared, []
  ensure
    pl.loaded.replace(saved_loaded)
    pl.table = saved_table
  end
end
