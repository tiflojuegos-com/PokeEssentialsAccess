# Elite Battle: DX's battle bag (plugins/ebdx.rb), as Golden Crown runs it (Dark Horizon's "Bag Screen with
# interactable Party" replaces it): read by where its selector sits, the four pocket buttons by the game's pocket
# names, the last-used item and back, a pocket's items under its name and page, and the use/don't-use confirmation
# after the item's description.
require File.expand_path("ebdx_stand_ins", File.dirname(__FILE__))

class EbdxBagGdTest < PokeAccessTest
  T = PokeAccess::I18n
  # The game's pocket names, Settings.bag_pocket_names, with the unused 0.
  POCKETS = ["", "Items", "Medicine", "Poké Balls", "TMs & HMs", "Berries", "Mail", "Battle Items", "Key Items"]
  # The same names as a v21 game keeps them, from the Items pocket on.
  POCKETS_V21 = POCKETS[1..-1]

  test "opening reads the focused pocket by the game's name for it, queued; moving interrupts once" do
    with_pockets do
      bag = opened
      assert_equal [["Medicine", false]], SpeakCapture.log
      SpeakCapture.clear
      point(bag, "pocket3")
      bag.update
      assert_equal [["Battle Items", true]], SpeakCapture.log
    end
  end

  test "each pocket button says the name its pocket's header paints, whatever list the game keeps" do
    said = [POCKETS, POCKETS_V21].map do |names|
      with_pockets(names) { (0..3).map { |k| PokeAccess::Ebdx.pocket_name(k) } }
    end
    assert_equal [["Medicine", "Poké Balls", "Berries", "Battle Items"],
                  ["Poké Balls", "TMs & HMs", "Mail", "Key Items"]], said
  end

  test "the last-used item's button says it with the item, and back is back" do
    with_pockets do
      bag = opened
      bag.instance_variable_set(:@lastUsed, :POTION)
      SpeakCapture.clear
      point(bag, "pocket4")
      point(bag, "pocket5")
      assert_equal ["#{T.t(:bb_last)}, ItemPOTION", T.t(:bb_back)], SpeakCapture.lines
    end
  end

  test "a pocket's items read their name and quantity, the first headed by the pocket's name and page" do
    with_pockets do
      bag = opened
      items = open_pocket(bag, 8)
      SpeakCapture.clear
      point(bag, items["0"])
      point(bag, items["1"])
      point(bag, items["6"])
      point(bag, bag.sprites["pocket5"])
      assert_equal ["Medicine, 1/2. ItemI0, x1", "ItemI1, x2", "Medicine, 2/2. ItemI6, x7", T.t(:bb_back)],
                   SpeakCapture.lines
      assert_equal :item, PokeAccess::Info.instance_variable_get(:@kind), "the info key holds the last item said"
    end
  end

  test "back on the pocket buttons and into the same pocket again, its header is said again" do
    with_pockets do
      bag = opened
      items = open_pocket(bag, 2)
      point(bag, items["0"])
      point(bag, bag.sprites["pocket0"])
      items = open_pocket(bag, 2)
      SpeakCapture.clear
      point(bag, items["0"])
      assert_equal ["Medicine, 1/1. ItemI0, x1"], SpeakCapture.lines
    end
  end

  test "an item left anchored while no pocket is open says nothing" do
    with_pockets do
      bag = opened
      items = open_pocket(bag, 2)
      bag.instance_variable_set(:@selPocket, 0)
      SpeakCapture.clear
      point(bag, items["1"])
      assert_nothing_spoken
    end
  end

  test "the confirmation says the item's description, queued, then the use and don't-use buttons" do
    with_pockets do
      bag = opened
      bag.instance_variable_set(:@ret, :POTION)
      bag.instance_variable_set(:@presses, %w[cancel confirm])
      SpeakCapture.clear
      bag.useItem?
      assert_equal [["idescPOTION", false], [T.t(:ura_bag_use), false], [T.t(:ura_bag_dont_use), true],
                    [T.t(:ura_bag_use), true]], SpeakCapture.log
    end
  end

  test "back from the confirmation, the bag reads its focused pocket again" do
    with_pockets do
      bag = opened
      bag.instance_variable_set(:@ret, :POTION)
      bag.useItem?
      SpeakCapture.clear
      Input.update
      point(bag, "pocket0")
      assert_equal [["Medicine", false]], SpeakCapture.log
    end
  end

  private

  # Runs the block with the game's pocket names (names) answering Settings.bag_pocket_names.
  def with_pockets(names = POCKETS)
    Settings.define_singleton_method(:bag_pocket_names) { names }
    yield
  ensure
    class << Settings; remove_method(:bag_pocket_names); end
  end

  # A bag shown on its first pocket, as pbItemMenu opens it, and its loop's first frame.
  def opened
    bag = BagWindowEBDX.new
    bag.show
    bag.update
    bag
  end

  # Anchors the selector on a sprite (by key or itself) as a move does, and runs the loop's frame.
  def point(bag, sprite)
    bag.sprites["sel"].target(sprite.is_a?(String) ? bag.sprites[sprite] : sprite)
    bag.update
  end

  # Opens the Medicine pocket with n items (:I0 x1, :I1 x2...), six a page, as drawPocket does; answers the item
  # sprites by slot.
  def open_pocket(bag, n)
    items = {}
    n.times { |i| items[i.to_s] = EbdxSprite.new }
    bag.instance_variable_set(:@items, items)
    bag.instance_variable_set(:@pocket, (0...n).map { |i| [:"I#{i}", i + 1] })
    bag.instance_variable_set(:@selPocket, 2)
    bag.instance_variable_set(:@pname, "Medicine")
    bag.instance_variable_set(:@pages, (n + 5) / 6)
    items
  end
end
