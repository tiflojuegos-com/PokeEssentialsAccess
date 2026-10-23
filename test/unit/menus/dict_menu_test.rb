# The config menu's Personalization (ConfigMenu::DICTS): the verbosity schemes, one editable list per game dictionary
# (tags, marks, map names) whose entries are said, renamed, shown and forgotten, and each store's import and export.
class DictMenuTest < PokeAccessTest
  Menu = PokeAccess::ConfigMenu
  T = PokeAccess::I18n
  # The shareable stores, whose files every test starts and ends without.
  STORES = [PokeAccess::Tags, PokeAccess::Marks, PokeAccess::MapNames, PokeAccess::VerbositySchemes]
  # The menu's own state, put back after each test.
  STATE = [:@active, :@mode, :@index, :@stack, :@armed, :@items, :@items_key, :@entry]

  test "enters verbosity, the three lists, import and export from Personalization, then back" do
    on_dicts do
      assert_equal [[:verbosity, :cat_verbosity], [:list_tags, :cat_list_tags], [:list_marks, :cat_list_marks],
                    [:list_maps, :cat_list_maps], [:dict_import, :cat_import], [:dict_export, :cat_export],
                    [:back, :back]],
                   items_of(:personal).map { |i| [i[:group] || i[:kind], i[:label]] }
    end
  end

  test "offers each store's import, the verbosity schemes' too, then all of them at once" do
    on_dicts do
      assert_equal [[[:import, :tags], :act_import], [[:import, :marks], :act_import_marks],
                    [[:import, :maps], :act_import_maps], [[:import, :schemes], :act_import_schemes],
                    [[:import, :all], :act_import_all], [:back, :back]],
                   items_of(:dict_import).map { |i| [i[:action] || i[:kind], i[:label]] }
    end
  end

  test "offers each store's export, the verbosity schemes' too, then all of them at once" do
    on_dicts do
      assert_equal [[[:export, :tags], :act_export], [[:export, :marks], :act_export_marks],
                    [[:export, :maps], :act_export_maps], [[:export, :schemes], :act_export_schemes],
                    [[:export, :all], :act_export_all], [:back, :back]],
                   items_of(:dict_export).map { |i| [i[:action] || i[:kind], i[:label]] }
    end
  end

  test "says an empty list has nothing yet, before back" do
    on_dicts do
      rows = items_of(:list_marks)
      assert_equal [[:note, :back], T.t(:list_empty)], [rows.map { |i| i[:kind] }, Menu.label_of(rows[0])]
    end
  end

  test "says the empty list's note again on confirm" do
    on_dicts do
      items_of(:list_marks)
      Menu.activate(1)
      assert_equal [T.t(:list_empty)], SpeakCapture.lines
    end
  end

  test "lists a store that fails to read as empty" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      replacing(PokeAccess::Marks, :each_mark, lambda { raise "unreadable" }) do
        assert_equal [:note, :back], items_of(:list_marks).map { |i| i[:kind] }
      end
    end
  end

  test "lists a store's entries in its own order, each keyed to find it again, then back" do
    on_dicts do
      PokeAccess::Marks.set(2, 1, 1, "Cueva")
      PokeAccess::Marks.set(1, 4, 4, "Salida")
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      assert_equal [[:entry, :marks, [1, 2, 3]], [:entry, :marks, [1, 4, 4]], [:entry, :marks, [2, 1, 1]],
                    [:back, nil, nil]], items_of(:list_marks).map { |i| [i[:kind], i[:dict], i[:key]] }
    end
  end

  test "says a mark with its map, name and tile" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      assert_equal T.t(:entry_mark, :map => "Mapa 1", :name => "Tienda", :x => 2, :y => 3), said_entry(:list_marks)
    end
  end

  test "says a tag with its map and name, a hidden one as hidden" do
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      plain = said_entry(:list_tags)
      PokeAccess::Tags.set_hidden(1, 7, true)
      tag = T.t(:entry_tag, :map => "Mapa 1", :name => "Roca grande")
      assert_equal [tag, "#{tag}, #{T.t(:entry_hidden)}"], [plain, said_entry(:list_tags)]
    end
  end

  test "says a tag the player never named as an object" do
    on_dicts do
      PokeAccess::Tags.set_hidden(1, 7, true)
      assert_equal "#{T.t(:entry_tag, :map => 'Mapa 1', :name => T.t(:loc_object))}, #{T.t(:entry_hidden)}",
                   said_entry(:list_tags)
    end
  end

  test "says a map rename with its name and id" do
    on_dicts do
      PokeAccess::MapNames.set(4, "Cueva del eco")
      assert_equal T.t(:entry_map, :name => "Cueva del eco", :id => 4), said_entry(:list_maps)
    end
  end

  test "says an entry on a map the game has no name for, or a blank one, as on map ?" do
    on_dicts do
      with_map_named(40, "") do
        PokeAccess::Marks.set(77, 2, 3, "Tienda")
        PokeAccess::Marks.set(40, 5, 6, "Cueva")
        assert_equal [T.t(:entry_mark, :map => "?", :name => "Cueva", :x => 5, :y => 6),
                      T.t(:entry_mark, :map => "?", :name => "Tienda", :x => 2, :y => 3)],
                     items_of(:list_marks)[0, 2].map { |i| Menu.label_of(i) }
      end
    end
  end

  test "offers a mark to rename or forget, nothing else" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      assert_equal [:rename, :forget, :back], actions_of(items_of(:list_marks)[0])
    end
  end

  test "offers a hidden tag to show again before renaming or forgetting it, a visible one only those two" do
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      visible = actions_of(items_of(:list_tags)[0])
      PokeAccess::Tags.set_hidden(1, 7, true)
      assert_equal [[:rename, :forget, :back], [:show, :rename, :forget, :back]],
                   [visible, actions_of(items_of(:list_tags)[0])]
    end
  end

  test "offers only back with no entry focused" do
    on_dicts do
      assert_equal [:back], actions_of(nil)
    end
  end

  test "the info key says what each row of Personalization, of its import and export and of an entry's screen does" do
    helps = [[:cat_verbosity_help, :cat_list_tags_help, :cat_list_marks_help, :cat_list_maps_help, :cat_import_help,
              :cat_export_help],
             [:act_import_help, :act_import_marks_help, :act_import_maps_help, :act_import_schemes_help,
              :act_import_all_help],
             [:act_export_help, :act_export_marks_help, :act_export_maps_help, :act_export_schemes_help,
              :act_export_all_help],
             [:entry_show_help, :tag_rename_help, :entry_forget_help]]
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      PokeAccess::Tags.set_hidden(1, 7, true)
      said = [:personal, :dict_import, :dict_export].map { |mode| items_of(mode); helps_here }
      items_of(:list_tags)
      Menu.instance_variable_set(:@index, 0)
      Menu.activate(1)
      said.push(helps_here)
      assert_equal helps.map { |keys| keys.map { |k| T.t(k) } }, said
    end
  end

  test "forgets a mark, saying so, then queues the list's row, the other mark" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      PokeAccess::Marks.set(1, 4, 4, "Salida")
      run_on_entry(:list_marks, :forget)
      gone = T.t(:entry_mark, :map => "Mapa 1", :name => "Tienda", :x => 2, :y => 3)
      left = T.t(:entry_mark, :map => "Mapa 1", :name => "Salida", :x => 4, :y => 4)
      assert_equal [[T.t(:entry_forgotten, :name => gone), true], [left, false]], SpeakCapture.log
      assert_nil PokeAccess::Marks.get(1, 2, 3), "the mark is gone from its store"
    end
  end

  test "forgets a tag and a map rename from their stores" do
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      PokeAccess::MapNames.set(4, "Cueva del eco")
      run_on_entry(:list_tags, :forget)
      run_on_entry(:list_maps, :forget)
      assert_equal [nil, nil], [PokeAccess::Tags.rec(1, 7), PokeAccess::MapNames.get(4)]
    end
  end

  test "shows a hidden object again, saying so by its name, then queues its list row without the mark" do
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      PokeAccess::Tags.set_hidden(1, 7, true)
      run_on_entry(:list_tags, :show)
      tag = T.t(:entry_tag, :map => "Mapa 1", :name => "Roca grande")
      confirm, row = SpeakCapture.log
      assert_equal 2, SpeakCapture.log.length, "the confirmation, then the list row"
      assert_equal [true, true], [confirm[0].start_with?(T.t(:unhidden, :name => tag)), confirm[1]],
                   "the confirmation names the object, cutting in"
      assert_equal [tag, false], row, "the row is queued without the hidden mark"
      assert_equal false, PokeAccess::Tags.hidden?(1, 7), "the object is hidden no more"
    end
  end

  test "drops an object it shows again that keeps nothing else, leaving the list empty" do
    on_dicts do
      PokeAccess::Tags.set_hidden(1, 7, true)
      run_on_entry(:list_tags, :show)
      assert_equal [[T.t(:list_empty), false], nil], [SpeakCapture.log.last, PokeAccess::Tags.rec(1, 7)]
    end
  end

  test "says the object it shows again without the hidden mark" do
    on_dicts do
      PokeAccess::Tags.set(1, 7, "Roca grande")
      PokeAccess::Tags.set_hidden(1, 7, true)
      run_on_entry(:list_tags, :show)
      assert_equal [T.t(:unhidden, :name => T.t(:entry_tag, :map => "Mapa 1", :name => "Roca grande")), true],
                   SpeakCapture.log.first
    end
  end

  test "renames each kind of entry through the game's text entry, keeping its key" do
    {
      :list_marks => [lambda { PokeAccess::Marks.set(1, 2, 3, "Tienda") }, lambda { PokeAccess::Marks.get(1, 2, 3) }],
      :list_tags  => [lambda { PokeAccess::Tags.set(1, 7, "Roca") }, lambda { PokeAccess::Tags.get(1, 7) }],
      :list_maps  => [lambda { PokeAccess::MapNames.set(4, "Cueva") }, lambda { PokeAccess::MapNames.get(4) }]
    }.each do |list, (make, name)|
      on_dicts do
        make.call
        GameFunctions.with(:pbEnterText => lambda { |*_args| "Nuevo" }) { run_on_entry(list, :rename) }
        assert_equal "Nuevo", name.call, list.to_s
      end
    end
  end

  test "asks each kind of entry's new name with its own prompt, holding the old name" do
    {
      :list_marks => [lambda { PokeAccess::Marks.set(1, 2, 3, "Tienda") }, :mark_prompt, "Tienda"],
      :list_tags  => [lambda { PokeAccess::Tags.set(1, 7, "Roca") }, :loc_label_prompt, "Roca"],
      :list_maps  => [lambda { PokeAccess::MapNames.set(4, "Cueva") }, :map_label_prompt, "Cueva"]
    }.each do |list, (make, prompt, old)|
      on_dicts do
        make.call
        asked = []
        GameFunctions.with(:pbEnterText => lambda { |*args| asked.push(args); nil }) { run_on_entry(list, :rename) }
        assert_equal [[T.t(prompt), 0, 40, old]], asked, list.to_s
      end
    end
  end

  test "a blank name for Rename, which is what Escape gives, keeps each kind of entry and says nothing changed" do
    {
      :list_marks => [lambda { PokeAccess::Marks.set(1, 2, 3, "Tienda") }, lambda { PokeAccess::Marks.get(1, 2, 3) }, "Tienda"],
      :list_tags  => [lambda { PokeAccess::Tags.set(1, 7, "Roca") }, lambda { PokeAccess::Tags.get(1, 7) }, "Roca"],
      :list_maps  => [lambda { PokeAccess::MapNames.set(4, "Cueva") }, lambda { PokeAccess::MapNames.get(4) }, "Cueva"]
    }.each do |list, (make, name, old)|
      on_dicts do
        make.call
        GameFunctions.with(:pbEnterText => lambda { |*_args| "" }) { run_on_entry(list, :rename) }
        assert_equal [old, [T.t(:cancelled), true]], [name.call, SpeakCapture.log[1]], list.to_s
      end
    end
  end

  test "says what a mark it renames was and that it saved, then queues the list's row" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      GameFunctions.with(:pbEnterText => lambda { |*_args| "Puerta" }) { run_on_entry(:list_marks, :rename) }
      assert_equal [[T.t(:mark_edit_for, :name => "Tienda"), true], [T.t(:mark_saved, :label => "Puerta"), true],
                    [T.t(:entry_mark, :map => "Mapa 1", :name => "Puerta", :x => 2, :y => 3), false]],
                   SpeakCapture.log
    end
  end

  test "refuses an import stamped with another game, naming neither game, and takes nothing of it" do
    on_dicts do
      mine = PokeAccess::Game.profile_name
      PokeAccess::Marks.get(1, 1, 1)
      write_import(PokeAccess::Marks, "1:9,9=Ajena", "#{mine}_otro")
      transfer(:import, :marks)
      assert_equal [T.t(:act_import_foreign, :file => "marks_import.txt")], SpeakCapture.lines
      refute_includes SpeakCapture.lines.join, mine, "a profile id is not a name to say"
      assert_nil PokeAccess::Marks.get(1, 9, 9), "nothing of it arrived"
    end
  end

  test "refuses an import of a game without a profile naming neither title either" do
    on_dicts do
      replacing(PokeAccess::Game, :game_title, lambda { "Pokemon Myth" }) do
        PokeAccess::Marks.get(1, 1, 1)
        write_import(PokeAccess::Marks, "1:9,9=Ajena", "generic:Pokemon Otro")
        transfer(:import, :marks)
      end
      assert_equal [T.t(:act_import_foreign, :file => "marks_import.txt")], SpeakCapture.lines
      refute_includes SpeakCapture.lines.join, "Pokemon"
    end
  end

  test "says an import file that is not there, by its name" do
    on_dicts do
      transfer(:import, :maps)
      assert_equal [T.t(:act_import_none, :file => "map_names_import.txt")], SpeakCapture.lines
    end
  end

  test "imports a ready file's new entries into a store in use, saying how many" do
    on_dicts do
      PokeAccess::Marks.get(1, 1, 1)
      write_import(PokeAccess::Marks, "1:9,9=Ajena")
      transfer(:import, :marks)
      assert_equal [[T.t(:act_import_marks_done, :n => 1)], "Ajena"],
                   [SpeakCapture.lines, PokeAccess::Marks.get(1, 9, 9)]
    end
  end

  test "counts the entries an import brings into a store not read yet this session" do
    on_dicts do
      write_import(PokeAccess::Marks, "1:9,9=Ajena")
      transfer(:import, :marks)
      assert_equal [T.t(:act_import_marks_done, :n => 1)], SpeakCapture.lines
    end
  end

  test "imports every store at once, one result per store in order" do
    on_dicts do
      transfer(:import, :all)
      files = ["tags_import.txt", "marks_import.txt", "map_names_import.txt", "verbosity_import.txt"]
      assert_equal [files.map { |f| T.t(:act_import_none, :file => f) }.join(". ")], SpeakCapture.lines
    end
  end

  test "exports every store at once, one result per store in order, writing those that hold entries" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      transfer(:export, :all)
      said = [T.t(:act_export_none), T.t(:act_export_marks_done, :n => 1), T.t(:act_export_maps_none),
              T.t(:act_export_schemes_none)].join(". ")
      assert_equal [said], SpeakCapture.lines
      assert_equal ["1:2,3=Tienda", false],
                   [File.readlines(PokeAccess::Marks::EXPORT).last.chomp, File.exist?(PokeAccess::Tags::EXPORT)],
                   "the marks' file holds the mark; the empty tags wrote none"
    end
  end

  test "an export that cannot write its file says so, not that there is nothing to export" do
    on_dicts do
      PokeAccess::Marks.set(1, 2, 3, "Tienda")
      Dir.mkdir(PokeAccess::Marks::EXPORT)
      begin
        transfer(:export, :marks)
      ensure
        Dir.rmdir(PokeAccess::Marks::EXPORT)
      end
      assert_equal [T.t(:act_export_failed, :file => File.basename(PokeAccess::Marks::EXPORT))], SpeakCapture.lines
    end
  end

  private

  # Runs the block with every dictionary's files deleted and its store forgotten, before and after, and the menu's
  # state put back afterwards.
  def on_dicts
    saved = STATE.map { |iv| Menu.instance_variable_get(iv) }
    wipe
    Menu.instance_variable_set(:@stack, [])
    Menu.instance_variable_set(:@index, 0)
    yield
  ensure
    wipe
    STATE.each_with_index { |iv, i| Menu.instance_variable_set(iv, saved[i]) }
  end

  # Deletes each store's file, import (merged or not) and export, and forgets the loaded store.
  def wipe
    STORES.each do |m|
      [m::FILE, m::IMPORT, m::EXPORT, m.imported_path].each { |f| File.delete(f) if File.exist?(f) }
      m.reload!
    end
  end

  # The rows of screen mode, the menu left on it.
  def items_of(mode)
    Menu.instance_variable_set(:@mode, mode)
    Menu.items
  end

  # The first entry of a list as the list says it.
  def said_entry(list)
    Menu.label_of(items_of(list)[0])
  end

  # What the info key says over each row but back of the screen the menu is on, one line per row.
  def helps_here
    Menu.items.each_index.reject { |i| Menu.items[i][:kind] == :back }.map do |i|
      SpeakCapture.clear
      Menu.instance_variable_set(:@index, i)
      Menu.speak_help
      SpeakCapture.lines.join(" ")
    end
  end

  # The actions offered on an entry, by operation, then back.
  def actions_of(entry)
    Menu.entry_action_rows(entry).map { |i| i[:op] || i[:kind] }
  end

  # Opens the first entry of a list from its row and runs the action op on it from the entry's own screen, the log
  # cleared just before the action.
  def run_on_entry(list, op)
    items_of(list)
    Menu.instance_variable_set(:@index, 0)
    Menu.activate(1)
    Menu.instance_variable_set(:@index, Menu.items.index { |i| i[:op] == op })
    SpeakCapture.clear
    Menu.activate(1)
  end

  # Runs the block with the game's map table naming map id as name, the table the locator kept put back afterwards.
  def with_map_named(id, name)
    loc = PokeAccess::Locator
    saved = loc.instance_variable_get(:@mapinfos)
    loc.instance_variable_set(:@mapinfos, (saved || loc.load_mapinfos).merge(id => TestMapInfo.new(id, name)))
    yield
  ensure
    loc.instance_variable_set(:@mapinfos, saved)
  end

  # Runs the block with obj's singleton method name answering by body, the method it had put back afterwards.
  def replacing(obj, name, body)
    was = obj.method(name)
    obj.define_singleton_method(name, &body)
    yield
  ensure
    obj.define_singleton_method(name, was)
  end

  # Writes a store's import file holding the line given, stamped with the game named (this one by default).
  def write_import(store, line, game = PokeAccess::Game.profile_name)
    File.open(store::IMPORT, "w") { |f| f.write("# game: #{game}\n#{line}\n") }
  end

  # Runs an import or export of which (a store, or :all) from its row in the transfer screen.
  def transfer(op, which)
    items = items_of(op == :import ? :dict_import : :dict_export)
    Menu.instance_variable_set(:@index, items.index { |i| i[:action] == [op, which] })
    SpeakCapture.clear
    Menu.activate(1)
  end
end
