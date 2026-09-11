# The name every shareable dictionary is stamped with, which is the ONLY thing standing between a marks file
# from one game and the map ids of another. A map id means something else in every game, so a file imported
# into the wrong one names random events all over the region -- silently, which is the one failure a shared
# file must not have.
#
# The generic profile declares no name, so every game installed under it stamped the same word "generic" and
# any two of them accepted each other's files. There the editor's own title qualifies the stamp.
Suite.define("profile stamp: two games with no profile of their own do not share a stamp") do
  g = PokeAccess::Game
  saved_profiles = g.profiles.dup
  saved_sys = (defined?($data_system) ? $data_system : nil)
  path = "#{PokeAccess::Paths::DATA}/installed.json"
  saved_json = (File.read(path) rescue nil)
  sys = Object.new
  begin
    g.profiles.clear
    g.instance_variable_set(:@profile_name, nil)
    File.open(path, "w") { |f| f.write('{"profile": "generic"}') }

    def sys.game_title; "Pokemon Myth"; end
    $data_system = sys
    myth = g.profile_name
    eq "a generic install carries the game's own title", myth, "generic:Pokemon Myth"

    g.instance_variable_set(:@profile_name, nil)
    other = Object.new
    def other.game_title; "Pokemon Otro"; end
    $data_system = other
    truthy "so another generic install is a DIFFERENT game", g.profile_name != myth

    # The stamp is written and read back through Dictionary, whose line parser used to stop at the first
    # space -- which would have made every title of two words foreign to itself.
    file = "#{PokeAccess::Paths::DATA}/stamp_probe.txt"
    File.open(file, "w") { |f| f.write("# game: #{myth}\n1=algo\n") }
    eq "and a stamp with spaces in it survives the round trip",
       PokeAccess::Marks.file_game(file), myth
    File.delete(file) rescue nil

    g.instance_variable_set(:@profile_name, nil)
    $data_system = nil
    eq "with no title to be had, the bare stamp is still answered", g.profile_name, "generic"

    # A game WITH a profile keeps the profile name alone: it is already unique, and qualifying it would
    # orphan every file already shared between players of that game.
    g.profiles.push("anil")
    g.instance_variable_set(:@profile_name, nil)
    eq "a declared profile is the stamp, untouched", g.profile_name, "anil"
  ensure
    g.profiles.clear
    saved_profiles.each { |p| g.profiles.push(p) }
    g.instance_variable_set(:@profile_name, nil)
    $data_system = saved_sys
    if saved_json then File.open(path, "w") { |f| f.write(saved_json) } else (File.delete(path) rescue nil) end
  end
end

# Every one of these files is read a line at a time, and the tags format separates its tokens with a tab.
# A name carrying either -- pasted, not typed -- came back truncated on the NEXT load, long after the player
# had moved on, and with no error anywhere.
# Every unprofiled install before 0.4.6 stamped the bare word "generic", so a file so stamped may well be
# this very game's own; taking the qualified stamp literally refused the player their own markers.
Suite.define("profile stamp: a file stamped by an older unprofiled install still imports into its own game") do
  g = PokeAccess::Game
  saved_profiles = g.profiles.dup
  saved_name = g.instance_variable_get(:@profile_name)
  file = PokeAccess::Marks::IMPORT
  begin
    g.profiles.clear
    g.instance_variable_set(:@profile_name, "generic:Spec Game")
    File.open(file, "w") { |f| f.write("# game: generic\n1:2,2=Vieja\n") }
    eq "the bare stamp of the older versions is taken as this game's", PokeAccess::Marks.import_status, [:ready, "generic"]
    File.open(file, "w") { |f| f.write("# game: generic:Otro juego\n1:2,2=Ajena\n") }
    eq "while another game's qualified stamp is still refused",
       PokeAccess::Marks.import_status, [:foreign, "generic:Otro juego"]
  ensure
    (File.delete(file) rescue nil)
    g.profiles.clear
    saved_profiles.each { |p| g.profiles.push(p) }
    g.instance_variable_set(:@profile_name, saved_name)
  end
end

Suite.define("dictionaries: a name with a tab or a line break in it survives its own file") do
  begin
    PokeAccess::Tags.set(1, 40, "Casa\tdel\nprofesor")
    PokeAccess::Tags.reload!
    eq "a tag keeps every word, on one line", PokeAccess::Tags.get(1, 40), "Casa del profesor"

    PokeAccess::Marks.set(1, 8, 8, "aqui\tme\rquede")
    PokeAccess::Marks.reload!
    eq "and so does a mark", PokeAccess::Marks.get(1, 8, 8), "aqui me quede"

    PokeAccess::MapNames.set(77, "Ruta\tlarga")
    PokeAccess::MapNames.reload!
    eq "and a renamed map", PokeAccess::MapNames.get(77), "Ruta larga"
  ensure
    PokeAccess::Tags.delete(1, 40)
    PokeAccess::Marks.delete(1, 8, 8)
    PokeAccess::MapNames.delete(77)
  end
end
