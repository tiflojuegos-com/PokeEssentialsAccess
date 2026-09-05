# The player's marks on the map: Ctrl+G names the tile under the player, the locator lists the map's marks
# in a category of their own, and the two keys that already act on a selected target (Shift+K rename,
# Ctrl+K menu) act on a mark too. What is pinned is the player-visible contract -- one key creates, edits
# and removes; the category exists only where there is something in it; a mark is a target like any other
# -- because every piece is a small branch in code that already works for events, and a branch that quietly
# falls into the event path speaks "this cannot be labelled" at a tile the player just marked.

# Deletes the marks files and forgets the store, before and after.
def marks_wipe
  [PokeAccess::Marks::FILE, PokeAccess::Marks::IMPORT, PokeAccess::Marks::EXPORT].each { |f| (File.delete(f) rescue nil) }
  PokeAccess::Marks.reload!
end

# Stands in for the engine's text box for the duration of the block: every prompt answers with the given
# text (nil = the player cancelled), and the stand-in is removed afterwards so no other suite inherits it.
def with_text_answer(answer)
  $marks_spec_answer = answer
  Object.send(:define_method, :pbEnterText) { |*_a| $marks_spec_answer }
  yield
ensure
  Object.send(:remove_method, :pbEnterText)
end

# Stands in for the engine's choice menu: every menu picks the given index. The stub engine already answers
# Kernel.pbMessage with nil (which show_menu prefers over the bare call), so the singleton is what is replaced.
def with_menu_choice(index)
  $marks_spec_choice = index
  orig = Kernel.method(:pbMessage)
  Kernel.define_singleton_method(:pbMessage) { |*_a| $marks_spec_choice }
  yield
ensure
  Kernel.define_singleton_method(:pbMessage, orig)
end

# Runs the block with the locator's category cursor and target saved and restored, on a map with the player
# at a known tile.
def with_marks_state
  loc = PokeAccess::Locator
  ivars = [:@cat, :@ti, :@target, :@targets]
  prev = ivars.map { |s| loc.instance_variable_get(s) }
  had_temp = $game_temp
  $game_temp ||= Game_Temp.new
  $game_map.map_id = 1
  $game_player.x = 5
  $game_player.y = 5
  marks_wipe
  yield loc
ensure
  marks_wipe
  $game_temp = had_temp
  ivars.each_index { |i| loc.instance_variable_set(ivars[i], prev[i]) }
end

Suite.define("marks: the category appears only on a map that has one, and never grows the base") do
  with_marks_state do |loc|
    PokeAccess::Config.categories = [:all, :people, :objects, :exits, :signs, :extras, :surfaces]
    falsy "with no marks on the map the category is not offered", loc.active_categories.include?(:marks)

    PokeAccess::Marks.set(2, 1, 1, "En otro mapa")
    falsy "a mark on another map does not bring it either", loc.active_categories.include?(:marks)

    PokeAccess::Marks.set(1, 7, 5, "Tienda")
    500.times { loc.active_categories }
    ac = loc.active_categories
    eq "a mark on this map adds the category exactly once", ac.count { |c| c == :marks }, 1
    eq "and the configured base is untouched after 500 reads", PokeAccess::Config.categories.size, 7
    eq "the category speaks as marks", loc.cat_name(:marks), PokeAccess::I18n.t(:tcat_marks)

    loc.instance_variable_set(:@cat, ac.index(:marks))
    loc.rebuild_targets
    t = loc.instance_variable_get(:@targets)
    eq "the map's marks are the category's targets", t.map { |x| [x.x, x.y] }, [[7, 5]]
    truthy "each a synthetic target carrying the mark key", loc.mark_target?(t[0])
    eq "spoken by the name the player gave it", loc.target_name(t[0]), "Tienda"
  end
end

