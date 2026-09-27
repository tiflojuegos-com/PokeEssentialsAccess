# Verbosity: each reading is said at a level (brief, medium, full), set by a built-in scheme or per reading by the
# player's own; a part is kept from its level up, and full says everything.

# Deletes the scheme files and reloads the store empty.
def verbosity_schemes_wipe
  m = PokeAccess::VerbositySchemes
  [m::FILE, m::IMPORT, m::EXPORT].each { |f| (File.delete(f) rescue nil) }
  m.reload!
end

Suite.define("verbosity: a part is kept from its level up, and full keeps everything") do
  vb = PokeAccess::Verbosity
  parts = [["Pikachu", :brief], ["nivel 5", :medium], ["macho", :full], "lleva objeto", [nil, :brief], ["", :brief]]
  PokeAccess::Config.verbosity = :full
  eq "full is every part, a bare string counting as a full one, and blank ones left out",
     vb.line(:party, parts), "Pikachu, nivel 5, macho, lleva objeto"
  PokeAccess::Config.verbosity = :medium
  eq "medium drops what only full says", vb.line(:party, parts), "Pikachu, nivel 5"
  PokeAccess::Config.verbosity = :brief
  eq "brief keeps the essentials", vb.line(:party, parts), "Pikachu"
  eq "with the separator the builder asks for", vb.line(:party, [["A", :brief], ["B", :brief]], ". "), "A. B"
  PokeAccess::Config.verbosity = nil
  eq "no setting at all is full", vb.active, :full
end

Suite.define("verbosity: positions and key hints are said from medium") do
  vb = PokeAccess::Verbosity
  t = PokeAccess::I18n
  PokeAccess::Config.verbosity = :medium
  eq "a list row keeps its position", vb.list_entry("Pidgey", 3, 8), t.t(:list_entry, :name => "Pidgey", :n => 3, :tot => 8)
  eq "a bare position too", vb.position(3, 8), t.t(:list_pos, :i => 3, :n => 8)
  truthy "and the hints are said", vb.hints?
  PokeAccess::Config.verbosity = :brief
  eq "brief says the name alone", vb.list_entry("Pidgey", 3, 8), "Pidgey"
  eq "and no position", vb.position(3, 8), nil
  falsy "nor hints", vb.hints?
end

Suite.define("verbosity: the player's scheme sets each reading apart, and a gap in it is full") do
  vb = PokeAccess::Verbosity
  store = PokeAccess::VerbositySchemes
  verbosity_schemes_wipe
  begin
    store.set("Rapido", { :party => :brief, :battle_move => :medium })
    PokeAccess::Config.verbosity = :Rapido
    eq "each reading at its own level", [vb.level(:party), vb.level(:battle_move)], [:brief, :medium]
    eq "a reading the scheme does not name is said in full", vb.level(:bag_item), :full
    PokeAccess::Config.verbosity = :Borrado
    eq "and a scheme that no longer exists says everything", vb.level(:party), :full
  ensure
    verbosity_schemes_wipe
  end
end

Suite.define("verbosity: the rotation goes through the three levels and then the player's schemes") do
  vb = PokeAccess::Verbosity
  store = PokeAccess::VerbositySchemes
  t = PokeAccess::I18n
  verbosity_schemes_wipe
  begin
    store.set("Zeta", { :party => :brief })
    store.set("Alfa", { :party => :medium })
    eq "the built-in ones first, then the player's by name", vb.rotation, [:brief, :medium, :full, :Alfa, :Zeta]
    PokeAccess::Config.verbosity = :full
    SpeakCapture.clear
    vb.rotate_scheme
    eq "the key moves to the next one", PokeAccess::Config.verbosity, :Alfa
    eq "and says it by the name the player gave it", SpeakCapture.last, t.t(:vb_now, :name => "Alfa")
    vb.rotate_scheme
    vb.rotate_scheme
    eq "past the last it wraps to brief, said by its own name", [PokeAccess::Config.verbosity, SpeakCapture.last],
       [:brief, t.t(:vb_now, :name => t.t(:vb_level_brief))]
    eq "and back from brief is the last scheme", vb.next_scheme(-1), :Zeta
    eq "the rotation key ships unassigned", PokeAccess::Config::KEY_DEFAULTS[:verbosity], nil
    truthy "and can be remapped", PokeAccess::Remap.mod_action?(:verbosity)
  ensure
    verbosity_schemes_wipe
  end
