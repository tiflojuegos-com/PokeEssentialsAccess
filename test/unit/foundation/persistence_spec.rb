# The user-persistence subsystem (Tags, MapNames, Settings) -- the only part of the mod whose files are
# SHARED between players, so a format break silently breaks the community's tag dictionaries. Runs over
# the harness's sandbox data dir (Paths::DATA under the test cwd), wiping the files and in-memory stores
# before and after so no state leaks between suites or into the repo.
Suite.define("persistence: tags round-trip, prune, import; map names; settings clamp and top-up") do
  tags_file = PokeAccess::Tags::FILE
  import_file = PokeAccess::Tags::IMPORT
  names_file = PokeAccess::MapNames::FILE
  dir = File.dirname(tags_file)
  (Dir.mkdir(File.dirname(dir)) rescue nil)
  (Dir.mkdir(dir) rescue nil)
  truthy "the sandbox data dir exists", File.directory?(dir)
  wipe = lambda do
    [tags_file, import_file, names_file, PokeAccess::Tags::EXPORT].each { |f| (File.delete(f) rescue nil) }
    PokeAccess::Tags.instance_variable_set(:@tags, nil)
    PokeAccess::MapNames.instance_variable_set(:@names, nil)
  end
  wipe.call
  begin
    PokeAccess::Tags.set(3, 7, "Puerta norte")
    PokeAccess::Tags.set_category(3, 7, :exits)
    PokeAccess::Tags.set_hidden(5, 2, true)
    PokeAccess::Tags.instance_variable_set(:@tags, nil)
    eq "a saved name survives a reload", PokeAccess::Tags.get(3, 7), "Puerta norte"
    eq "a saved category survives a reload", PokeAccess::Tags.category(3, 7), :exits
    truthy "a hidden flag survives a reload", PokeAccess::Tags.hidden?(5, 2)

    PokeAccess::Tags.set(3, 7, "")
    PokeAccess::Tags.set_category(3, 7, nil)
    falsy "a record emptied of name+cat+hide is pruned", PokeAccess::Tags.rec(3, 7)

    File.open(import_file, "w") do |f|
      f.write("5:2=Pisada\n")
      f.write("9:1=Cartel oeste\tcat=signs\n")
    end
    added = PokeAccess::Tags.import_now
    eq "import adds only the entries the store lacks", added, 1
    eq "an imported record parses its tokens", PokeAccess::Tags.category(9, 1), :signs
    truthy "an existing record is never overwritten by import", PokeAccess::Tags.hidden?(5, 2)

    eq "export returns the entry count", PokeAccess::Tags.export, 2

    PokeAccess::MapNames.set(12, "Bosque renombrado")
    PokeAccess::MapNames.instance_variable_set(:@names, nil)
    eq "a map name survives a reload", PokeAccess::MapNames.get(12), "Bosque renombrado"
    PokeAccess::MapNames.set(12, "  ")
    falsy "a blank rename clears the entry", PokeAccess::MapNames.get(12)

    PokeAccess::Settings.set_numeric(:footstep_volume, "250", :vol)
    eq "a numeric setting clamps to its kind's bounds", PokeAccess::Config.footstep_volume, 100
    PokeAccess::Settings.set_numeric(:footstep_volume, "-5", :vol)
    eq "and to the lower bound", PokeAccess::Config.footstep_volume, 0
    PokeAccess::Settings.set_numeric(:footstep_volume, "80", :vol)

    PokeAccess::Settings.write
    data = PokeAccess::Settings.read
    missing = PokeAccess::Settings.schema_keys.reject { |k| data.has_key?(k) }
    eq "write serialises every schema key", missing, []

    doctored = data.reject { |k, _| k == "footstep_volume" }
    File.open(PokeAccess::Settings::FILE, "w") do |f|
      doctored.each { |k, v| f.write("#{k}=#{v}\n") }
    end
    PokeAccess::Settings.apply
    eq "apply tops the ini up when this version knows a key the file lacks",
       PokeAccess::Settings.read.has_key?("footstep_volume"), true
    eq "the topped-up value is the live one", PokeAccess::Config.footstep_volume, 80
  ensure
    wipe.call
    (File.delete(PokeAccess::Settings::FILE) rescue nil)
  end
end
