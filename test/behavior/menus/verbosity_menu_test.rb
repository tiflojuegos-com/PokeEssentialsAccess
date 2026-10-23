# The config menu's verbosity screen (Personalization): the scheme in use, schemes created from the levels in use and
# edited reading by reading, used, renamed, copied and deleted on a second press; the rotation key ships unbound.
class VerbosityMenuTest < PokeAccessTest
  MENU_STATE = [:@mode, :@index, :@stack, :@scheme, :@armed, :@items, :@items_key, :@reading_group, :@ri]

  test "lists the setting, the new scheme, each scheme by name, then back" do
    on_verbosity_screen do |cm|
      store.set("Zeta", {})
      store.set("Rapido", { :party => :brief })
      assert_equal ["#{t(:lbl_scheme_in_use)}, #{t(:vb_level_full)}", t(:vb_new), "Rapido", "Zeta", t(:back)],
                   said_rows(cm)
    end
  end

  test "entering from Personalization says the screen's title, then the scheme in use under a name of its own" do
    on_verbosity_screen do |cm|
      cm.instance_variable_set(:@stack, [[:top, 0]])
      cm.instance_variable_set(:@mode, :personal)
      cm.activate(1)
      assert_equal "#{t(:cat_verbosity)}. #{t(:lbl_scheme_in_use)}, #{t(:vb_level_full)}", SpeakCapture.last
      refute_equal t(:cat_verbosity), t(:lbl_scheme_in_use), "the row does not repeat the title"
    end
  end

  test "says the scheme in use on the setting, and on that scheme's own row" do
    on_verbosity_screen do |cm|
      store.set("Rapido", { :party => :brief })
      PokeAccess::Config.verbosity = :Rapido
      assert_equal ["#{t(:lbl_scheme_in_use)}, Rapido", t(:vb_in_use, :name => "Rapido")], said_rows(cm).values_at(0, 2)
    end
  end

  test "right on the setting goes to the next scheme, past the player's own and round to brief" do
    on_verbosity_screen do |cm|
      store.set("Rapido", { :party => :brief })
      { :full => [:Rapido, "Rapido"], :Rapido => [:brief, t(:vb_level_brief)] }.each do |from, (to, name)|
        PokeAccess::Config.verbosity = from
        cm.adjust(cm.items[0], 1)
        assert_equal [to, "#{t(:lbl_scheme_in_use)}, #{name}"], [PokeAccess::Config.verbosity, SpeakCapture.last],
                     "from #{from}"
      end
    end
  end

  test "the info key on the new scheme's row explains it" do
    on_verbosity_screen do |cm|
      point_at(cm) { |row| row[:op] == :new }
      cm.speak_help
      assert_equal t(:vb_new_help), SpeakCapture.last
    end
  end

  test "a new scheme starts every reading, and the others, at the level in use" do
    on_verbosity_screen do |cm|
      PokeAccess::Config.verbosity = :medium
      create(cm, "Rapido")
      assert_equal every_reading(:medium), store.levels("Rapido")
    end
  end

  test "a new scheme made under a player's scheme takes each reading's level from it" do
    on_verbosity_screen do |cm|
      store.set("Base", { :party => :brief, :others => :medium })
      PokeAccess::Config.verbosity = :Base
      create(cm, "Copia")
      assert_equal every_reading(:medium).merge(:party => :brief), store.levels("Copia")
    end
  end

  test "a new scheme is saved under the name typed, trimmed, and asks whether to use it now, yes first" do
    on_verbosity_screen do |cm|
      point_at(cm) { |row| row[:op] == :new }
      with_scheme_name("  Rapido ") { cm.activate(1) }
      said = "#{t(:vb_created, :name => 'Rapido')}. #{t(:vb_use_ask)} #{t(:vb_yes)}"
      assert_equal [["Rapido"], said, [t(:vb_yes), t(:vb_no)], :full],
                   [store.names, SpeakCapture.last, said_rows(cm), PokeAccess::Verbosity.active]
    end
  end

  test "yes puts the new scheme in use and opens its editor, saying both" do
    on_verbosity_screen do |cm|
      create(cm, "Rapido", :use_now)
      said = "#{t(:vb_now, :name => 'Rapido')}. #{t(:vb_editing, :name => 'Rapido')}. #{t(:vbg_general)}"
      assert_equal [:Rapido, said], [PokeAccess::Verbosity.active, SpeakCapture.last]
    end
  end

  test "no keeps the scheme in use as it was and opens the new one's editor" do
    on_verbosity_screen do |cm|
      create(cm, "Rapido", :not_now)
      assert_equal [:full, "#{t(:vb_editing, :name => 'Rapido')}. #{t(:vbg_general)}"],
                   [PokeAccess::Verbosity.active, SpeakCapture.last]
    end
  end

  test "cancel on the question goes back to the verbosity screen on the new scheme, using nothing" do
    on_verbosity_screen do |cm|
      point_at(cm) { |row| row[:op] == :new }
      with_scheme_name("Rapido") { cm.activate(1) }
      cm.back_one
      assert_equal [:full, "Rapido"], [PokeAccess::Verbosity.active, SpeakCapture.last]
    end
  end

  test "a blank name, a closed text box or a failing one cancels, creating nothing" do
    on_verbosity_screen do |cm|
      { "a blank name" => "   ", "the text box closed" => nil }.each do |what, answer|
        point_at(cm) { |row| row[:op] == :new }
        with_scheme_name(answer) { cm.activate(1) }
        assert_equal [t(:cancelled), [], t(:vb_new)], [SpeakCapture.last, store.names, cm.describe], what
      end
      cm.activate(1)
      assert_equal [t(:cancelled), [], t(:vb_new)], [SpeakCapture.last, store.names, cm.describe], "no text entry"
    end
  end

  test "a name another scheme or a built-in one has, whatever its case, is refused" do
    on_verbosity_screen do |cm|
      store.set("Rapido", { :party => :brief })
      ["RAPIDO", "rapido", t(:vb_level_brief), t(:vb_level_brief).upcase, "full", t(:vb_level_medium)].each do |name|
        point_at(cm) { |row| row[:op] == :new }
        with_scheme_name(name) { cm.activate(1) }
        assert_equal [t(:vb_name_taken, :name => name), ["Rapido"]], [SpeakCapture.last, store.names], name
      end
    end
  end

  test "asks for the name in the game's text entry, up to 20 letters, empty for a new scheme, the old for a rename" do
    on_verbosity_screen do |cm|
      point_at(cm) { |row| row[:op] == :new }
      made = with_scheme_name("Rapido") { |asked| cm.activate(1); asked }
      cm.back_one
      enter_scheme(cm, "Rapido")
      renamed = with_scheme_name("Zorro") { |asked| cm.run_scheme_action(:rename); asked }
      assert_equal [[[t(:vb_name_prompt), 0, 20, ""]], [[t(:vb_name_prompt), 0, 20, "Rapido"]]], [made, renamed]
    end
  end

  test "the editor lists each group with readings in order, then the others' level and back" do
    on_verbosity_screen do |cm|
      create(cm, "Rapido")
      assert_equal [t(:vbg_general), t(:vbg_map), t(:vbg_battle), t(:vbg_pokemon), t(:vbg_items), t(:vbg_dex),
                    t(:vbg_game), "#{t(:vb_others)}, #{t(:vb_level_full)}", t(:back)], said_rows(cm)
    end
  end

  test "a group opens on its first reading, saying the group and that reading's level" do
    on_verbosity_screen do |cm|
      PokeAccess::Config.verbosity = :medium
      create(cm, "Rapido")
      point_at(cm) { |row| row[:group] == :pokemon }
      cm.activate(1)
      assert_equal "#{t(:vbg_pokemon)}. #{t(:vb_party)}, #{t(:vb_level_medium)}", SpeakCapture.last
    end
  end

  test "a group lists its readings, each at the scheme's level, then back" do
    on_verbosity_screen do |cm|
      PokeAccess::Config.verbosity = :medium
      create(cm, "Rapido")
      point_at(cm) { |row| row[:group] == :battle }
      cm.activate(1)
      assert_equal ["#{t(:vb_battle_move)}, #{t(:vb_level_medium)}", "#{t(:vb_battle_marks)}, #{t(:vb_level_medium)}",
                    t(:back)], said_rows(cm)
    end
  end

  test "left and right move a reading one level, round the ends, saying it and saving it at once" do
    on_verbosity_screen do |cm|
      PokeAccess::Config.verbosity = :medium
      create(cm, "Rapido")
      point_at(cm) { |row| row[:group] == :pokemon }
      cm.activate(1)
      steps = [-1, -1, 1].map do |dir|
        cm.adjust(cm.items[0], dir)
        store.reload!
        [store.levels("Rapido")[:party], SpeakCapture.last]
      end
      assert_equal [[:brief, "#{t(:vb_party)}, #{t(:vb_level_brief)}"], [:full, "#{t(:vb_party)}, #{t(:vb_level_full)}"],
                    [:brief, "#{t(:vb_party)}, #{t(:vb_level_brief)}"]], steps
    end
  end

  test "the info key on a reading says what each level says of it" do
    on_verbosity_screen do |cm|
      create(cm, "Rapido")
      point_at(cm) { |row| row[:group] == :pokemon }
      cm.activate(1)
      cm.speak_help
      assert_equal t(:vbh_party), SpeakCapture.last
    end
  end

  test "back from a group is the editor on that group, and back again the verbosity screen on the new scheme" do
    on_verbosity_screen do |cm|
      store.set("Zeta", {})
      create(cm, "Rapido")
      point_at(cm) { |row| row[:group] == :pokemon }
      cm.activate(1)
      backs = [1, 2].map { cm.back_one; SpeakCapture.last }
      assert_equal [t(:vbg_pokemon), "Rapido"], backs
    end
  end

  test "a scheme opens its actions under its name" do
    on_verbosity_screen do |cm|
      store.set("Rapido", { :party => :brief })
      point_at(cm) { |row| row[:name] == "Rapido" }
      cm.activate(1)
      assert_equal [[t(:vb_act_use), t(:vb_act_edit), t(:tag_rename), t(:vb_act_copy), t(:entry_forget), t(:back)],
                    "Rapido. #{t(:vb_act_use)}"], [said_rows(cm), SpeakCapture.last]
    end
  end

  test "the info key on a scheme's row and on each of its actions says what it does, not the row again" do
    on_verbosity_screen do |cm|
      store.set("Rapido", { :party => :brief })
      helps = [cm.help_text(point_at(cm) { |row| row[:name] == "Rapido" })]
      cm.activate(1)
      helps.concat(cm.items.select { |row| row[:kind] == :scheme_action }.map { |row| cm.help_text(row) })
      assert_equal [t(:vb_scheme_help), t(:vb_act_use_help), t(:vb_act_edit_help), t(:vb_act_rename_help),
                    t(:vb_act_copy_help), t(:vb_act_delete_help)], helps
    end
  end

  test "use puts the scheme in use and says so" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      cm.run_scheme_action(:use)
      assert_equal [:Rapido, t(:vb_now, :name => "Rapido")], [PokeAccess::Config.verbosity, SpeakCapture.last]
    end
  end

  test "edit opens the scheme's editor under its name" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      cm.run_scheme_action(:edit)
      assert_equal ["#{t(:vb_editing, :name => 'Rapido')}. #{t(:vbg_general)}", "#{t(:vb_others)}, #{t(:vb_level_full)}"],
                   [SpeakCapture.last, said_rows(cm)[-2]]
    end
  end

  test "a rename keeps the scheme in use under the new name, the verbosity screen's cursor following it" do
    on_verbosity_screen do |cm|
      store.set("Zeta", { :party => :medium })
      enter_scheme(cm, "Rapido", { :party => :brief })
      PokeAccess::Config.verbosity = :Rapido
      with_scheme_name("Zorro") { cm.run_scheme_action(:rename) }
      said = SpeakCapture.last
      cm.back_one
      assert_equal [:Zorro, ["Zeta", "Zorro"], { :party => :brief }, t(:vb_renamed, :name => "Zorro"),
                    t(:vb_in_use, :name => "Zorro")],
                   [PokeAccess::Config.verbosity, store.names, store.levels("Zorro"), said, SpeakCapture.last]
    end
  end

  test "after a rename, the scheme's other actions act on its new name" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      with_scheme_name("Zorro") { cm.run_scheme_action(:rename) }
      cm.run_scheme_action(:use)
      assert_equal [:Zorro, t(:vb_now, :name => "Zorro")], [PokeAccess::Config.verbosity, SpeakCapture.last]
    end
  end

  test "a rename of a scheme not in use leaves the one in use alone" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      with_scheme_name("Zorro") { cm.run_scheme_action(:rename) }
      assert_equal [:full, ["Zorro"]], [PokeAccess::Config.verbosity, store.names]
    end
  end

  test "a rename may change only the case of the scheme's own name" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      with_scheme_name("RAPIDO") { cm.run_scheme_action(:rename) }
      assert_equal [["RAPIDO"], t(:vb_renamed, :name => "RAPIDO")], [store.names, SpeakCapture.last]
    end
  end

  test "a rename cancelled or to a name taken changes nothing" do
    on_verbosity_screen do |cm|
      store.set("Zeta", {})
      enter_scheme(cm, "Rapido", { :party => :brief })
      PokeAccess::Config.verbosity = :Rapido
      { "  " => t(:cancelled), "zeta" => t(:vb_name_taken, :name => "zeta") }.each do |answer, said|
        with_scheme_name(answer) { cm.run_scheme_action(:rename) }
        assert_equal [said, ["Rapido", "Zeta"], :Rapido], [SpeakCapture.last, store.names, PokeAccess::Config.verbosity],
                     answer.inspect
      end
    end
  end

  test "a copy carries the scheme's levels and asks over the verbosity screen whether to use it now" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief, :others => :medium })
      with_scheme_name("Copia") { cm.run_scheme_action(:copy) }
      said = SpeakCapture.last
      cm.back_one
      assert_equal [{ :party => :brief, :others => :medium },
                    "#{t(:vb_created, :name => 'Copia')}. #{t(:vb_use_ask)} #{t(:vb_yes)}", "Copia"],
                   [store.levels("Copia"), said, SpeakCapture.last]
    end
  end

  test "deleting asks on the first press, and moving away forgets the question" do
    on_verbosity_screen do |cm|
      enter_scheme(cm, "Rapido", { :party => :brief })
      cm.run_scheme_action(:delete)
      asked = SpeakCapture.last
      cm.move(1)
      cm.move(-1)
      cm.run_scheme_action(:delete)
      assert_equal [t(:vb_delete_confirm, :name => "Rapido"), t(:vb_delete_confirm, :name => "Rapido"), ["Rapido"]],
                   [asked, SpeakCapture.last, store.names]
    end
  end

  test "a second press in a row deletes the scheme and goes back to the verbosity screen, saying the row there" do
    on_verbosity_screen do |cm|
      store.set("Zeta", {})
      enter_scheme(cm, "Rapido", { :party => :brief })
      2.times { cm.run_scheme_action(:delete) }
      assert_equal [["Zeta"], :full, "#{t(:vb_deleted, :name => 'Rapido')}. Zeta"],
                   [store.names, PokeAccess::Config.verbosity, SpeakCapture.last]
    end
  end

  test "deleting the scheme in use leaves full in use and says so" do
    on_verbosity_screen do |cm|
      store.set("Zeta", {})
      enter_scheme(cm, "Rapido", { :party => :brief })
      PokeAccess::Config.verbosity = :Rapido
      2.times { cm.run_scheme_action(:delete) }
      assert_equal [:full, "#{t(:vb_deleted, :name => 'Rapido')}. #{t(:vb_now, :name => t(:vb_level_full))}. Zeta"],
                   [PokeAccess::Config.verbosity, SpeakCapture.last]
    end
  end

  test "the editor's last reading is the others' level, said full while the scheme leaves it unset" do
    on_verbosity_screen do |cm|
      edit_scheme(cm, "Corto", { :party => :brief })
      assert_equal ["#{t(:vb_others)}, #{t(:vb_level_full)}", t(:back)], said_rows(cm).last(2)
    end
  end

  test "left on the others' level sets it, and a reading the scheme does not name follows it" do
    on_verbosity_screen do |cm|
      edit_scheme(cm, "Corto", { :party => :brief })
      cm.adjust(cm.items[-2], -1)
      point_at(cm) { |row| row[:group] == :items }
      cm.activate(1)
      bag = point_at(cm) { |row| row[:reading] == :bag_item }
      said = cm.describe
      cm.adjust(bag, 1)
      assert_equal [:medium, "#{t(:vb_bag_item)}, #{t(:vb_level_medium)}", :full],
                   [store.levels("Corto")[:others], said, store.levels("Corto")[:bag_item]]
    end
  end

  test "the info key on the others' level says what it is for" do
    on_verbosity_screen do |cm|
      edit_scheme(cm, "Corto", { :party => :brief })
      point_at(cm) { |row| row[:reading] == PokeAccess::Verbosity::OTHERS }
      cm.speak_help
      assert_equal t(:vbh_others), SpeakCapture.last
    end
  end

  test "the rotation key's row says it is unassigned, then how to change it, the hint left out in brief" do
    on_remap_entry(:verbosity) do |cm|
      entry = t(:rmp_entry, :action => PokeAccess::Remap.label(:verbosity), :key => t(:rmp_unassigned))
      { :full => "#{entry}. #{t(:rmp_entry_hint)}", :brief => entry }.each do |level, said|
        PokeAccess::Config.verbosity = level
        assert_equal said, cm.rebind_desc, level.to_s
      end
    end
  end

  test "once bound, the rotation key's row names the key it is on" do
    on_remap_entry(:verbosity) do |cm|
      PokeAccess::Config.keys[:verbosity] = 0x7B
      assert_equal "#{t(:rmp_entry, :action => PokeAccess::Remap.label(:verbosity), :key => t(:key_f, :n => 12))}. " \
                   "#{t(:rmp_entry_hint)}", cm.rebind_desc
    end
  end

  test "left on the bound rotation key unbinds it and says so, and again finds nothing to undo" do
    on_remap_entry(:verbosity) do |cm|
      PokeAccess::Config.keys[:verbosity] = 0x7B
      said = [1, 2].map { cm.clear_binding; [PokeAccess::Config.keys[:verbosity], SpeakCapture.last] }
      assert_equal [[nil, t(:rmp_cleared, :action => PokeAccess::Remap.label(:verbosity))], [nil, t(:rmp_none)]], said
    end
  end

  test "left on a mod key whose default another entry holds keeps it and says who holds that default" do
    on_remap_entry(:hist_prev) do |cm|
      PokeAccess::Config.keys[:hist_prev] = 0x2D
      PokeAccess::Config.keys[:hp] = 0x24
      cm.clear_binding
      assert_equal [0x2D, t(:rmp_inuse, :key => t(:key_home), :action => PokeAccess::Remap.label(:hp))],
                   [PokeAccess::Config.keys[:hist_prev], SpeakCapture.last]
    end
  end

  test "left on a mod key that ships bound gives it its default back" do
    on_remap_entry(:hist_prev) do |cm|
      PokeAccess::Config.keys[:hist_prev] = 0x2D
      cm.clear_binding
      assert_equal [0x24, t(:rmp_restored, :action => PokeAccess::Remap.label(:hist_prev))],
                   [PokeAccess::Config.keys[:hist_prev], SpeakCapture.last]
    end
  end

  private

  def t(key, vars = nil); PokeAccess::I18n.t(key, vars); end

  def store; PokeAccess::VerbositySchemes; end

  # The rows of the screen the menu is on, as each is said.
  def said_rows(cm)
    cm.items.map { |row| cm.describe(row) }
  end

  # Puts the menu's cursor on the first row of its screen the block accepts, and answers that row.
  def point_at(cm, &pick)
    i = cm.items.index(&pick)
    flunk "no such row on #{cm.instance_variable_get(:@mode)}" unless i
    cm.instance_variable_set(:@index, i)
    cm.items[i]
  end

  # Creates a scheme from the new scheme's row, the text entry answering name, and answers whether to use it now
  # on the row of answer (:use_now or :not_now).
  def create(cm, name, answer = :not_now)
    point_at(cm) { |row| row[:op] == :new }
    with_scheme_name(name) { cm.activate(1) }
    point_at(cm) { |row| row[:op] == answer }
    cm.activate(1)
  end

  # Saves a scheme of these levels (when given) and opens its actions from the verbosity screen.
  def enter_scheme(cm, name, levels = nil)
    store.set(name, levels) if levels
    point_at(cm) { |row| row[:name] == name }
    cm.activate(1)
  end

  # Saves a scheme of these levels and opens its editor straight from the verbosity screen.
  def edit_scheme(cm, name, levels)
    enter_scheme(cm, name, levels)
    cm.run_scheme_action(:edit)
  end

  # Every declared reading, and the others' entry, at level.
  def every_reading(level)
    out = { PokeAccess::Verbosity::OTHERS => level }
    PokeAccess::Verbosity.readings.each { |row| out[row[0]] = level }
    out
  end

  # Runs the block with the game's text entry answering every prompt with answer (nil for closed), yielding the
  # arguments of each prompt it got; the stand-in is taken away afterwards.
  def with_scheme_name(answer)
    asked = []
    Object.send(:define_method, :pbEnterText) { |*args| asked.push(args); answer }
    yield asked
  ensure
    Object.send(:remove_method, :pbEnterText)
  end

  # Runs the block on the verbosity screen, reached through Personalization, with an empty scheme store; afterwards
  # the menu's state and the settings file are put back and the store is left empty.
  def on_verbosity_screen
    cm = PokeAccess::ConfigMenu
    saved = MENU_STATE.map { |ivar| cm.instance_variable_get(ivar) }
    settings = (File.read(PokeAccess::Settings::FILE) rescue nil)
    wipe_schemes
    cm.instance_variable_set(:@stack, [[:top, 0], [:personal, 0]])
    cm.instance_variable_set(:@mode, :verbosity)
    cm.instance_variable_set(:@index, 0)
    cm.instance_variable_set(:@armed, nil)
    SpeakCapture.clear
    yield cm
  ensure
    wipe_schemes
    MENU_STATE.each_with_index { |ivar, i| cm.instance_variable_set(ivar, saved[i]) }
    put_back_settings(settings)
  end

  # Runs the block with the key binding list on the entry for action; the list's cursor and the settings file are
  # put back afterwards (Reset restores the keys).
  def on_remap_entry(action)
    cm = PokeAccess::ConfigMenu
    was = cm.instance_variable_get(:@ri)
    settings = (File.read(PokeAccess::Settings::FILE) rescue nil)
    cm.instance_variable_set(:@ri, PokeAccess::Remap.buttons.index { |b| b[0] == action })
    SpeakCapture.clear
    yield cm
  ensure
    cm.instance_variable_set(:@ri, was)
    put_back_settings(settings)
  end

  # Deletes the scheme files and forgets the store.
  def wipe_schemes
    [store::FILE, store::IMPORT, store::EXPORT].each { |f| File.delete(f) if File.exist?(f) }
    store.reload!
  end

  # Writes the settings file back as it was, or deletes it when there was none.
  def put_back_settings(text)
    file = PokeAccess::Settings::FILE
    if text
      File.open(file, "w") { |f| f.write(text) }
    elsif File.exist?(file)
      File.delete(file)
    end
  end
end
