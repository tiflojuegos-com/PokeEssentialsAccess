# The "labels and markers" branch of the config menu: one table (ConfigMenu::DICTS) drives an import
# submenu, an export submenu and three editable lists, one per dictionary. Pinned here is the shape a
# player navigates by ear -- the same four rows in import and export, the same three actions on every
# entry -- and the two results that matter most: a foreign file is refused with its game named, and
# forgetting an entry drops it from the list the player is standing in.

# Deletes every dictionary file and forgets the stores, before and after a suite.
def dict_menu_wipe
  [PokeAccess::Tags, PokeAccess::Marks, PokeAccess::MapNames].each do |m|
    [m::FILE, m::IMPORT, m::EXPORT].each { |f| (File.delete(f) rescue nil) }
    m.reload!
  end
end

# Runs the block with the menu's navigation state saved and restored.
def with_dict_menu
  cm = PokeAccess::ConfigMenu
  ivars = [:@mode, :@index, :@stack, :@entry]
  prev = ivars.map { |s| cm.instance_variable_get(s) }
  dict_menu_wipe
  yield cm
ensure
  dict_menu_wipe
  ivars.each_index { |i| cm.instance_variable_set(ivars[i], prev[i]) }
end

# The items of a menu mode, without moving the live cursor.
def dict_menu_items(cm, mode)
  cm.instance_variable_set(:@mode, mode)
  cm.items
end

Suite.define("dict menu: the labels branch offers import, export and one list per dictionary") do
  with_dict_menu do |cm|
    top = dict_menu_items(cm, :tags)
    eq "the branch enters import, export and the three lists, then back",
       top.map { |i| i[:group] || i[:kind] },
       [:dict_import, :dict_export, :list_tags, :list_marks, :list_maps, :back]

    imp = dict_menu_items(cm, :dict_import)
    eq "import offers each dictionary and then everything at once",
       imp.map { |i| i[:action] || i[:kind] },
       [[:import, :tags], [:import, :marks], [:import, :maps], [:import, :all], :back]
    exp = dict_menu_items(cm, :dict_export)
    eq "export is the same four rows", exp.map { |i| i[:action] || i[:kind] },
       [[:export, :tags], [:export, :marks], [:export, :maps], [:export, :all], :back]
    eq "and the two submenus are labelled by their own keys",
       [imp[3][:label], exp[3][:label]], [:act_import_all, :act_export_all]

    empty = dict_menu_items(cm, :list_marks)
    eq "an empty list says so instead of offering only back", empty.map { |i| i[:kind] }, [:note, :back]
  end
end

Suite.define("dict menu: a list names each entry by map and name, and offers the actions its kind allows") do
  with_dict_menu do |cm|
    PokeAccess::Marks.set(1, 2, 3, "Tienda")
    PokeAccess::Tags.set(1, 7, "Roca grande")
    PokeAccess::Tags.set_hidden(1, 7, true)
    PokeAccess::MapNames.set(4, "Cueva del eco")

    marks = dict_menu_items(cm, :list_marks)
    eq "a mark entry carries what the actions need", [marks[0][:kind], marks[0][:dict], marks[0][:key]],
       [:entry, :marks, [1, 2, 3]]
    eq "and is spoken with its map, name and tile", cm.label_of(marks[0]),
       PokeAccess::I18n.t(:entry_mark, :map => cm.map_label(1), :name => "Tienda", :x => 2, :y => 3)
    eq "a mark can be renamed or forgotten, nothing else",
       cm.entry_action_rows(marks[0]).map { |i| i[:op] || i[:kind] }, [:rename, :forget, :back]

    tags = dict_menu_items(cm, :list_tags)
    truthy "a hidden object says it is hidden", cm.label_of(tags[0]).include?(PokeAccess::I18n.t(:entry_hidden))
    eq "and can be shown again before renamed or forgotten",
       cm.entry_action_rows(tags[0]).map { |i| i[:op] || i[:kind] }, [:show, :rename, :forget, :back]

    maps = dict_menu_items(cm, :list_maps)
    eq "a map entry is its name and id", cm.label_of(maps[0]),
       PokeAccess::I18n.t(:entry_map, :name => "Cueva del eco", :id => 4)
  end
end

Suite.define("dict menu: forgetting an entry drops it from the list, and showing a hidden object unhides it") do
  with_dict_menu do |cm|
    PokeAccess::Marks.set(1, 2, 3, "Tienda")
    PokeAccess::Marks.set(1, 4, 4, "Salida")
    entry = dict_menu_items(cm, :list_marks)[0]
    cm.instance_variable_set(:@stack, [[:list_marks, 0]])
    cm.instance_variable_set(:@mode, :entry_actions)
    cm.instance_variable_set(:@entry, entry)
    SpeakCapture.clear
    cm.run_entry_action(:forget)
    falsy "the mark is gone from the store", PokeAccess::Marks.get(1, 2, 3)
    eq "the menu is back on the list", cm.instance_variable_get(:@mode), :list_marks
    eq "which now holds the other mark and back", cm.items.map { |i| i[:kind] }, [:entry, :back]
    eq "the deletion is spoken first and the list position queued behind it",
       SpeakCapture.log.map { |txt, int| [txt, int] },
       [[PokeAccess::I18n.t(:entry_forgotten, :name => cm.entry_label(entry)), true], [cm.describe, false]]

    PokeAccess::Tags.set_hidden(1, 7, true)
    hidden = dict_menu_items(cm, :list_tags)[0]
    cm.instance_variable_set(:@stack, [[:list_tags, 0]])
    cm.instance_variable_set(:@mode, :entry_actions)
    cm.instance_variable_set(:@entry, hidden)
    SpeakCapture.clear
    cm.run_entry_action(:show)
    falsy "show clears the hidden flag", PokeAccess::Tags.hidden?(1, 7)
    truthy "and says the object is shown", SpeakCapture.lines[0].include?(PokeAccess::I18n.t(:unhidden, :name => ""))
  end
end

Suite.define("dict menu: import refuses a foreign file by name, and export reports each dictionary") do
  with_dict_menu do |cm|
    mine = PokeAccess::Game.profile_name
    File.open(PokeAccess::Marks::IMPORT, "w") do |f|
      f.write("# game: #{mine}_otro\n")
      f.write("1:9,9=Ajena\n")
    end
    SpeakCapture.clear
    cm.run_transfer(:import, :marks)
    eq "a file from another game is refused, naming both games", SpeakCapture.lines,
       [PokeAccess::I18n.t(:act_import_foreign, :file => "marks_import.txt", :game => "#{mine}_otro", :mine => mine)]
    falsy "and nothing of it arrived", PokeAccess::Marks.get(1, 9, 9)

    SpeakCapture.clear
    cm.run_transfer(:import, :maps)
    eq "a missing file is reported as missing, by name", SpeakCapture.lines,
       [PokeAccess::I18n.t(:act_import_none, :file => "map_names_import.txt")]

    PokeAccess::Marks.set(1, 2, 3, "Tienda")
    SpeakCapture.clear
    cm.run_transfer(:export, :all)
    eq "export all speaks one result per dictionary, in order", SpeakCapture.lines,
       [[PokeAccess::I18n.t(:act_export_none),
         PokeAccess::I18n.t(:act_export_marks_done, :n => 1),
         PokeAccess::I18n.t(:act_export_maps_none)].join(". ")]
    truthy "and the marks export file exists", File.exist?(PokeAccess::Marks::EXPORT)
  end
end
