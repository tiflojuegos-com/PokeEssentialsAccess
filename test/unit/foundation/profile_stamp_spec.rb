# The dictionary stamp: a generic install qualifies "generic" with the game's own title, so two unprofiled games do
# not share a stamp; a declared profile is the stamp as is.
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

    file ="#{PokeAccess::Paths::DATA}/stamp_probe.txt"
    File.open(file, "w") { |f| f.write("# game: #{myth}\n1=algo\n") }
    eq "and a stamp with spaces in it survives the round trip",
       PokeAccess::Marks.file_game(file), myth
    File.delete(file) rescue nil

    g.instance_variable_set(:@profile_name, nil)
    $data_system = nil
    eq "with no title to be had, the bare stamp is still answered", g.profile_name, "generic"

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

# A common loads before the game's own modules and names its defines "<x>_common": the stamp stays the game's, from its
# own define or, when all its readers come from commons, from its install.
Suite.define("profile stamp: a common's define never signs the game") do
  g = PokeAccess::Game
  saved_profiles = g.profiles.dup
  saved_name = g.instance_variable_get(:@profile_name)
  path = "#{PokeAccess::Paths::DATA}/installed.json"
  saved_json = (File.read(path) rescue nil)
  begin
    g.profiles.clear
    g.profiles.push("infinitefusion_common")
    g.profiles.push("infinitefusion_hoenn")
    g.instance_variable_set(:@profile_name, nil)
    eq "the game's own define signs, past the common's", g.profile_name, "infinitefusion_hoenn"

    g.profiles.clear
    g.profiles.push("infinitefusion_common")
    g.instance_variable_set(:@profile_name, nil)
    File.open(path, "w") { |f| f.write('{"profile": "infinitefusion"}') }
    eq "a game with no define of its own is signed by its install", g.profile_name, "infinitefusion"
  ensure
    g.profiles.clear
    saved_profiles.each { |p| g.profiles.push(p) }
    g.instance_variable_set(:@profile_name, saved_name)
    if saved_json then File.open(path, "w") { |f| f.write(saved_json) } else (File.delete(path) rescue nil) end
  end
end

# A file with the bare "generic" stamp of installs before 0.4.6 imports into any unprofiled game; another game's
# qualified stamp is still refused.
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

# A tab or a line break in a name (the files' token and line separators) is saved as a space.
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
