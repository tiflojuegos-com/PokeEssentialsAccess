# The Ready Menu's rows, said as its cursor reaches them: an item with how many the bag holds, a move with the party
# member who uses it.

class ReadyMenuTest < PokeAccessTest
  Ready = PokeAccess::ReadyMenu
  Member = Struct.new(:name)
  MOVES = [[:FLY, "Vuelo", true, 0], [:SURF, "Surf", true, 1]]
  ITEMS = [[:POTION, "Pocion", false], [:REPEL, "Repelente", false]]

  test "an item row says how many of it the bag holds" do
    with_bag(:POTION => 5, :REPEL => 1) do
      { 0 => bag_item("Pocion", 5), 1 => bag_item("Repelente", 1) }.each do |row, want|
        assert_equal want, said(split_menu(:items, row)), "item row #{row}"
      end
    end
  end

  test "a move row says the party member who uses it" do
    with_party(["Chispa", "Nube"]) do
      { 0 => "Vuelo, Chispa", 1 => "Surf, Nube" }.each do |row, want|
        assert_equal want, said(split_menu(:moves, row)), "move row #{row}"
      end
    end
  end

  test "a move whose user the party cannot name is said alone" do
    assert_equal "Vuelo", said(split_menu(:moves, 0)), "with no party to ask"
    with_party(["Chispa"]) { assert_equal "Surf", said(split_menu(:moves, 1)), "with no member at its place" }
  end

  test "the single-list shape, Pokemon Z's [id, name] items, reads its tuples the same" do
    flat = [[:POTION, "Pocion"], [:REPEL, "Repelente"]]
    with_bag(:POTION => 5, :REPEL => 1) do
      { 0 => bag_item("Pocion", 5), 1 => bag_item("Repelente", 1) }.each do |row, want|
        assert_equal want, said(menu(flat, row, ["Pocion", "Repelente"], row)), "item row #{row}"
      end
    end
  end

  test "a row with no tuple behind it is said as the window names it" do
    with_bag(:POTION => 5) do
      {
        "a row past the tuples" => [menu([MOVES, ITEMS[0, 1]], [0, 1, 1], ["Pocion", "Bici"], 1), "Bici"],
        "a scene with no tuples" => [menu(nil, nil, ["Pocion"], 0), "Pocion"],
        "a side with no list" => [menu([MOVES], [0, 0, 1], ["Pocion"], 0), "Pocion"],
        "a tuple too short to hold a name" => [menu([MOVES, [[:POTION]]], [0, 0, 1], ["Pocion"], 0), "Pocion"]
      }.each { |what, (scene, want)| assert_equal want, said(scene), what }
    end
  end

  test "an important item shows no count, as its screen shows none" do
    bike = [[:BICYCLE, "Bici", false]]
    with_bag(:BICYCLE => 1) do
      GameFunctions.with(:pbIsImportantItem? => lambda { |item| item == :BICYCLE }) do
        assert_equal "Bici", said(menu([MOVES, bike], [0, 0, 1], ["Bici"], 0))
      end
    end
  end

  test "an item the bag holds none of, or with no bag to ask, shows no count" do
    with_bag(:POTION => 0) { assert_equal "Pocion", said(split_menu(:items, 0)), "none in the bag" }
    with_bag(nil) { assert_equal "Pocion", said(split_menu(:items, 0)), "no bag" }
  end

  test "an item tuple with no id shows no count, whatever the bag answers for it" do
    scene = menu([MOVES, [[nil, "Pocion", false]]], [0, 0, 1], ["Pocion"], 0)
    with_bag(nil => 7) { assert_equal "Pocion", said(scene) }
  end

  test "the focused row is said as the cursor reaches it, interrupting, and once" do
    scene = split_menu(:items, 0)
    with_bag(:POTION => 5) do
      Ready.poll(scene)
      assert_equal [["#{side_items(2)}. #{bag_item('Pocion', 5)}", true]], SpeakCapture.log, "the row reached"
      SpeakCapture.clear
      Ready.poll(scene)
      assert_nothing_spoken "and not again while the cursor stays"
    end
  end

  test "as the menu opens and on each change of side, the column and how many entries the other holds lead the row" do
    scene = split_menu(:items, 0)
    with_party(["Chispa", "Nube"]) do
      with_bag(:POTION => 5) do
        Ready.poll(scene)
        SpeakCapture.clear
        scene.instance_variable_set(:@index, [0, 0, 0])
        window_of(scene).commands = MOVES.map { |e| e[1] }
        Ready.poll(scene)
        assert_equal [["#{PokeAccess::I18n.t(:ready_side_moves, :n => 2)}. Vuelo, Chispa", true]], SpeakCapture.log,
                     "the moves' side"
        SpeakCapture.clear
        window_of(scene).index = 1
        scene.instance_variable_set(:@index, [1, 0, 0])
        Ready.poll(scene)
        assert_equal [["Surf, Nube", true]], SpeakCapture.log, "a move within the side"
      end
    end
  end

  test "a column whose other side is empty, or the single-list shape, leads with no column" do
    with_bag(:POTION => 5) do
      Ready.poll(menu([[], ITEMS], [0, 0, 1], ["Pocion"], 0))
      Ready.poll(menu([[:POTION, "Pocion"]], 0, ["Pocion"], 0))
    end
    assert_equal [[bag_item("Pocion", 5), true]] * 2, SpeakCapture.log
  end

  test "the command loop run again after a cancelled Fly map says the focused entry once more, without its column" do
    scene = PokemonReadyMenu_Scene.new
    win = Window_DrawableCommand.new(MOVES.map { |e| e[1] })
    scene.instance_variable_set(:@sprites, { "cmdwindow" => win })
    scene.instance_variable_set(:@commands, [MOVES, ITEMS])
    scene.instance_variable_set(:@index, [0, 0, 0])
    with_party(["Chispa", "Nube"]) do
      scene.pbShowCommands
      SpeakCapture.clear
      scene.pbShowCommands
    end
    assert_equal [["Vuelo, Chispa", true]], SpeakCapture.log
  end

  test "a move of the cursor says the new row" do
    scene = split_menu(:items, 0)
    with_bag(:POTION => 5, :REPEL => 1) do
      Ready.poll(scene)
      SpeakCapture.clear
      window_of(scene).index = 1
      Ready.poll(scene)
    end
    assert_equal [[bag_item("Repelente", 1), true]], SpeakCapture.log
  end

  test "the hidden command window is left to the Ready Menu's reader" do
    scene = split_menu(:items, 0)
    with_bag(:POTION => 5, :REPEL => 1) do
      Ready.poll(scene)
      SpeakCapture.clear
      win = window_of(scene)
      win.index = 1
      win.update
      assert_nothing_spoken "the command windows' reader leaves it"
      Ready.poll(scene)
    end
    assert_equal [[bag_item("Repelente", 1), true]], SpeakCapture.log, "the Ready Menu's says it"
  end

  test "a scene without its command window, or a blank row, says nothing" do
    bare = Object.new
    blank = menu([MOVES, ITEMS], [0, 0, 1], [""], 0)
    with_bag(:POTION => 5) { [bare, blank].each { |scene| Ready.poll(scene) } }
    assert_nothing_spoken
  end

  private

  # A Ready Menu split in two lists, moves and items, focused on row of side (:moves or :items), its hidden window
  # listing that side's names as the screen syncs it.
  def split_menu(side, row)
    list = side == :moves ? MOVES : ITEMS
    index = side == :moves ? [row, 0, 0] : [0, row, 1]
    menu([MOVES, ITEMS], index, list.map { |e| e[1] }, row)
  end

  # A Ready Menu scene as the game keeps it: its tuples ([moves, items] with @index [move row, item row, side] where
  # the screen is split in two, a flat list where it is not) and its hidden command window listing only names, on row.
  def menu(commands, scene_index, names, row)
    win = Window_DrawableCommand.new(names)
    win.index = row
    scene = Object.new
    scene.instance_variable_set(:@sprites, { "cmdwindow" => win })
    scene.instance_variable_set(:@commands, commands)
    scene.instance_variable_set(:@index, scene_index)
    scene
  end

  def window_of(scene)
    scene.instance_variable_get(:@sprites)["cmdwindow"]
  end

  # What the reader says for the focused row, given the name the hidden window lists there.
  def said(scene)
    win = window_of(scene)
    Ready.row_text(scene, win, win.commands[win.index])
  end

  # Runs the block with the gen-6 bag ($PokemonBag, and no modern $bag ahead of it) holding counts ({item =>
  # quantity}), or with no bag for nil; the bags before it put back after.
  def with_bag(counts)
    was = [$bag, $PokemonBag]
    bag = nil
    if counts
      bag = Object.new
      bag.define_singleton_method(:pbQuantity) { |id| counts[id].to_i }
    end
    $bag = nil
    $PokemonBag = bag
    yield
  ensure
    $bag, $PokemonBag = was
  end

  # Runs the block with the player's party made of members with these names, the player left as it was after.
  def with_party(names)
    who = PokeAccess::Engine.player
    members = names.map { |n| Member.new(n) }
    who.define_singleton_method(:party) { members }
    yield
  ensure
    who.singleton_class.send(:remove_method, :party) if who.singleton_methods.include?(:party)
  end

  def bag_item(name, qty)
    PokeAccess::I18n.t(:bag_item, :name => name, :qty => qty)
  end

  # The items' column as it leads a row, with n moves on the other side.
  def side_items(n)
    PokeAccess::I18n.t(:ready_side_items, :n => n)
  end
end
