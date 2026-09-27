# The config menu's verbosity screen (Personalization): schemes created from the levels in use and edited reading by
# reading, used, renamed, copied and deleted on a second press; the rotation key ships unbound.

# Deletes the scheme files and forgets the store.
def verbosity_menu_wipe
  m = PokeAccess::VerbositySchemes
  [m::FILE, m::IMPORT, m::EXPORT].each { |f| (File.delete(f) rescue nil) }
  m.reload!
end

# Stands in for the engine's text box during the block: every prompt answers with the text (nil = cancelled).
def with_scheme_name(answer)
  $verbosity_menu_answer = answer
  Object.send(:define_method, :pbEnterText) { |*_a| $verbosity_menu_answer }
  yield
ensure
  Object.send(:remove_method, :pbEnterText)
end

# Runs the block on the verbosity screen, reached through Personalization, with an empty store; the menu's state is
# saved and restored.
def with_verbosity_menu
  cm = PokeAccess::ConfigMenu
  ivars = [:@mode, :@index, :@stack, :@scheme, :@armed, :@items]
  prev = ivars.map { |s| cm.instance_variable_get(s) }
  verbosity_menu_wipe
  cm.instance_variable_set(:@stack, [[:top, 0], [:personal, 0]])
  cm.instance_variable_set(:@mode, :verbosity)
  cm.instance_variable_set(:@index, 0)
  cm.instance_variable_set(:@armed, nil)
  yield cm
ensure
  verbosity_menu_wipe
  ivars.each_index { |i| cm.instance_variable_set(ivars[i], prev[i]) }
end

Suite.define("verbosity menu: the scheme in use, a new scheme, then the player's own") do
  t = PokeAccess::I18n
  with_verbosity_menu do |cm|
    PokeAccess::VerbositySchemes.set("Rapido", { :party => :brief })
    rows = cm.items
    eq "the setting, the new scheme, each scheme by name, then back", rows.map { |r| r[:kind] },
       [:setting, :scheme_action, :scheme, :back]
    eq "the setting says the scheme in use", cm.describe(rows[0]), "#{t.t(:lbl_verbosity)}, #{t.t(:vb_level_full)}"
    eq "a scheme not in use is its name", cm.describe(rows[2]), "Rapido"
    PokeAccess::Config.verbosity = :Rapido
    eq "and the one in use says so", cm.describe(rows[2]), t.t(:vb_in_use, :name => "Rapido")
    SpeakCapture.clear
    cm.adjust(rows[0], 1)
    eq "right on the setting goes on through the rotation, wrapping to brief", PokeAccess::Config.verbosity, :brief
    eq "and says it", SpeakCapture.last, "#{t.t(:lbl_verbosity)}, #{t.t(:vb_level_brief)}"
    cm.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    cm.speak_help
    eq "the info key on the new scheme row explains it", SpeakCapture.last, t.t(:vb_new_help)
  end
end

Suite.define("verbosity menu: a new scheme copies the levels in use and opens its editor") do
  t = PokeAccess::I18n
  store = PokeAccess::VerbositySchemes
  with_verbosity_menu do |cm|
    PokeAccess::Config.verbosity = :medium
    cm.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    with_scheme_name("  Rapido ") { cm.activate(1) }
    eq "every reading starts at the level in use", store.levels("Rapido").values.uniq, [:medium]
    eq "all of them, and the level of the readings it does not name", store.levels("Rapido").keys.length,
       PokeAccess::Verbosity.readings.length + 1
    eq "and the editor opens on it", [cm.instance_variable_get(:@mode), cm.instance_variable_get(:@scheme)],
       [:scheme_edit, "Rapido"]
    eq "saying so and its first reading", SpeakCapture.last,
       "#{t.t(:vb_created, :name => "Rapido")}. #{t.t(:vb_party)}, #{t.t(:vb_level_medium)}"

    SpeakCapture.clear
    cm.adjust(cm.items[0], -1)
    eq "left lowers the reading and saves it at once", store.levels("Rapido")[:party], :brief
    eq "saying the reading and its new level", SpeakCapture.last, "#{t.t(:vb_party)}, #{t.t(:vb_level_brief)}"
    cm.adjust(cm.items[0], -1)
    eq "and below brief it wraps to full", store.levels("Rapido")[:party], :full
    store.reload!
    eq "what was saved is on disk", store.levels("Rapido")[:party], :full

    SpeakCapture.clear
    cm.speak_help
    eq "the info key on a reading says what each level says of it", SpeakCapture.last, t.t(:vbh_party)

    cm.back_one
    eq "back is the verbosity screen", cm.instance_variable_get(:@mode), :verbosity
    eq "with the cursor on the new scheme", cm.items[cm.instance_variable_get(:@index)][:name], "Rapido"
  end
