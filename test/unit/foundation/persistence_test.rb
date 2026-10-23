# The player's dictionaries (Tags, Marks, MapNames): what each keeps, how its file is read and written, the import,
# export, stamp and revision they share; the key=value parser under them (KVFile); and the settings.ini beside them.
class PersistenceTest < PokeAccessTest
  Tags = PokeAccess::Tags
  Marks = PokeAccess::Marks
  MapNames = PokeAccess::MapNames
  Settings = PokeAccess::Settings
  STORES = [Tags, Marks, MapNames].freeze
  PROBE = File.join(PokeAccess::Paths::DATA, "kv_probe.txt")

  def setup
    super
    wipe
  end

  def teardown
    wipe
    super
  end

  test "keeps a tag's name, category and hidden flag across a reload" do
    Tags.set(3, 7, "Puerta norte")
    Tags.set_category(3, 7, :exits)
    Tags.set_hidden(5, 2, true)
    Tags.reload!
    assert_equal ["Puerta norte", :exits, false], [Tags.get(3, 7), Tags.category(3, 7), Tags.hidden?(3, 7)], "named"
    assert_equal [nil, nil, true], [Tags.get(5, 2), Tags.category(5, 2), Tags.hidden?(5, 2)], "hidden"
  end

  test "writes a tag per line, its category and hidden flag as tab tokens, by map and event" do
    Tags.set(9, 1, "Cartel")
    Tags.set_category(9, 1, :signs)
    Tags.set_hidden(9, 1, true)
    Tags.set(3, 7, "Puerta")
    Tags.set_hidden(3, 2, true)
    assert_equal ["3:2=\thide", "3:7=Puerta", "9:1=Cartel\tcat=signs\thide"], data_lines(Tags::FILE)
  end

  test "reads a tag's name and its optional cat and hide tokens, skipping a line it cannot place" do
    write(Tags::FILE, "# comentario\n4:5=Nombre\tcat=people\thide\n4:6=\thide\n4:7=\nsin dos puntos=x\n" \
                      "4:8=  Con espacios  \t cat=objects \n4:9=Otro\tfoo\tcat=\n")
    Tags.reload!
    assert_equal [[4, 5, { "name" => "Nombre", "cat" => "people", "hidden" => true }], [4, 6, { "hidden" => true }],
                  [4, 8, { "name" => "Con espacios", "cat" => "objects" }], [4, 9, { "name" => "Otro" }]], records
  end

  test "clears only the name of a tag set to an empty one, keeping its category and hidden flag" do
    Tags.set(3, 7, "Puerta")
    Tags.set_category(3, 7, :exits)
    Tags.set_hidden(3, 7, true)
    Tags.set(3, 7, "")
    assert_equal [nil, :exits, true], [Tags.get(3, 7), Tags.category(3, 7), Tags.hidden?(3, 7)]
  end

  test "drops a tag left with no name, category or hidden flag" do
    Tags.set(3, 7, "Puerta")
    Tags.set_category(3, 7, :exits)
    Tags.set_hidden(5, 2, true)
    Tags.set(3, 7, "")
    Tags.set_category(3, 7, nil)
    Tags.set_hidden(5, 2, false)
    assert_nil Tags.rec(3, 7), "the one emptied of its name and category"
    assert_nil Tags.rec(5, 2), "the one shown again"
    assert_equal [], data_lines(Tags::FILE), "and the file holds neither"
  end

  test "walks every tag by map, then by event" do
    Tags.set(9, 1, "Cartel")
    Tags.set(3, 7, "Puerta")
    Tags.set_hidden(3, 2, true)
    assert_equal [[3, 2, { "hidden" => true }], [3, 7, { "name" => "Puerta" }], [9, 1, { "name" => "Cartel" }]], records
  end

  test "forgets a deleted tag whole, in the store and in its file, keeping the map's others" do
    Tags.set(5, 2, "Pisada")
    Tags.set_hidden(5, 2, true)
    Tags.set(5, 3, "Otra")
    Tags.delete(5, 2)
    assert_nil Tags.rec(5, 2), "gone from the store"
    Tags.reload!
    assert_equal [[5, 3, { "name" => "Otra" }]], records, "and from the file, the other kept"
  end

  test "ignores the deletion of a tag that is not there" do
    Tags.set(3, 7, "Puerta")
    Tags.delete(3, 8)
    Tags.delete(4, 1)
    assert_equal [[3, 7, { "name" => "Puerta" }]], records
  end

  test "keeps a mark across a reload, keyed by its tile" do
    Marks.set(87, 15, 17, "Losa del medio")
    Marks.reload!
    assert_equal "Losa del medio", Marks.get(87, 15, 17)
    assert_nil Marks.get(87, 15, 18), "another tile of the map"
    assert_nil Marks.get(88, 15, 17), "the same tile of another map"
  end

  test "lists a map's marks row by row, left to right" do
    Marks.set(87, 9, 17, "Losa del medio")
    Marks.set(87, 15, 17, "Rejilla")
    Marks.set(87, 4, 17, "Palanca")
    Marks.set(87, 10, 3, "Arriba del todo")
    Marks.set(119, 13, 11, "Rejilla")
    assert_equal [[10, 3, "Arriba del todo"], [4, 17, "Palanca"], [9, 17, "Losa del medio"], [15, 17, "Rejilla"]],
                 Marks.on_map(87)
    assert_equal [], Marks.on_map(88), "a map with none"
  end

  test "says whether a map holds marks" do
    Marks.set(87, 4, 17, "Palanca")
    assert_equal [true, false], [Marks.any_on?(87), Marks.any_on?(88)]
    Marks.delete(87, 4, 17)
    assert_equal false, Marks.any_on?(87), "once its last mark is deleted"
  end

  test "removes a mark named blank" do
    Marks.set(87, 4, 17, "Palanca")
    Marks.set(87, 4, 17, "   ")
    assert_nil Marks.get(87, 4, 17)
    assert_equal 0, Marks.count
  end

  test "forgets a deleted mark, in the store and in its file" do
    Marks.set(119, 13, 11, "Rejilla")
    Marks.set(119, 2, 2, "Puerta")
    Marks.delete(119, 13, 11)
    Marks.reload!
    assert_equal [[2, 2, "Puerta"]], Marks.on_map(119)
  end

  test "ignores the deletion of a mark that is not there" do
    Marks.set(87, 4, 17, "Palanca")
    Marks.delete(87, 5, 17)
    Marks.delete(88, 4, 17)
    assert_equal [[87, 4, 17, "Palanca"]], marks
  end

  test "walks every mark by map, then in reading order" do
    Marks.set(119, 13, 11, "Rejilla")
    Marks.set(87, 10, 3, "Arriba")
    Marks.set(87, 1, 3, "Izquierda")
    Marks.set(87, 4, 17, "Palanca")
    assert_equal [[87, 1, 3, "Izquierda"], [87, 10, 3, "Arriba"], [87, 4, 17, "Palanca"], [119, 13, 11, "Rejilla"]],
                 marks
  end

  test "writes a mark per line as its map, tile and name, in reading order" do
    Marks.set(87, 5, 3, "Centro")
    Marks.set(87, 10, 3, "Arriba")
    Marks.set(87, 1, 3, "Izquierda")
    Marks.set(87, 4, 17, "Palanca")
    assert_equal ["87:1,3=Izquierda", "87:5,3=Centro", "87:10,3=Arriba", "87:4,17=Palanca"], data_lines(Marks::FILE)
  end

  test "reads a mark's line, skipping a malformed key or an empty name" do
    write(Marks::FILE, "87:15,17=Losa\n87:1,1=\n87;2,2=Mal\n87:3=Sin fila\nx:1,1=Letra\n")
    Marks.reload!
    assert_equal [[87, 15, 17, "Losa"]], marks
  end

  test "keeps a renamed map across a reload" do
    MapNames.set(12, "Bosque renombrado")
    MapNames.reload!
    assert_equal "Bosque renombrado", MapNames.get(12)
    assert_nil MapNames.get(13), "a map never renamed"
  end

  test "clears a map's name renamed blank or deleted, in the store and in its file" do
    { "renamed blank" => lambda { |mid| MapNames.set(mid, "  ") },
      "deleted" => lambda { |mid| MapNames.delete(mid) } }.each do |how, clear|
      MapNames.set(12, "Bosque")
      clear.call(12)
      assert_nil MapNames.get(12), how
      MapNames.reload!
      assert_nil MapNames.get(12), "#{how}, after a reload"
      assert_equal [], data_lines(MapNames::FILE), "#{how}: the file"
    end
  end

  test "walks the renamed maps by map id" do
    MapNames.set(40, "Cueva")
    MapNames.set(12, "Bosque")
    assert_equal [[12, "Bosque"], [40, "Cueva"]], map_names
  end

  test "reads a map name's line, skipping map 0, a negative map and an empty name" do
    write(MapNames::FILE, "12=Bosque\n0=nunca\n-3=tampoco\n1=Pueblo\n40=\nabc=letras\n")
    MapNames.reload!
    assert_equal [[1, "Pueblo"], [12, "Bosque"]], map_names
  end

  test "saves a name with a tab or a line break in it on one line, the breaks turned to spaces" do
    Tags.set(1, 40, "Casa\tdel\nprofesor")
    Marks.set(1, 8, 8, "aqui\tme\rquede")
    MapNames.set(77, "Ruta\tlarga")
    STORES.each(&:reload!)
    assert_equal ["Casa del profesor", "aqui me quede", "Ruta larga"],
                 [Tags.get(1, 40), Marks.get(1, 8, 8), MapNames.get(77)]
  end

  test "imports only the entries each store lacks, never overwriting one" do
    Tags.set_hidden(5, 2, true)
    Marks.set(87, 15, 17, "Losa del medio")
    MapNames.set(12, "Bosque renombrado")
    write(Tags::IMPORT, "5:2=Pisada\n9:1=Cartel oeste\tcat=signs\n")
    write(Marks::IMPORT, "87:15,17=Otro nombre\n87:1,1=Entrada\n")
    write(MapNames::IMPORT, "12=Bosque ajeno\n40=Cueva del eco\n")
    assert_equal [1, 1, 1], STORES.map(&:import_now), "one entry added to each"
    assert_equal [[5, 2, { "hidden" => true }], [9, 1, { "name" => "Cartel oeste", "cat" => "signs" }]], records
    assert_equal [[87, 1, 1, "Entrada"], [87, 15, 17, "Losa del medio"]], marks
    assert_equal [[12, "Bosque renombrado"], [40, "Cueva del eco"]], map_names
  end

  test "exports each store to its export file and answers how many entries it holds" do
    Tags.set(3, 7, "Puerta")
    Tags.set_hidden(5, 2, true)
    Marks.set(87, 1, 1, "Entrada")
    MapNames.set(40, "Cueva")
    MapNames.set(12, "Bosque")
    MapNames.set(7, "Pueblo")
    { Tags => ["3:7=Puerta", "5:2=\thide"], Marks => ["87:1,1=Entrada"],
      MapNames => ["7=Pueblo", "12=Bosque", "40=Cueva"] }.each do |store, lines|
      assert_equal lines.length, store.export, "#{store}: the count"
      assert_equal File.read(store::FILE), File.read(store::EXPORT), "#{store}: the export is the store's file"
      assert_equal lines, data_lines(store::EXPORT), "#{store}: its lines"
    end
  end

  test "exports nothing and answers nil for an empty store" do
    STORES.each do |store|
      assert_nil store.export, store.to_s
      assert_equal false, File.exist?(store::EXPORT), "#{store}: no export file"
    end
  end

  test "answers nil for an export it cannot write" do
    Tags.set(3, 7, "Puerta")
    Dir.mkdir(Tags::EXPORT)
    assert_nil Tags.export
  ensure
    Dir.rmdir(Tags::EXPORT) if File.directory?(Tags::EXPORT)
  end

  test "keeps a change for the session when its file cannot be written" do
    Dir.mkdir(Marks::FILE)
    Marks.set(1, 2, 3, "Tienda")
    assert_equal "Tienda", Marks.get(1, 2, 3)
  ensure
    Dir.rmdir(Marks::FILE) if File.directory?(Marks::FILE)
  end

  test "stamps every dictionary file with its game under the store's header" do
    mine = PokeAccess::Game.profile_name
    Tags.set(3, 7, "Puerta")
    Marks.set(1, 2, 3, "Tienda")
    MapNames.set(5, "Pueblo")
    STORES.each do |store|
      want = store.header.map { |line| "# #{line}" } + ["# game: #{mine}"]
      assert_equal want, File.readlines(store::FILE).map(&:chomp).first(want.length), store.to_s
    end
  end

  test "reports an import stamped by another game as foreign, by its name, and refuses it" do
    mine = PokeAccess::Game.profile_name
    write(Marks::IMPORT, "# PokeAccess: marcadores\n# game: #{mine}_otro\n1:9,9=Ajena\n")
    assert_equal [:foreign, "#{mine}_otro"], Marks.import_status
    assert_equal 0, Marks.import_now, "import_now adds nothing"
    Marks.reload!
    assert_nil Marks.get(1, 9, 9), "and neither does the merge on load"
    assert_equal true, File.exist?(Marks::IMPORT), "the refused file stays where the player put it"
  end

  test "takes an unstamped import, from before stamps existed, for ready with its game unknown" do
    Marks.count
    write(Marks::IMPORT, "1:9,9=Antigua\n")
    assert_equal [:ready, nil], Marks.import_status
    assert_equal 1, Marks.import_now, "and merges it"
  end

  test "counts what an import adds when the store was not read yet" do
    write(Marks::IMPORT, "1:9,9=Antigua\n")
    assert_equal 1, Marks.import_now, "the entry it added"
    assert_equal "Antigua", Marks.get(1, 9, 9)
    assert_equal "1:9,9=Antigua\n", File.read(Marks.imported_path), "and the import is set aside"
  end

  test "has nothing to import without an import file" do
    assert_equal [:none], Marks.import_status
    assert_equal 0, Marks.import_now
  end

  test "sets a merged import file aside as .imported, replacing an earlier one" do
    Marks.count
    write(Marks::IMPORT, "1:9,9=Primera\n")
    Marks.import_now
    assert_equal "1:9,9=Primera\n", File.read(Marks.imported_path), "the first is set aside"
    write(Marks::IMPORT, "1:8,8=Segunda\n")
    Marks.import_now
    assert_equal false, File.exist?(Marks::IMPORT), "the import file is gone"
    assert_equal "1:8,8=Segunda\n", File.read(Marks.imported_path), "and the latest one replaces the first"
  end

  test "merges a ready import on first use, saving the store, and sets the file aside" do
    write(Marks::IMPORT, "1:9,9=Antigua\n")
    assert_equal "Antigua", Marks.get(1, 9, 9), "the import is in the store"
    assert_equal ["1:9,9=Antigua"], data_lines(Marks::FILE), "and in its file"
    assert_equal false, File.exist?(Marks::IMPORT), "and the import is set aside"
  end

  test "leaves the store's file as it was when an import merged on first use adds nothing" do
    write(Marks::FILE, "1:9,9=Antigua\n")
    write(Marks::IMPORT, "1:9,9=Otra\n")
    assert_equal "Antigua", Marks.get(1, 9, 9), "the store's own entry wins"
    assert_equal "1:9,9=Antigua\n", File.read(Marks::FILE), "its file is not rewritten"
    assert_equal false, File.exist?(Marks::IMPORT), "and the import is set aside"
  end

  test "leaves the store's file as it was when the menu's import adds nothing" do
    write(Marks::FILE, "1:9,9=Antigua\n")
    Marks.count
    write(Marks::IMPORT, "1:9,9=Otra\n")
    assert_equal 0, Marks.import_now, "the store's own entry wins"
    assert_equal "1:9,9=Antigua\n", File.read(Marks::FILE), "its file is not rewritten"
  end

  test "saves what an import adds, which survives a reload" do
    Marks.count
    write(Marks::IMPORT, "1:9,9=Antigua\n")
    Marks.import_now
    Marks.reload!
    assert_equal "Antigua", Marks.get(1, 9, 9)
  end

  test "bumps a store's revision on every save and every reload" do
    start = Tags.rev
    Tags.set(3, 7, "Puerta")
    saved = Tags.rev
    Tags.reload!
    reloaded = Tags.rev
    assert_operator saved, :>, start, "a save"
    assert_operator reloaded, :>, saved, "a reload"
  end

  test "reads past a stray byte that is not UTF-8, which becomes a question mark" do
    write(PROBE, "a=1\nb=caf\xE9\nc=3\n")
    assert_equal [["a", "1"], ["b", "caf?"], ["c", "3"]], kv_pairs(PROBE)
  end

  test "drops the byte order mark a file starts with, and only there" do
    { "\xEF\xBB\xBFa=1\nb=2\n\xEF\xBB\xBFc=3\n" => [["a", "1"], ["b", "2"], ["\uFEFFc", "3"]],
      "\xEF\xBB\xBFa=1" => [["a", "1"]] }.each do |text, want|
      write(PROBE, text)
      assert_equal want, kv_pairs(PROBE), "for #{text.inspect}"
    end
  end

  test "skips blank lines, comments, lines with no equals sign and lines with no key" do
    write(PROBE, "# comentario\n  # clave=valor\n\n   \nsin igual\n=valor\n  k  =  v  \n")
    assert_equal [["k", "v"]], kv_pairs(PROBE)
  end

  test "keeps a value's spaces when asked not to strip it" do
    write(PROBE, "k=  v  \n")
    got = []
    PokeAccess::KVFile.each(PROBE, :strip_value => false) { |k, v| got.push([k, v]) }
    assert_equal [["k", "  v  "]], got
  end

  test "skips a line its reader fails on, and reads on" do
    write(PROBE, "a=1\nb=2\nc=3\n")
    got = []
    PokeAccess::KVFile.each(PROBE) { |k, v| k == "b" ? raise("bad line") : got.push([k, v]) }
    assert_equal [["a", "1"], ["c", "3"]], got
  end

  test "reads nothing from a file that is not there" do
    assert_equal [], kv_pairs(PROBE)
  end

  test "reads nothing from a path it cannot read" do
    Dir.mkdir(PROBE)
    assert_equal [], kv_pairs(PROBE)
  ensure
    Dir.rmdir(PROBE) if File.directory?(PROBE)
  end

  test "clamps a stored number to its setting's bounds" do
    row = PokeAccess::Config.setting(:footstep_volume)
    { "250" => 100, "-5" => 0, "70" => 70 }.each do |text, want|
      assert_equal want, PokeAccess::Config.parse(row, text), "for #{text.inspect}"
    end
  end

  test "writes every setting into the ini" do
    with_settings_file do
      Settings.write
      assert_equal [], PokeAccess::Config.settings.map { |s| s.key.to_s } - Settings.read.keys
    end
  end

  test "writes a setting the ini lacks back into it, with the value the setting holds" do
    with_settings_file do
      Settings.write
      kept = File.readlines(Settings::FILE).reject { |line| line.start_with?("footstep_volume=") }
      File.open(Settings::FILE, "w") { |f| f.write(kept.join) }
      PokeAccess::Config.footstep_volume = 60
      Settings.apply
      assert_equal "60", Settings.read["footstep_volume"]
    end
  end

  private

  # Deletes every file the dictionaries and the parser probe can touch, and forgets the loaded stores.
  def wipe
    STORES.each do |store|
      [store::FILE, store::IMPORT, store::EXPORT, store.imported_path].each { |f| File.delete(f) if File.exist?(f) }
      store.reload!
    end
    File.delete(PROBE) if File.exist?(PROBE)
  end

  # Writes text to path, byte for byte.
  def write(path, text)
    File.open(path, "wb") { |f| f.write(text) }
  end

  # A file's data lines: its lines past the comments.
  def data_lines(path)
    File.readlines(path).map(&:chomp).reject { |line| line.start_with?("#") }
  end

  # Every tag as [map, event, record], as each_record walks them.
  def records
    out = []
    Tags.each_record { |mid, eid, r| out.push([mid, eid, r]) }
    out
  end

  # Every mark as [map, x, y, name], as each_mark walks them.
  def marks
    out = []
    Marks.each_mark { |mid, x, y, name| out.push([mid, x, y, name]) }
    out
  end

  # Every renamed map as [map, name], as each_name walks them.
  def map_names
    out = []
    MapNames.each_name { |mid, name| out.push([mid, name]) }
    out
  end

  # The (key, value) pairs KVFile reads from path.
  def kv_pairs(path)
    out = []
    PokeAccess::KVFile.each(path) { |k, v| out.push([k, v]) }
    out
  end

  # Runs the block and puts settings.ini back as it was (absent stays absent).
  def with_settings_file
    was = File.exist?(Settings::FILE) ? File.binread(Settings::FILE) : nil
    yield
  ensure
    if was
      File.open(Settings::FILE, "wb") { |f| f.write(was) }
    elsif File.exist?(Settings::FILE)
      File.delete(Settings::FILE)
    end
  end
end
