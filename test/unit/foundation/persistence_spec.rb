# The user-persistence subsystem (Tags, Marks, MapNames, Settings) -- the only part of the mod whose files
# are SHARED between players, so a format break silently breaks the community's dictionaries. Runs over the
# harness's sandbox data dir (Paths::DATA under the test cwd), wiping the files and in-memory stores before
# and after so no state leaks between suites or into the repo.
#
# The three dictionaries sit on one Dictionary plumbing, so what is pinned per store is its own shape (key,
# record, line) and what is pinned once is the plumbing: import adds only what the store lacks, export
# counts, and every file is stamped with the game it belongs to -- a file from another game is refused,
# a file from before the stamp existed still imports.

# Every file the three dictionaries can touch.
def persistence_files
  [PokeAccess::Tags, PokeAccess::Marks, PokeAccess::MapNames].map do |m|
    [m::FILE, m::IMPORT, m::EXPORT]
  end.flatten
end

# Deletes every dictionary file and forgets the loaded stores, so a suite starts and ends with nothing.
def persistence_wipe
  persistence_files.each { |f| (File.delete(f) rescue nil) }
  [PokeAccess::Tags, PokeAccess::Marks, PokeAccess::MapNames].each { |m| m.reload! }
end

Suite.define("persistence: tags round-trip, prune, import; map names; settings clamp and top-up") do
  tags_file = PokeAccess::Tags::FILE
  import_file = PokeAccess::Tags::IMPORT
  dir = File.dirname(tags_file)
  (Dir.mkdir(File.dirname(dir)) rescue nil)
  (Dir.mkdir(dir) rescue nil)
  truthy "the sandbox data dir exists", File.directory?(dir)
  persistence_wipe
  begin
    PokeAccess::Tags.set(3, 7, "Puerta norte")
    PokeAccess::Tags.set_category(3, 7, :exits)
    PokeAccess::Tags.set_hidden(5, 2, true)
    PokeAccess::Tags.reload!
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

    seen = []
    PokeAccess::Tags.each_record { |mid, eid, r| seen.push([mid, eid, r["hidden"] ? :hidden : :shown]) }
    eq "each_record walks every record in file order", seen, [[5, 2, :hidden], [9, 1, :shown]]
    (File.delete(import_file) rescue nil)
    PokeAccess::Tags.delete(5, 2)
    falsy "delete forgets a record whole, hidden flag included", PokeAccess::Tags.rec(5, 2)
    PokeAccess::Tags.reload!
    falsy "and that is what the file says too", PokeAccess::Tags.rec(5, 2)

    PokeAccess::MapNames.set(12, "Bosque renombrado")
    PokeAccess::MapNames.reload!
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
    persistence_wipe
    (File.delete(PokeAccess::Settings::FILE) rescue nil)
  end
end

# The marks dictionary: a tile keyed by map and coordinates, its own file, its own line format.
Suite.define("persistence: marks round-trip by tile, list per map in reading order, import and export") do
  persistence_wipe
  begin
    m = PokeAccess::Marks
    m.set(87, 15, 17, "Losa del medio")
    m.set(87, 4, 17, "Palanca")
    m.set(87, 10, 3, "Arriba del todo")
    m.set(119, 13, 11, "Rejilla")
    m.reload!
    eq "a mark survives a reload, keyed by its tile", m.get(87, 15, 17), "Losa del medio"
    falsy "a tile never marked has none", m.get(87, 15, 18)
    eq "a map lists its marks row by row, left to right",
       m.on_map(87), [[10, 3, "Arriba del todo"], [4, 17, "Palanca"], [15, 17, "Losa del medio"]]
    truthy "a map with marks says so", m.any_on?(87)
    falsy "and one without does not", m.any_on?(88)

    m.set(87, 4, 17, "   ")
    falsy "a blank name removes the mark", m.get(87, 4, 17)
    m.delete(119, 13, 11)
    falsy "so does delete, and it empties the map out of the store", m.any_on?(119)
    eq "which leaves this many", m.count, 2

    File.open(m::IMPORT, "w") do |f|
      f.write("# game: #{PokeAccess::Game.profile_name}\n")
      f.write("87:15,17=Otro nombre\n")
      f.write("87:1,1=Entrada\n")
      f.write("garbage line=nope\n")
    end
    eq "import adds only the tiles the store lacks and skips a malformed key", m.import_now, 1
    eq "an existing mark is never overwritten by import", m.get(87, 15, 17), "Losa del medio"
    eq "export counts what it wrote", m.export, 3
    truthy "and the export file is the store, line for line",
           File.read(m::EXPORT).include?("87:1,1=Entrada")
  ensure
    persistence_wipe
  end