end

Suite.define("verbosity menu: a name left blank cancels, and one already taken is refused") do
  t = PokeAccess::I18n
  store = PokeAccess::VerbositySchemes
  with_verbosity_menu do |cm|
    store.set("Rapido", { :party => :brief })
    cm.instance_variable_set(:@index, 1)
    SpeakCapture.clear
    with_scheme_name("   ") { cm.activate(1) }
    eq "a blank name cancels", SpeakCapture.last, t.t(:cancelled)
    with_scheme_name("RAPIDO") { cm.activate(1) }
    eq "a name taken is refused, whatever its case", SpeakCapture.last, t.t(:vb_name_taken, :name => "RAPIDO")
    with_scheme_name(t.t(:vb_level_brief)) { cm.activate(1) }
    eq "and so is a built-in scheme's", SpeakCapture.last, t.t(:vb_name_taken, :name => t.t(:vb_level_brief))
    with_scheme_name(nil) { cm.activate(1) }
    eq "the text box closed without an answer cancels too", SpeakCapture.last, t.t(:cancelled)
    eq "nothing was created", store.names, ["Rapido"]
    eq "and the screen is still the verbosity one", cm.instance_variable_get(:@mode), :verbosity
  end
end

Suite.define("verbosity menu: a scheme is used, renamed in use, copied and deleted on a second press") do
  t = PokeAccess::I18n
  store = PokeAccess::VerbositySchemes
  with_verbosity_menu do |cm|
    store.set("Rapido", { :party => :brief })
    store.set("Zeta", { :party => :medium })
    cm.instance_variable_set(:@index, 2)
    SpeakCapture.clear
    cm.activate(1)
    eq "a scheme opens its actions", cm.items.map { |r| r[:op] || r[:kind] }, [:use, :edit, :rename, :copy, :delete, :back]
    eq "under its name", SpeakCapture.last, "Rapido. #{t.t(:vb_act_use)}"

    cm.run_scheme_action(:use)
    eq "use puts it in use", PokeAccess::Config.verbosity, :Rapido
    eq "and says so", SpeakCapture.last, t.t(:vb_now, :name => "Rapido")

    with_scheme_name("Zorro") { cm.run_scheme_action(:rename) }
    eq "a rename keeps it in use under the new name", [PokeAccess::Config.verbosity, store.names], [:Zorro, ["Zeta", "Zorro"]]
    eq "and says the new name", SpeakCapture.last, t.t(:vb_renamed, :name => "Zorro")
    stack = cm.instance_variable_get(:@stack)
    eq "the verbosity screen's cursor follows it to its new place in name order", stack.last[1], 3

    with_scheme_name("Copia") { cm.run_scheme_action(:copy) }
    eq "a copy carries the levels", store.levels("Copia"), store.levels("Zorro")
    eq "and opens its editor over the verbosity screen", [cm.instance_variable_get(:@mode), cm.instance_variable_get(:@stack).length],
       [:scheme_edit, 3]
    cm.back_one

    cm.instance_variable_set(:@index, cm.scheme_row("Zorro"))
    cm.activate(1)
    SpeakCapture.clear
    cm.run_scheme_action(:delete)
    eq "the first press asks", SpeakCapture.last, t.t(:vb_delete_confirm, :name => "Zorro")
    truthy "and deletes nothing", store.names.include?("Zorro")
    cm.move(1)
    cm.move(-1)
    cm.run_scheme_action(:delete)
    truthy "moving away forgets the question", store.names.include?("Zorro")
    cm.run_scheme_action(:delete)
    falsy "a second press in a row deletes it", store.names.include?("Zorro")
    eq "the one in use gone, full is in use", PokeAccess::Config.verbosity, :full
    truthy "and it says both, then where the cursor is",
           SpeakCapture.last.index("#{t.t(:vb_deleted, :name => "Zorro")}. #{t.t(:vb_now, :name => t.t(:vb_level_full))}. ") == 0
    eq "back on the verbosity screen", cm.instance_variable_get(:@mode), :verbosity
  end
