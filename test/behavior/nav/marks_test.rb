# The player's marks: Ctrl+G names, renames or removes the one on the player's tile, :marks lists them all where the map
# holds one, K says one by its name, Shift+K and the Ctrl+K menu act on it, and a selection lasts while its mark does.
class NavMarksTest < PokeAccessTest
  Locator = PokeAccess::Locator
  Marks = PokeAccess::Marks
  # An open room with the player at (5, 5) and, under a wall, a row at y 7 they cannot get to.
  WALLED_ROW = ["##########",
                "#........#",
                "#........#",
                "#........#",
                "#........#",
                "#....@...#",
                "##########",
                "#........#",
                "##########"].freeze

  test ":marks is offered only on a map that holds one of the player's marks" do
    with_marks do
      assert_equal false, Locator.active_categories.include?(:marks), "no marks"
      Marks.set(2, 1, 1, "En otro mapa")
      assert_equal false, Locator.active_categories.include?(:marks), "a mark on another map"
      Marks.set(1, 7, 5, "Tienda")
      assert_equal PokeAccess::Config.categories + [:marks], Locator.active_categories, "a mark on this one"
    end
  end

  test "a marks store that cannot be read offers no :marks category" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      failing_store { assert_equal PokeAccess::Config.categories, Locator.active_categories }
    end
  end

  test "while hiding the unreachable, every mark is listed, one the player cannot get to as well" do
    with_marks do
      hpa_fresh_grid(WALLED_ROW)
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 3, 7, "Cueva")
      PokeAccess::Config.hide_unreachable = :unreachable
      select_first_mark
      assert_equal [[7, 5], [3, 7]], Locator.instance_variable_get(:@targets).map { |t| [t.x, t.y] }
    end
  end

  test "asking for the categories again and again leaves the configured ones as they were" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      base = PokeAccess::Config.categories.dup
      3.times { Locator.active_categories }
      assert_equal base, PokeAccess::Config.categories
    end
  end

  test "cycling back from all reaches the marks, said with how many the map holds and the nearest after it" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 2, 2, "Fuente")
      SpeakCapture.clear
      Locator.cycle_category(-1)
      cat = PokeAccess::I18n.t(:loc_category, :cat => PokeAccess::I18n.t(:tcat_marks), :n => 2)
      line, cut = SpeakCapture.log[0]
      assert_equal [1, true, true, "Tienda"],
                   [SpeakCapture.log.length, cut, line.start_with?("#{cat}. Tienda, "), Locator.target.name]
    end
  end

  test "the marks are the category's targets, nearest first, each named as the player named it" do
    with_marks do
      Marks.set(1, 2, 2, "Fuente")
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      targets = Locator.instance_variable_get(:@targets)
      assert_equal [[7, 5, "Tienda"], [2, 2, "Fuente"]], targets.map { |t| [t.x, t.y, Locator.target_name(t)] }
      assert_equal [true, true], targets.map { |t| Locator.mark_target?(t) }, "each one a mark"
    end
  end

  test "Ctrl+G on a bare tile names a new mark there, saying the tile, then the mark" do
    with_marks do
      SpeakCapture.clear
      answering("Tienda") { Locator.mark_here }
      assert_equal "Tienda", Marks.get(1, 5, 5)
      assert_equal [[PokeAccess::I18n.t(:mark_for, :name => "x 5, y 5"), true],
                    [PokeAccess::I18n.t(:mark_saved, :label => "Tienda"), true]], SpeakCapture.log
    end
  end

  test "Ctrl+G asks for the mark's name with the current one filled in, up to 40 letters" do
    with_marks do
      Marks.set(1, 5, 5, "Tienda")
      asked = answering(nil) { Locator.mark_here }
      assert_equal [[PokeAccess::I18n.t(:mark_prompt), 0, 40, "Tienda"]], asked
    end
  end

  test "Ctrl+G on a marked tile edits that mark, the new name replacing the old" do
    with_marks do
      Marks.set(1, 5, 5, "Tienda")
      SpeakCapture.clear
      answering("Tienda barata") { Locator.mark_here }
      assert_equal "Tienda barata", Marks.get(1, 5, 5)
      assert_equal [PokeAccess::I18n.t(:mark_edit_for, :name => "Tienda"),
                    PokeAccess::I18n.t(:mark_saved, :label => "Tienda barata")], SpeakCapture.lines
    end
  end

  test "a name typed with spaces around it is kept without them" do
    with_marks do
      SpeakCapture.clear
      answering("  Tienda  ") { Locator.mark_here }
      assert_equal "Tienda", Marks.get(1, 5, 5)
      assert_equal PokeAccess::I18n.t(:mark_saved, :label => "Tienda"), SpeakCapture.last
    end
  end

  test "Escape on Ctrl+G's prompt, or a blank name, leaves the mark as it was and says nothing changed" do
    with_marks do
      ["", "   "].each do |answer|
        Marks.set(1, 5, 5, "Tienda")
        SpeakCapture.clear
        answering(answer) { Locator.mark_here }
        assert_equal "Tienda", Marks.get(1, 5, 5), answer.inspect
        assert_equal [[PokeAccess::I18n.t(:mark_edit_for, :name => "Tienda"), true], [PokeAccess::I18n.t(:cancelled), true]],
                     SpeakCapture.log, answer.inspect
      end
    end
  end

  test "Escape on Ctrl+G's prompt on a bare tile adds no mark, and says nothing changed, not that one was removed" do
    with_marks do
      SpeakCapture.clear
      answering("") { Locator.mark_here }
      assert_equal [nil, false], [Marks.get(1, 5, 5), Marks.any_on?(1)]
      assert_equal [[PokeAccess::I18n.t(:mark_for, :name => "x 5, y 5"), true], [PokeAccess::I18n.t(:cancelled), true]],
                   SpeakCapture.log
    end
  end

  test "Escape on Ctrl+G's prompt on the selected mark keeps it selected" do
    with_marks do
      Marks.set(1, 5, 5, "Fuente")
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      answering("") { Locator.mark_here }
      assert_equal [5, 5, "Fuente"], [Locator.target.x, Locator.target.y, Locator.target.name]
    end
  end

  test "inside a menu Ctrl+G marks nothing and says why" do
    with_marks do
      $game_temp.in_menu = true
      SpeakCapture.clear
      answering("En la mochila") { Locator.mark_here }
      assert_nil Marks.get(1, 5, 5)
      assert_equal [[PokeAccess::I18n.t(:mark_map_only), true]], SpeakCapture.log
    end
  end

  test "Ctrl+G marks the tile again once the menu over the map is closed" do
    with_marks do
      $game_temp.in_menu = true
      $game_temp.in_menu = false
      answering("Tienda") { Locator.mark_here }
      assert_equal "Tienda", Marks.get(1, 5, 5)
    end
  end

  test "Shift+K on a selected mark renames it in the mark's own words, the selection carrying the new name" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      SpeakCapture.clear
      answering("Centro Pokemon") { Locator.rename_target }
      assert_equal "Centro Pokemon", Marks.get(1, 7, 5), "the mark renamed"
      assert_equal PokeAccess::I18n.t(:mark_edit_for, :name => "Tienda"), SpeakCapture.lines[0], "its prompt"
      assert_equal "Centro Pokemon", Locator.target_name(Locator.target), "the cursor left where it was"
    end
  end

  test "Escape on Shift+K's prompt on a mark leaves it as it was" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      answering("") { Locator.rename_target }
      assert_equal "Tienda", Marks.get(1, 7, 5)
    end
  end

  test "Escape on Shift+K's prompt keeps the label the player gave a person, and says nothing changed" do
    with_marks do
      World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      PokeAccess::Tags.set(1, 3, "Tendero")
      Locator.step(1)
      SpeakCapture.clear
      answering("") { Locator.rename_target }
      assert_equal "Tendero", PokeAccess::Tags.get(1, 3)
      assert_equal [[PokeAccess::I18n.t(:loc_label_for, :name => "Tendero"), true], [PokeAccess::I18n.t(:cancelled), true]],
                   SpeakCapture.log
    end
  ensure
    PokeAccess::Tags.delete(1, 3)
  end

  test "a selected mark stays a valid target while it exists, and is none once deleted elsewhere" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      assert_equal true, Locator.target_valid?, "the mark as set"
      Marks.delete(1, 7, 5)
      assert_equal false, Locator.target_valid?, "deleted from the dictionaries menu"
    end
  end

  test "with no map the selected mark is no valid target" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      without_map { assert_equal false, Locator.target_valid? }
    end
  end

  test "with nothing selected no target is valid" do
    with_marks { assert_equal false, Locator.target_valid? }
  end

  test "a selected person stays a valid target while on the map, and is none once gone from it" do
    with_marks do
      World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      Locator.step(1)
      assert_equal true, Locator.target_valid?, "on the map"
      $game_map.events.delete(3)
      assert_equal false, Locator.target_valid?, "gone"
    end
  end

  test "Shift+K after the selected person left the map labels the one now in its place" do
    with_marks do
      World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      World.event(:name => "EV004", :id => 4, :x => 8, :y => 5)
      Locator.step(1)
      $game_map.events.delete(3)
      answering("Tendero") { Locator.rename_target }
      assert_equal [nil, "Tendero"], [PokeAccess::Tags.get(1, 3), PokeAccess::Tags.get(1, 4)]
    end
  ensure
    PokeAccess::Tags.delete(1, 3)
    PokeAccess::Tags.delete(1, 4)
  end

  test "K with nothing selected says so" do
    with_marks do
      SpeakCapture.clear
      press_k
      assert_equal [[PokeAccess::I18n.t(:loc_nothing_selected), true]], SpeakCapture.log
    end
  end

  test "K on a selected mark says it by the name the player gave it, then where it lies" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      SpeakCapture.clear
      press_k
      where = "2 #{PokeAccess::I18n.t(:dir_right)}"
      steps = PokeAccess::I18n.t(:loc_steps, :n => 1)
      assert_equal [["Tienda, #{only_one}, #{where}, #{steps}", true]], SpeakCapture.log
    end
  end

  test "K on a mark under the player says it lies right here" do
    with_marks do
      Marks.set(1, 5, 5, "Tienda")
      select_first_mark
      SpeakCapture.clear
      press_k
      assert_equal [["Tienda, #{only_one}, #{PokeAccess::I18n.t(:loc_here)}", true]], SpeakCapture.log
    end
  end

  test "Shift+K with nothing selected says so" do
    with_marks do
      SpeakCapture.clear
      answering("Tienda") { Locator.rename_target }
      assert_equal [[PokeAccess::I18n.t(:loc_nothing_selected), true]], SpeakCapture.log
    end
  end

  test "Shift+K on a person labels it, and the label is its name from then on" do
    with_marks do
      World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      Locator.step(1)
      name = Locator.target_name(Locator.target)
      SpeakCapture.clear
      asked = answering("Tendero") { Locator.rename_target }
      assert_equal [[PokeAccess::I18n.t(:loc_label_prompt), 0, 40, ""]], asked, "the prompt, with no label yet"
      assert_equal [[PokeAccess::I18n.t(:loc_label_for, :name => name), true],
                    [PokeAccess::I18n.t(:loc_label_saved, :label => "Tendero"), true]], SpeakCapture.log
      assert_equal "Tendero", Locator.target_name(Locator.target)
    end
  ensure
    PokeAccess::Tags.delete(1, 3)
  end

  test "Shift+K on a surface, which is no event, says it cannot be labelled" do
    with_marks do
      Locator.instance_variable_set(:@target, Locator::SurfaceTarget.new(6, 5, "agua", :surf_water))
      SpeakCapture.clear
      asked = answering("Lago") { Locator.rename_target }
      assert_equal [], asked, "no prompt"
      assert_equal [[PokeAccess::I18n.t(:loc_cant_label), true]], SpeakCapture.log
    end
  end

  test "the Ctrl+K menu of a mark offers renaming, deleting and going back, under the mark's name" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      asked = choosing(2) { Locator.tag_menu }
      t = PokeAccess::I18n
      assert_equal [[t.t(:mark_menu, :name => "Tienda"), [t.t(:tag_rename), t.t(:mark_delete), t.t(:back)], 3]], asked
    end
  end

  test "the Ctrl+K menu's delete entry deletes the selected mark, says so, and the category goes with the last" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      SpeakCapture.clear
      choosing(1) { Locator.tag_menu }
      assert_nil Marks.get(1, 7, 5), "the mark deleted"
      assert_equal [[PokeAccess::I18n.t(:mark_deleted, :name => "Tienda"), true]], SpeakCapture.log
      assert_equal false, Locator.active_categories.include?(:marks), "no mark left on the map"
    end
  end

  test "deleting a mark from the Ctrl+K menu selects the first mark left" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      Marks.set(1, 2, 2, "Fuente")
      select_first_mark
      choosing(1) { Locator.tag_menu }
      assert_equal [2, 2, "Fuente"], [Locator.target.x, Locator.target.y, Locator.target.name]
    end
  end

  test "the Ctrl+K menu's rename entry edits the selected mark" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      choosing(0) { answering("Fuente") { Locator.tag_menu } }
      assert_equal "Fuente", Marks.get(1, 7, 5)
    end
  end

  test "going back from the Ctrl+K menu changes nothing and says nothing" do
    with_marks do
      Marks.set(1, 7, 5, "Tienda")
      select_first_mark
      SpeakCapture.clear
      choosing(2) { Locator.tag_menu }
      assert_equal "Tienda", Marks.get(1, 7, 5)
      assert_nothing_spoken
    end
  end

  test "in a battle Ctrl+G marks nothing and says why" do
    with_marks do
      $game_temp.in_battle = true
      SpeakCapture.clear
      answering("Batalla") { Locator.mark_here }
      assert_nil Marks.get(1, 5, 5)
      assert_equal [[PokeAccess::I18n.t(:mark_map_only), true]], SpeakCapture.log
    end
  end

  test "a picked-up item ball is no valid target once its page shows and runs nothing" do
    with_marks do
      ball_page = TestPage.new(:sprite => "Object ball", :list => [TestCmd.new(355, ["pbItemBall(:POTION)"]), TestCmd.new(0, [])])
      gone_page = TestPage.new(:sprite => "", :list => [TestCmd.new(0, [])])
      ball = $game_map.events[9] = TestGameEvent.new(:id => 9, :x => 6, :y => 5, :pages => [ball_page, gone_page])
      World.next_frame
      Locator.step(1)
      ball.instance_variable_set(:@active, gone_page)
      ball.instance_variable_set(:@list, gone_page.list)
      ball.character_name = ""
      assert_equal false, Locator.target_valid?
    end
  end

  test "an erased person is no valid target, though the engine keeps the event on the map" do
    with_marks do
      npc = World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      Locator.step(1)
      [:@active, :@list, :@trigger].each { |iv| npc.instance_variable_set(iv, nil) }
      npc.character_name = ""
      assert_equal false, Locator.target_valid?
    end
  end

  test "hiding a wide doorway from the Ctrl+K menu hides every tile of it" do
    with_doorway do
      choosing_in_turn(2) { Locator.tag_menu }
      assert_equal [[true, true], []], [[7, 5].map { |id| PokeAccess::Tags.hidden?(1, id) }, Locator.candidates(:exits)]
    end
  end

  test "Shift+K labels every tile of a wide doorway, which is said by the label from either side" do
    with_doorway do
      answering("Porton") { Locator.rename_target }
      $game_player.x = 8
      Locator.rebuild_targets
      assert_equal ["Porton", "Porton", "Porton"], [7, 5].map { |id| PokeAccess::Tags.get(1, id) } + [Locator.target_name(Locator.target)]
    end
  end

  test "recategorising a wide doorway moves every tile of it" do
    with_doorway do
      choosing_in_turn(1, 1, 3) { Locator.tag_menu }
      assert_equal [:people, :people], [7, 5].map { |id| PokeAccess::Tags.category(1, id) }
    end
  end

  test "the Ctrl+K menu of an object offers to take its name off only while the player has named it" do
    with_marks do
      World.event(:name => "EV003", :id => 3, :x => 6, :y => 5)
      Locator.step(1)
      t = PokeAccess::I18n
      bare = choosing(3) { Locator.tag_menu }
      PokeAccess::Tags.set(1, 3, "Tendero")
      named = choosing(4) { Locator.tag_menu }
      assert_equal [[t.t(:tag_rename), t.t(:tag_recat), t.t(:tag_hide), t.t(:back)], 4], bare[0][1, 2], "unnamed"
      assert_equal [[t.t(:tag_rename), t.t(:tag_unname), t.t(:tag_recat), t.t(:tag_hide), t.t(:back)], 5], named[0][1, 2],
                   "named"
    end
  ensure
    PokeAccess::Tags.delete(1, 3)
  end

  test "the Ctrl+K menu's name removal takes the player's name off every tile of a wide doorway, and says so" do
    with_doorway do
      answering("Porton") { Locator.rename_target }
      SpeakCapture.clear
      choosing_in_turn(1) { Locator.tag_menu }
      assert_equal ["", ""], [7, 5].map { |id| PokeAccess::Tags.get(1, id).to_s }
      assert_equal [PokeAccess::I18n.t(:loc_label_removed)], SpeakCapture.lines
    end
  end

  private

  # Runs the block (inside with_marks) with a doorway two tiles wide, (6, 2) and (7, 2), to two spots side by side of
  # map 5, the player on (1, 1) and the doorway selected; its tags deleted after.
  def with_doorway
    with_marks do
      $game_map.load_grid(["##########", "#@.......#", "#........#", "##########"])
      World.touch(:id => 7, :x => 6, :y => 2, :list => [TestCmd.new(201, [0, 5, 4, 4])])
      World.touch(:id => 5, :x => 7, :y => 2, :list => [TestCmd.new(201, [0, 5, 5, 4])])
      Locator.instance_variable_set(:@cat_id, :exits)
      Locator.step(1)
      yield
    end
  ensure
    [7, 5].each { |id| PokeAccess::Tags.delete(1, id) }
    $game_map.clear_grid
  end

  # Runs the block with the choice messages picking the indexes given in turn, then going back (3); returns nothing.
  def choosing_in_turn(*indexes)
    real = Kernel.method(:pbMessage)
    Kernel.define_singleton_method(:pbMessage) { |_msg, _choices = nil, _cancel = nil| indexes.empty? ? 3 : indexes.shift }
    yield
  ensure
    Kernel.define_singleton_method(:pbMessage, real)
  end

  # Runs the block on map 1 with no marks stored and a $game_temp, the player at (5, 5) and the list showing all; the
  # marks wiped, the category and $game_temp put back after.
  def with_marks
    cat = Locator.instance_variable_get(:@cat_id)
    temp = $game_temp
    $game_temp = Game_Temp.new
    Locator.instance_variable_set(:@cat_id, :all)
    wipe_marks
    yield
  ensure
    wipe_marks
    $game_temp = temp
    Locator.instance_variable_set(:@cat_id, cat)
  end

  # Deletes the marks files and reloads the empty store.
  def wipe_marks
    [Marks::FILE, Marks::IMPORT, Marks::EXPORT].each { |f| File.delete(f) if File.exist?(f) }
    Marks.reload!
  end

  # Runs the block with Marks.any_on? raising, as a store that cannot be read; the real one put back after.
  def failing_store
    real = Marks.method(:any_on?)
    Marks.define_singleton_method(:any_on?) { |_mid| raise IOError, "the marks cannot be read" }
    yield
  ensure
    Marks.define_singleton_method(:any_on?, real)
  end

  # Runs the block with no map loaded, as before the game has one.
  def without_map
    was = $game_map
    $game_map = nil
    yield
  ensure
    $game_map = was
  end

  # K as the locator's key runs it: the selection made sure of, then said.
  def press_k
    Locator.ensure_target
    Locator.announce_selected(true)
  end

  # Cycles from all back to the marks, which selects the nearest.
  def select_first_mark
    Locator.cycle_category(-1)
  end

  # The number of the only target listed.
  def only_one
    PokeAccess::I18n.t(:loc_count, :n => 1, :total => 1)
  end

  # Runs the block with every pbEnterText prompt answered with answer ("" is what the engine gives for Escape); returns
  # each prompt's arguments [text, least, most, value filled in].
  def answering(answer)
    asked = []
    Object.send(:define_method, :pbEnterText) { |*args| asked.push(args); answer }
    yield
    asked
  ensure
    Object.send(:remove_method, :pbEnterText)
  end

  # Runs the block with every choice message picking index, through the Kernel.pbMessage the menus prefer; returns
  # what each message asked, as [text, choices, cancel index].
  def choosing(index)
    asked = []
    real = Kernel.method(:pbMessage)
    Kernel.define_singleton_method(:pbMessage) { |msg, choices = nil, cancel = nil| asked.push([msg, choices, cancel]); index }
    yield
    asked
  ensure
    Kernel.define_singleton_method(:pbMessage, real)
  end
end