end

Suite.define("verbosity schemes: stored one per line, named safely, shared with no game stamp") do
  store = PokeAccess::VerbositySchemes
  verbosity_schemes_wipe
  begin
    store.set("Mio", { :party => :brief, :hints => :medium })
    text = File.read(store::FILE)
    truthy "a scheme is one line of reading:level pairs", text.include?("Mio=hints:medium,party:brief")
    falsy "and the file carries no game stamp", text =~ /^# game:/
    store.reload!
    eq "and it reads back as it was written", store.levels("Mio"), { :party => :brief, :hints => :medium }

    falsy "a blank name cannot be given", store.valid_name?("  ")
    falsy "nor a built-in level's", store.valid_name?("full")
    falsy "nor the name a built-in one is said by", store.valid_name?(PokeAccess::I18n.t(:vb_level_brief))
    falsy "nor another scheme's, whatever its case", store.valid_name?("MIO")
    truthy "but a scheme keeps its own when renamed", store.valid_name?("Mio", "Mio")
    eq "a name loses what would break its line", store.clean_name("# a=b\tc"), "ab c"

    store.rename("Mio", "Tuyo")
    eq "a rename keeps the levels under the new name", [store.names, store.levels("Tuyo")[:party]], [["Tuyo"], :brief]
    store.delete("Tuyo")
    eq "and a delete forgets it", store.names, []

    File.open(store::IMPORT, "w") do |f|
      f.write("# game: otro_juego\n")
      f.write("Prestado=party:brief,battle_move:bogus\n")
      f.write("full=party:brief\n")
    end
    eq "a file from another game imports, since a scheme means the same in all", store.import_now, 1
    eq "an unknown level is dropped from the scheme", store.levels("Prestado"), { :party => :brief }
    eq "and a line named like a built-in level is ignored", store.names, ["Prestado"]
  ensure
    verbosity_schemes_wipe
  end
end

Suite.define("verbosity: a plugin or a profile declares its own readings, and a scheme's others level covers them") do
  vb = PokeAccess::Verbosity
  store = PokeAccess::VerbositySchemes
  verbosity_schemes_wipe
  before = vb.readings.dup
  begin
    eq "the core's readings come first, in the editor's order", vb.readings.first(3).map { |r| r[0] },
       [:party, :battle_move, :battle_marks]
    vb.define_reading(:spec_quest, :vb_party, :vbh_party)
    eq "a declared reading is listed after them", vb.readings.last[0], :spec_quest
    vb.define_reading(:spec_quest, :vb_bag_item, :vbh_bag_item)
    eq "declaring it again rewords it in place", [vb.readings.length, vb.reading_row(:spec_quest)[1]],
       [before.length + 1, :vb_bag_item]
    eq "and it is said by its own name", vb.reading_name(:spec_quest), PokeAccess::I18n.t(:vb_bag_item)
    store.set("Mio", { :party => :medium, vb::OTHERS => :brief })
    PokeAccess::Config.verbosity = :Mio
    eq "a reading the scheme names keeps its level", vb.level(:party), :medium
    eq "one it does not name, from any game, takes its others level", vb.level(:spec_quest), :brief
    store.set("Viejo", { :party => :medium })
    PokeAccess::Config.verbosity = :Viejo
    eq "and a scheme with no others level says it in full", vb.level(:spec_quest), :full
  ensure
    vb.readings.replace(before)
    verbosity_schemes_wipe
  end
end