end

Suite.define("verbosity menu: the rotation key ships unbound, and left on it unbinds it again") do
  cm = PokeAccess::ConfigMenu
  t = PokeAccess::I18n
  prev_ri = cm.instance_variable_get(:@ri)
  keys_before = PokeAccess::Config.keys.dup
  begin
    cm.instance_variable_set(:@ri, PokeAccess::Remap.buttons.index { |b| b[0] == :verbosity })
    label = PokeAccess::Remap.label(:verbosity)
    eq "its row says it is unassigned, then how to change it",
       cm.rebind_desc, "#{t.t(:rmp_entry, :action => label, :key => t.t(:rmp_unassigned))}. #{t.t(:rmp_entry_hint)}"
    PokeAccess::Config.verbosity = :brief
    eq "brief leaves the hint out", cm.rebind_desc, t.t(:rmp_entry, :action => label, :key => t.t(:rmp_unassigned))
    PokeAccess::Config.verbosity = :full

    PokeAccess::Config.keys[:verbosity] = 0x7B
    SpeakCapture.clear
    cm.clear_binding
    eq "left on a bound rotation key unbinds it", PokeAccess::Config.keys[:verbosity], nil
    eq "and says so", SpeakCapture.last, t.t(:rmp_cleared, :action => label)
    cm.clear_binding
    eq "left again finds nothing to undo", SpeakCapture.last, t.t(:rmp_none)

    cm.instance_variable_set(:@ri, PokeAccess::Remap.buttons.index { |b| b[0] == :hist_prev })
    PokeAccess::Config.keys[:hist_prev] = 0x2D
    cm.clear_binding
    eq "a key that ships bound goes back to its default instead", PokeAccess::Config.keys[:hist_prev], 0x24
    eq "saying that", SpeakCapture.last, t.t(:rmp_restored, :action => PokeAccess::Remap.label(:hist_prev))
  ensure
    PokeAccess::Config.keys = keys_before
    cm.instance_variable_set(:@ri, prev_ri)
    (PokeAccess::Settings.write rescue nil)
  end
end

Suite.define("verbosity menu: the editor ends with the level of the readings the scheme does not name") do
  t = PokeAccess::I18n
  store = PokeAccess::VerbositySchemes
  with_verbosity_menu do |cm|
    store.set("Corto", { :party => :brief })
    cm.instance_variable_set(:@scheme, "Corto")
    cm.instance_variable_set(:@mode, :scheme_edit)
    rows = cm.items
    others = rows[-2]
    eq "the last reading row is the others one", others[:reading], PokeAccess::Verbosity::OTHERS
    eq "said by its name, and full while unset", cm.describe(others), "#{t.t(:vb_others)}, #{t.t(:vb_level_full)}"
    cm.adjust(others, -1)
    eq "left sets it", store.levels("Corto")[PokeAccess::Verbosity::OTHERS], :medium
    bag = rows.detect { |r| r[:reading] == :bag_item }
    eq "a reading the scheme does not name shows that level", cm.describe(bag),
       "#{t.t(:vb_bag_item)}, #{t.t(:vb_level_medium)}"
    cm.adjust(bag, 1)
    eq "and moving it starts from there", store.levels("Corto")[:bag_item], :full
    cm.instance_variable_set(:@index, rows.length - 2)
    SpeakCapture.clear
    cm.speak_help
    eq "its help says what it is for", SpeakCapture.last, t.t(:vbh_others)
  end
end
