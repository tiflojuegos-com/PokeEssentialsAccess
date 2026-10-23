# Reminiscencia's bag (games/reminiscencia/bag.rb), read by its own per-frame poll while either of its loops runs: the
# focused item as the pocket or the row changes, the pocket named on a switch (the Special pocket with the rogue items
# it holds against their limit), its item window claimed from the generic reader, which would say every row again, and
# the watcher's section of the diagnostic dump.
class PokemonBag_Scene
  attr_reader :watched
  def initialize(win = nil); @sprites = { "itemwindow" => win }; end
  def pbChooseItem; @watched = PokeAccess::ReminBag.watching?; 0; end
  def pbCheckItem; @watched = PokeAccess::ReminBag.watching?; 0; end
end
remin_bag_path = File.join(Harness::ROOT, "games", "reminiscencia", "bag.rb")
eval(Harness.source(remin_bag_path), TOPLEVEL_BINDING, remin_bag_path)

class ReminBagTest < PokeAccessTest
  # The item window as the bag scene holds it: the pocket it shows, its row, the bag it lists, its display names.
  class ItemWindow
    attr_accessor :pocket, :index
    def initialize(bag, pocket, index = 0); @bag = bag; @pocket = pocket; @index = index; @adapter = Names.new; end
  end

  # The names the bag paints (its adapter's getDisplayName).
  class Names
    def getDisplayName(item); { :POTION => "Poción", :ANTIDOTE => "Antídoto", :ROGUEGEM => "Gema" }[item]; end
  end

  Bag = Struct.new(:pockets)
  POCKETS = [nil, [[:POTION, 3], [:ANTIDOTE, 1]], [], [[:ROGUEGEM, 1]]]
  POCKET_NAMES = ["", "Objetos", "Medicinas", "Especial"]
  RogueBag = Struct.new(:getRogueItemCount)
  RoguePlayer = Struct.new(:rogueItemLimit)

  test "claims the item window from the generic reader once it watches the bag" do
    win = item_window(1)
    refute PokeAccess.dedicated?(win), "the window is nobody's before"
    watching(win) { assert PokeAccess.dedicated?(win), "and the bag's reader's while it watches" }
  end

  test "names the Special pocket with the rogue items it holds against their limit" do
    with_pocket_names do
      with_rogue_counts(3, 15) do
        assert_equal "Especial, #{PokeAccess::I18n.t(:list_pos, :i => 3, :n => 15)}. ",
                     PokeAccess::ReminBag.pocket_prefix(item_window(3))
      end
    end
  end

  test "names the Special pocket alone while its count or its limit is unknown" do
    with_pocket_names do
      [[nil, 15], [3, nil]].each do |count, limit|
        with_rogue_counts(count, limit) do
          assert_equal "Especial. ", PokeAccess::ReminBag.pocket_prefix(item_window(3)), "count #{count.inspect}, limit #{limit.inspect}"
        end
      end
    end
  end

  test "names any other pocket alone, and no pocket already said" do
    with_pocket_names do
      with_rogue_counts(3, 15) do
        win = item_window(1)
        assert_equal "Objetos. ", PokeAccess::ReminBag.pocket_prefix(win), "another pocket"
        win.pocket = 3
        PokeAccess::Menus.mark_bag_pocket(win)
        assert_equal "", PokeAccess::ReminBag.pocket_prefix(win), "the Special pocket, once said"
      end
    end
  end

  test "reads the focused item with its pocket's name as the bag opens, then each row once" do
    with_pocket_names do
      win = item_window(1)
      watching(win) do
        2.times { PokeAccess::ReminBag.poll }
        win.index = 1
        PokeAccess::ReminBag.poll
      end
      assert_equal [["Objetos. Poción: 3, #{list_place(1, 3)}", true], ["Antídoto: 1, #{list_place(2, 3)}", true]],
                   SpeakCapture.log
    end
  end

  test "names the pocket again when the bag switches to another" do
    with_pocket_names do
      with_rogue_counts(1, 15) do
        win = item_window(1)
        watching(win) do
          PokeAccess::ReminBag.poll
          SpeakCapture.clear
          win.pocket = 3
          PokeAccess::ReminBag.poll
        end
        assert_equal ["Especial, #{PokeAccess::I18n.t(:list_pos, :i => 1, :n => 15)}. Gema: 1, #{list_place(1, 2)}"],
                     SpeakCapture.lines
      end
    end
  end

  test "reads nothing with no bag watched, no item window, or the cursor off the list" do
    win = item_window(1)
    PokeAccess::ReminBag.poll
    watching(nil) { PokeAccess::ReminBag.poll }
    [nil, -1].each do |idx|
      win.index = idx
      watching(win) { PokeAccess::ReminBag.poll }
    end
    assert_nothing_spoken
  end

  test "reads the focused item again each time the bag opens" do
    with_pocket_names do
      2.times { watching(item_window(1)) { PokeAccess::ReminBag.poll } }
      assert_equal ["Objetos. Poción: 3, #{list_place(1, 3)}"] * 2, SpeakCapture.lines
    end
  end

  test "the diagnostic dump tells whether the bag is watched, its last row and the window it reads" do
    win = item_window(1)
    assert_equal ["reminbag: watching=false last=nil"], diag_lines, "no bag watched"
    watching(win) do
      PokeAccess::ReminBag.poll
      assert_equal ["reminbag: watching=true last=[1, \"Poción: 3, #{list_place(1, 3)}\"]",
                    "  itemwindow=ReminBagTest::ItemWindow idx=0 pocket=1 adapter=ReminBagTest::Names",
                    "  focused_text=nil"], diag_lines, "a bag watched, its window one the core has no row reader for"
    end
    watching(nil) do
      assert_equal ["reminbag: watching=true last=nil",
                    "  itemwindow=nil idx=ERR(NoMethodError) pocket=ERR(NoMethodError) adapter=NilClass"], diag_lines,
                   "a bag watched before its item window is there"
    end
  end

  test "watches the bag while either of its loops runs, and only then" do
    [:pbChooseItem, :pbCheckItem].each do |loop_name|
      scene = PokemonBag_Scene.new(item_window(1))
      assert_equal 0, scene.send(loop_name), "#{loop_name} returns as the game's"
      assert_equal true, scene.watched, "#{loop_name}: watched inside"
      assert_equal false, PokeAccess::ReminBag.watching?, "#{loop_name}: let go after"
    end
  end

  private

  # An item window over the test bag, on pocket at row index.
  def item_window(pocket, index = 0)
    ItemWindow.new(Bag.new(POCKETS), pocket, index)
  end

  # The bag watcher's section of the diagnostic dump, line by line.
  def diag_lines
    PokeAccess::Keys.diag_build([:reminbag]).split("\n").drop(1)
  end

  # Runs the block with the bag's reader watching a scene whose item window is win, and stops it after.
  def watching(win)
    PokeAccess::ReminBag.watch(PokemonBag_Scene.new(win))
    yield
  ensure
    PokeAccess::ReminBag.unwatch
  end

  # Runs the block with the bag's pocket names (PokemonBag.pocketNames) as the game paints them, put back after.
  def with_pocket_names
    made = !Object.const_defined?(:PokemonBag)
    Object.const_set(:PokemonBag, Class.new) if made
    meta = PokemonBag.singleton_class
    had = meta.method_defined?(:pocketNames)
    meta.send(:alias_method, :remin_test_pocket_names, :pocketNames) if had
    names = POCKET_NAMES
    meta.send(:define_method, :pocketNames) { names }
    yield
  ensure
    if had
      meta.send(:alias_method, :pocketNames, :remin_test_pocket_names)
      meta.send(:remove_method, :remin_test_pocket_names)
    else
      meta.send(:remove_method, :pocketNames)
    end
    Object.send(:remove_const, :PokemonBag) if made
  end

  # Runs the block with the bag holding count rogue items against the player's limit (nil: one unknown).
  def with_rogue_counts(count, limit)
    saved = [$PokemonBag, $Trainer]
    $PokemonBag = count.nil? ? Object.new : RogueBag.new(count)
    $Trainer = limit.nil? ? Object.new : RoguePlayer.new(limit)
    yield
  ensure
    $PokemonBag, $Trainer = saved
  end
end