end

# MapNames gained import and export by moving onto the same plumbing; a player who renamed a dungeon can
# hand the file on, and the merge keeps their own names over the imported ones.
Suite.define("persistence: map names import and export like the other dictionaries") do
  persistence_wipe
  begin
    mn = PokeAccess::MapNames
    mn.set(12, "Bosque renombrado")
    File.open(mn::IMPORT, "w") do |f|
      f.write("12=Bosque ajeno\n")
      f.write("40=Cueva del eco\n")
      f.write("0=nunca\n")
    end
    eq "import adds the maps the store lacks and ignores map 0", mn.import_now, 1
    eq "the player's own name wins over the imported one", mn.get(12), "Bosque renombrado"
    eq "the new one arrived", mn.get(40), "Cueva del eco"
    names = []
    mn.each_name { |mid, nm| names.push([mid, nm]) }
    eq "each_name walks them by map id", names, [[12, "Bosque renombrado"], [40, "Cueva del eco"]]
    eq "export counts both", mn.export, 2
  ensure
    persistence_wipe
  end
end

# The game stamp: keys are map ids, and a map id means something else in every other game, so a file must
# know which game it belongs to and an import must refuse a stranger's.
Suite.define("persistence: every dictionary file is stamped with its game, and a foreign file is refused") do
  persistence_wipe
  begin
    mine = PokeAccess::Game.profile_name
    truthy "the running profile has a name to stamp with", mine && !mine.empty?

    PokeAccess::Tags.set(3, 7, "Puerta norte")
    head = File.read(PokeAccess::Tags::FILE).split("\n")[0, 4]
    truthy "the tags file carries the stamp in its comment block", head.include?("# game: #{mine}")
    PokeAccess::Marks.set(1, 2, 3, "Tienda")
    truthy "so does the marks file", File.read(PokeAccess::Marks::FILE).include?("# game: #{mine}")
    PokeAccess::MapNames.set(5, "Pueblo")
    truthy "and the map names file", File.read(PokeAccess::MapNames::FILE).include?("# game: #{mine}")

    File.open(PokeAccess::Marks::IMPORT, "w") do |f|
      f.write("# PokeAccess: marcadores\n")
      f.write("# game: #{mine}_otro\n")
      f.write("1:9,9=Ajena\n")
    end
    eq "a file stamped with another game is reported foreign, by name",
       PokeAccess::Marks.import_status, [:foreign, "#{mine}_otro"]
    eq "and import_now refuses it outright", PokeAccess::Marks.import_now, 0
    falsy "nothing of it reached the store", PokeAccess::Marks.get(1, 9, 9)
    PokeAccess::Marks.reload!
    falsy "not even through the merge on load", PokeAccess::Marks.get(1, 9, 9)

    File.open(PokeAccess::Marks::IMPORT, "w") { |f| f.write("1:9,9=Antigua\n") }
    eq "a file with no stamp -- written before stamps existed -- is ready, game unknown",
       PokeAccess::Marks.import_status, [:ready, nil]
    eq "and imports as it always did", PokeAccess::Marks.import_now, 1

    (File.delete(PokeAccess::Marks::IMPORT) rescue nil)
    eq "with no file there is nothing to import", PokeAccess::Marks.import_status, [:none]
  ensure
    persistence_wipe
  end
end