Suite.define("marks: Ctrl+G creates, edits and removes the mark under the player with one prompt") do
  with_marks_state do |loc|
    SpeakCapture.clear
    with_text_answer("Tienda") { loc.mark_here }
    eq "a bare tile takes the name typed", PokeAccess::Marks.get(1, 5, 5), "Tienda"
    eq "the prompt names the tile, then confirms", SpeakCapture.lines,
       [PokeAccess::I18n.t(:mark_for, :name => "x 5, y 5"), PokeAccess::I18n.t(:mark_saved, :label => "Tienda")]

    SpeakCapture.clear
    with_text_answer("Tienda barata") { loc.mark_here }
    eq "on a marked tile the prompt is an edit of that mark", SpeakCapture.lines[0],
       PokeAccess::I18n.t(:mark_edit_for, :name => "Tienda")
    eq "and the new name replaces the old", PokeAccess::Marks.get(1, 5, 5), "Tienda barata"

    SpeakCapture.clear
    with_text_answer(nil) { loc.mark_here }
    eq "cancelling the prompt changes nothing", PokeAccess::Marks.get(1, 5, 5), "Tienda barata"

    SpeakCapture.clear
    with_text_answer("   ") { loc.mark_here }
    falsy "a blanked answer removes the mark", PokeAccess::Marks.get(1, 5, 5)
    eq "and says so", SpeakCapture.lines[1], PokeAccess::I18n.t(:mark_removed)

    $game_temp.in_menu = true
    SpeakCapture.clear
    with_text_answer("En la mochila") { loc.mark_here }
    $game_temp.in_menu = false
    falsy "inside a menu the key marks nothing", PokeAccess::Marks.get(1, 5, 5)
    eq "and explains why", SpeakCapture.lines, [PokeAccess::I18n.t(:mark_map_only)]
  end
end

Suite.define("marks: the rename key and the Ctrl+K menu act on a selected mark") do
  with_marks_state do |loc|
    PokeAccess::Marks.set(1, 7, 5, "Tienda")
    PokeAccess::Config.categories = [:all, :people, :objects, :exits, :signs, :extras, :surfaces]
    loc.instance_variable_set(:@cat, loc.active_categories.index(:marks))
    loc.rebuild_targets
    loc.instance_variable_set(:@ti, 0)
    loc.instance_variable_set(:@target, loc.instance_variable_get(:@targets)[0])
    truthy "the fixture selected the mark", loc.mark_target?(loc.instance_variable_get(:@target))

    SpeakCapture.clear
    with_text_answer("Centro Pokemon") { loc.rename_target }
    eq "Shift+K renames the mark instead of refusing a target with no id",
       PokeAccess::Marks.get(1, 7, 5), "Centro Pokemon"
    eq "with the mark's own wording", SpeakCapture.lines[0],
       PokeAccess::I18n.t(:mark_edit_for, :name => "Tienda")
    eq "and the selection now carries the new name without the player moving the cursor",
       loc.target_name(loc.instance_variable_get(:@target)), "Centro Pokemon"
    truthy "a mark that still exists is a valid target", loc.target_valid?

    SpeakCapture.clear
    with_menu_choice(1) { loc.tag_menu }
    falsy "the Ctrl+K menu's second entry deletes the mark", PokeAccess::Marks.get(1, 7, 5)
    eq "and announces it", SpeakCapture.lines,
       [PokeAccess::I18n.t(:mark_deleted, :name => "Centro Pokemon")]
    falsy "after which the map has no marks and the category is gone", loc.active_categories.include?(:marks)

    PokeAccess::Marks.set(1, 7, 5, "Otra vez")
    loc.instance_variable_set(:@cat, loc.active_categories.index(:marks))
    loc.rebuild_targets
    loc.instance_variable_set(:@target, loc.instance_variable_get(:@targets)[0])
    PokeAccess::Marks.delete(1, 7, 5)
    falsy "a mark deleted behind the locator's back (the config menu) is no longer a valid target",
          loc.target_valid?
  end
end
