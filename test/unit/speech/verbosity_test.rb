# Verbosity: what each reading says at brief, medium or full by a built-in level or the player's own scheme (one line
# each in VerbositySchemes' file), the rotation key through the schemes, and the readings plugins and profiles declare.
class VerbosityTest < PokeAccessTest
  Vb = PokeAccess::Verbosity
  Store = PokeAccess::VerbositySchemes
  T = PokeAccess::I18n
  # A party row: a part from each level, a bare string (a full part) and two blank parts.
  PARTS = [["Pikachu", :brief], ["nivel 5", :medium], ["macho", :full], "lleva objeto", [nil, :brief], ["  ", :brief]].freeze
  WHOLE = "Pikachu, nivel 5, macho, lleva objeto"

  test "keeps each part from its level up, a bare string as a full one, and leaves blank parts out" do
    assert_equal ["Pikachu", "Pikachu, nivel 5", WHOLE], vb_levels { Vb.line(:party, PARTS) }
  end

  test "joins the parts with the separator the row asks for" do
    PokeAccess::Config.verbosity = :full
    assert_equal "Pikachu / nivel 5", Vb.line(:party, PARTS.first(2), " / ")
  end

  test "joins parts as sentences, with no second period after one that closes its own" do
    PokeAccess::Config.verbosity = :full
    assert_equal ["Pikachu. nivel 5", "Concurso. nivel 5"],
                 [PARTS.first(2), [["Concurso.", :brief], ["nivel 5", :medium]]].map { |parts| Vb.line(:party, parts, ". ") }
  end

  test "says everything with no setting at all" do
    PokeAccess::Config.verbosity = nil
    assert_equal [:full, WHOLE], [Vb.active, Vb.line(:party, PARTS)]
  end

  test "says a part with a mistyped level only in full, and logs the typo" do
    forgetting_log("verbosity_level_fulll") do
      parts = [["Pikachu", :brief], ["nivel 5", :fulll]]
      assert_equal ["Pikachu", "Pikachu", "Pikachu, nivel 5"], vb_levels { Vb.line(:party, parts) }
      assert_equal "unknown verbosity level :fulll", PokeAccess.logged["verbosity_level_fulll"]
    end
  end

  test "puts every reading at a built-in level" do
    PokeAccess::Config.verbosity = :medium
    assert_equal [:medium, :medium], [Vb.level(:party), Vb.level(:never_declared)]
  end

  test "keeps a part the reading's level reaches" do
    PokeAccess::Config.verbosity = :medium
    assert_equal [true, true, false], [:brief, :medium, :full].map { |from| Vb.keep?(:party, from) }
  end

  test "puts each reading at its own level under the player's scheme, one it does not name in full" do
    with_schemes do
      Store.set("Rapido", { :party => :brief, :battle_move => :medium })
      PokeAccess::Config.verbosity = :Rapido
      assert_equal [:Rapido, :brief, :medium, :full],
                   [Vb.active, Vb.level(:party), Vb.level(:battle_move), Vb.level(:bag_item)]
    end
  end

  test "puts a reading the player's scheme does not name at the scheme's others level" do
    with_schemes do
      Store.set("Mio", { :party => :medium, Vb::OTHERS => :brief })
      PokeAccess::Config.verbosity = :Mio
      assert_equal [:medium, :brief], [Vb.level(:party), Vb.level(:quest)]
    end
  end

  test "says everything under a scheme that no longer exists" do
    with_schemes do
      PokeAccess::Config.verbosity = :Borrado
      assert_equal [:full, :full], [Vb.active, Vb.level(:party)]
    end
  end

  test "builds a row whole as full says it, whatever the scheme, the scheme's levels back after" do
    PokeAccess::Config.verbosity = :brief
    inside = Vb.whole { [Vb.level(:party), Vb.line(:party, PARTS)] }
    assert_equal [[:full, WHOLE], :brief], [inside, Vb.level(:party)]
  end

  test "keeps a row whole after another built whole inside it" do
    PokeAccess::Config.verbosity = :brief
    assert_equal :full, Vb.whole { Vb.whole { nil }; Vb.level(:party) }
  end

  test "puts the levels back after a row built whole that fails" do
    PokeAccess::Config.verbosity = :brief
    (Vb.whole { raise "a reader fails" } rescue nil)
    assert_equal :brief, Vb.level(:party)
  end

  test "publishes a row whole to the info key and Ctrl+T, saying it at its reading's level" do
    PokeAccess::Config.verbosity = :brief
    said = Vb.info_line(:party, PARTS)
    assert_equal ["Pikachu", WHOLE, WHOLE], [said, PokeAccess::Info.info_text, PokeAccess::Info.row_text]
  end

  test "says a row whole for Ctrl+T whatever the scheme, as sentences when asked" do
    PokeAccess::Config.verbosity = :brief
    assert_equal [WHOLE, "Pikachu. nivel 5. macho. lleva objeto"], [Vb.full_line(PARTS), Vb.full_line(PARTS, ". ")]
  end

  test "says a row's position from medium" do
    entry = T.t(:list_entry, :name => "Pidgey", :n => 3, :tot => 8)
    position = T.t(:list_pos, :i => 3, :n => 8)
    assert_equal [["Pidgey", nil], [entry, position], [entry, position]],
                 vb_levels { [Vb.list_entry("Pidgey", 3, 8), Vb.position(3, 8)] }
  end

  test "says a screen's key hints from medium, after the line with the separator asked for" do
    hinted = [true, "Abrir. C: abrir", "Abrir - C: abrir"]
    assert_equal [[false, "Abrir", "Abrir"], hinted, hinted],
                 vb_levels { [Vb.hints?, Vb.with_hint("Abrir", "C: abrir"), Vb.with_hint("Abrir", "C: abrir", " - ")] }
  end

  test "says a screen's descriptions only in full" do
    assert_equal [false, false, true], vb_levels { Vb.descriptions? }
  end

  test "takes positions, hints and descriptions from their own readings under the player's scheme" do
    with_schemes do
      Store.set("Mio", { :positions => :brief, :hints => :full, :descriptions => :full, Vb::OTHERS => :brief })
      PokeAccess::Config.verbosity = :Mio
      assert_equal ["Pidgey", true, true], [Vb.list_entry("Pidgey", 3, 8), Vb.hints?, Vb.descriptions?]
    end
  end

  test "goes through the built-in levels, then the player's schemes by name" do
    with_schemes do
      two_schemes
      assert_equal [:brief, :medium, :full, :Alfa, :Zeta], Vb.rotation
    end
  end

  test "moves the rotation key to the next scheme, said by the name the player gave it as the mod's own news" do
    with_schemes do
      two_schemes
      PokeAccess::Config.verbosity = :full
      Vb.rotate_scheme
      said = T.t(:vb_now, :name => "Alfa")
      assert_equal [:Alfa, [[said, true]], [[said, :system]]], [PokeAccess::Config.verbosity, SpeakCapture.log, filed]
    end
  end

  test "wraps the rotation key past the last scheme round to brief, said by its spoken name" do
    with_schemes do
      two_schemes
      PokeAccess::Config.verbosity = :Zeta
      Vb.rotate_scheme
      assert_equal [:brief, T.t(:vb_now, :name => T.t(:vb_level_brief))], [PokeAccess::Config.verbosity, SpeakCapture.last]
    end
  end

  test "steps back from brief to the last scheme" do
    with_schemes do
      two_schemes
      PokeAccess::Config.verbosity = :brief
      assert_equal :Zeta, Vb.next_scheme(-1)
    end
  end

  test "saves the scheme the rotation key moves to" do
    with_schemes do
      two_schemes
      PokeAccess::Config.verbosity = :full
      Vb.rotate_scheme
      assert_includes File.readlines(PokeAccess::Settings::FILE).map { |line| line.chomp }, "verbosity=Alfa"
    end
  end

  test "lists the core's readings first, in the editor's order" do
    assert_equal [:party, :battle_move, :battle_marks], Vb.readings.first(3).map { |row| row[0] }
  end

  test "lists a declared reading last, under the group it names" do
    declaring do
      Vb.define_reading(:test_quest, :vb_quest, :vbh_quest, :map)
      assert_equal [[:test_quest, :vb_quest, :vbh_quest, :map], :test_quest, :test_quest],
                   [Vb.reading_row(:test_quest), Vb.readings.last[0], Vb.readings_in(:map).last[0]]
    end
  end

  test "rewords a reading declared again where it stands" do
    declaring do |count|
      Vb.define_reading(:test_quest, :vb_quest, :vbh_quest, :map)
      Vb.define_reading(:test_quest, :vb_bag_item, :vbh_bag_item, :items)
      assert_equal [count + 1, count, [:test_quest, :vb_bag_item, :vbh_bag_item, :items]],
                   [Vb.readings.length, Vb.readings.index { |row| row[0] == :test_quest }, Vb.reading_row(:test_quest)]
    end
  end

  test "files a reading declared under a group the editor lacks with this game's, and logs it" do
    declaring do
      forgetting_log("verbosity_group_test_lost") do
        Vb.define_reading(:test_lost, :vb_party, :vbh_party, :no_such_group)
        assert_equal [:game, "unknown verbosity group :no_such_group for test_lost"],
                     [Vb.reading_row(:test_lost)[3], PokeAccess.logged["verbosity_group_test_lost"]]
      end
    end
  end

  test "says a reading by its name, the others' entry by its own, and an undeclared one by its key" do
    declaring do
      Vb.define_reading(:test_quest, :vb_quest, :vbh_quest, :game)
      assert_equal [T.t(:vb_quest), T.t(:vb_others), "never_declared"],
                   [:test_quest, Vb::OTHERS, :never_declared].map { |reading| Vb.reading_name(reading) }
    end
  end

  test "finds every reading the source tree declares filed under a group the editor has" do
    texts = Dir.glob(File.join(Harness::ROOT, "{core,plugins,games}", "**", "*.rb")).sort.map { |f| File.read(f) }
    calls = texts.inject(0) { |n, text| n + text.scan(/define_reading\(/).length - text.scan(/def self\.define_reading\(/).length }
    found = texts.inject([]) { |all, text| all + declarations(text) }
    unread = Vb.readings.map { |row| row[0].to_s } - found.map { |reading, _group| reading }
    assert_equal [], unread, "the sweep reads every reading the mod declared as it loaded"
    assert_equal [calls, []], [found.length, misfiled(found)], "every declaration read, none naming a group the editor lacks"
  end

  test "its source check catches a declaration naming a group the editor lacks" do
    sample = "PokeAccess::Verbosity.define_reading(:quest, :vb_quest, :vbh_quest, :game)\n" \
             "PokeAccess::Verbosity.define_reading(:lost, :vb_lost, :vbh_lost, :nowhere)\n"
    assert_equal ["lost:nowhere"], misfiled(declarations(sample))
  end

  test "stores a scheme as one line of its readings and levels in order, with no game stamp" do
    with_schemes do
      Store.set("Mio", { :party => :brief, :hints => :medium })
      lines = File.readlines(Store::FILE).map { |line| line.chomp }
      assert_equal [["Mio=hints:medium,party:brief"], []], [lines.reject { |l| l.start_with?("#") }, lines.grep(/\A# game:/)]
    end
  end

  test "reads a scheme back from its file as it was written" do
    with_schemes do
      Store.set("Mio", { :party => :brief, :hints => :medium })
      Store.reload!
      assert_equal [["Mio"], { :party => :brief, :hints => :medium }], [Store.names, Store.levels("Mio")]
    end
  end

  test "saves a scheme under its name made fit for its line" do
    with_schemes do
      Store.set("# Mi=o\t1", { :party => :brief })
      assert_equal ["Mio 1"], Store.names
    end
  end

  test "makes a name fit one line: no breaks or tabs, no equals sign, no leading comment marks or spaces" do
    { "# a=b\tc" => "ab c", "  ##  Mio  " => "Mio", "Mi\r\nplan" => "Mi plan", "=Rapido=" => "Rapido",
      "Mi #1" => "Mi #1" }.each do |raw, want|
      assert_equal want, Store.clean_name(raw), "for #{raw.inspect}"
    end
  end

  test "refuses a blank name, a built-in level's as stored or as said, and another scheme's, case aside" do
    with_schemes do
      Store.set("Mio", { :party => :brief })
      { "  " => false, "full" => false, "Brief" => false, T.t(:vb_level_brief) => false,
        T.t(:vb_level_full).upcase => false, "MIO" => false, "Nuevo" => true, "# Nuevo" => true }.each do |name, want|
        assert_equal want, Store.valid_name?(name), "for #{name.inspect}"
      end
    end
  end

  test "lets a scheme being renamed keep its own name or change only its case" do
    with_schemes do
      Store.set("Mio", { :party => :brief })
      Store.set("Otro", { :party => :brief })
      assert_equal [true, true, false],
                   [["Mio", "Mio"], ["MIO", "Mio"], ["Otro", "Mio"]].map { |name, old| Store.valid_name?(name, old) }
    end
  end

  test "renames a scheme, its levels kept under the new name made fit, also in its file" do
    with_schemes do
      Store.set("Mio", { :party => :brief })
      Store.rename("Mio", " #Tuyo ")
      Store.reload!
      assert_equal [["Tuyo"], { :party => :brief }], [Store.names, Store.levels("Tuyo")]
    end
  end

  test "leaves the store as it was renaming a scheme that is not there" do
    with_schemes do
      Store.set("Mio", { :party => :brief })
      Store.rename("Nada", "Otro")
      assert_equal ["Mio"], Store.names
    end
  end

  test "forgets a deleted scheme, also in its file" do
    with_schemes do
      Store.set("Mio", { :party => :brief })
      Store.set("Otro", { :party => :medium })
      Store.delete("Mio")
      Store.reload!
      assert_equal ["Otro"], Store.names
    end
  end

  test "drops a line of its file named as a built-in level" do
    with_schemes do
      write_file(Store::FILE, "full=party:brief\nMio=party:brief\n")
      Store.reload!
      assert_equal ["Mio"], Store.names
    end
  end

  test "keeps a name in its file that only sounds like a built-in level, as a player of another language may give" do
    with_schemes do
      write_file(Store::FILE, "#{T.t(:vb_level_brief)}=party:medium\n")
      Store.reload!
      assert_equal [[T.t(:vb_level_brief)], { :party => :medium }], [Store.names, Store.levels(T.t(:vb_level_brief))]
    end
  end

  test "drops a pair of its file with no reading, an unknown level or a second colon, keeping the rest" do
    with_schemes do
      write_file(Store::FILE, "Mio=party:brief,hints:bogus,:medium,positions:brief:x, dex_page : medium ,\n")
      Store.reload!
      assert_equal({ :party => :brief, :dex_page => :medium }, Store.levels("Mio"))
    end
  end

  test "imports a scheme file stamped by another game, since a scheme means the same in every game" do
    with_schemes do
      added = importing("# game: otro_juego\nPrestado=party:brief\n")
      assert_equal [1, ["Prestado"], { :party => :brief }], [added, Store.names, Store.levels("Prestado")]
    end
  end

  test "leaves out of an import a scheme already there and a built-in level's name in any form" do
    with_schemes do
      Store.set("Mio", { :party => :medium })
      added = importing("Mio=party:brief\n#{T.t(:vb_level_brief)}=party:brief\nFULL=party:medium\nPrestado=party:brief\n")
      assert_equal [1, ["Mio", "Prestado"], { :party => :medium }], [added, Store.names, Store.levels("Mio")]
    end
  end

  private

  # Runs the block with no scheme stored; the scheme files, the settings file the rotation key saves to and the
  # store are put back as they were after.
  def with_schemes
    files = [Store::FILE, Store::IMPORT, Store::EXPORT, Store.imported_path, PokeAccess::Settings::FILE]
    kept = files.map { |f| File.exist?(f) ? File.binread(f) : nil }
    files.first(4).each { |f| File.delete(f) if File.exist?(f) }
    Store.reload!
    yield
  ensure
    files.each_with_index do |f, i|
      if kept[i]
        File.binwrite(f, kept[i])
      elsif File.exist?(f)
        File.delete(f)
      end
    end
    Store.reload!
  end

  # Stores two schemes, the later one first by name.
  def two_schemes
    Store.set("Zeta", { :party => :brief })
    Store.set("Alfa", { :party => :medium })
  end

  # What the menu's import adds from an import file holding text, the store read before as the menu has it.
  def importing(text)
    Store.names
    write_file(Store::IMPORT, text)
    Store.import_now
  end

  # Writes text as the whole of the file at path.
  def write_file(path, text)
    File.open(path, "w") { |f| f.write(text) }
  end

  # The lines the history holds, oldest first, as [text, category].
  def filed
    PokeAccess::History.lines_of(PokeAccess::History::ALL).map { |m| [m.text, m.category] }
  end

  # Runs the block with the declared readings put back as they were after; yields how many there were.
  def declaring
    before = Vb.readings.dup
    yield before.length
  ensure
    Vb.readings.replace(before)
  end

  # Runs the block with the log_once entry under key forgotten before and after, so the block's own logging shows.
  def forgetting_log(key)
    PokeAccess.logged.delete(key)
    yield
  ensure
    PokeAccess.logged.delete(key)
  end

  # The [reading, group] of each define_reading call in a source text whose arguments are four symbols.
  def declarations(text)
    text.scan(/define_reading\(:(\w+), :\w+, :\w+, :(\w+)\)/)
  end

  # The declarations naming a group the editor lacks, as "reading:group".
  def misfiled(found)
    found.reject { |_reading, group| Vb::GROUPS.assoc(group.to_sym) }.map { |reading, group| "#{reading}:#{group}" }
  end
end
