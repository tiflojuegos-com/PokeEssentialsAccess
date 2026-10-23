# Rejuvenation's bag (games/rejuvenation/bag_favourites.rb): a starred item's row carries the favourite mark, in its
# pocket and in the favourites one; a star under a still cursor, with nothing said, says the row again at once, a toss
# or use queued behind the message the game shows with it.
Harness.load_common("rv_common")

# Rejuvenation's bag: pockets of bare ids with their counts in the contents table, Z's stars, and pocket 9 gathering
# the starred items through getPocketItems.
class RVEngineFavBag
  FAVORITES = 9
  attr_reader :pockets, :contents
  def initialize(pockets, contents, favs); @pockets = pockets; @contents = contents; @favs = favs; end
  def isFavorite?(item); @favs.include?(item); end
  def addFavorite(item); @favs.push(item) unless isFavorite?(item); end
  def getPocketItems(pocket); pocket == FAVORITES ? @pockets.flatten.select { |i| isFavorite?(i) } : @pockets[pocket]; end
end

# The bag's item list under the name the bag reader binds, as Essentials defines it.
class Window_PokemonBag < Window_DrawableCommand; end

# Rejuvenation's list: the pocket on show, its focused item and its rows (the items, then the one that closes the bag).
class RVEngineFavBagWindow < Window_PokemonBag
  attr_reader :pocket
  def initialize(bag, pocket); super(); @bag = bag; @pocket = pocket; end
  def itemCount; @bag.getPocketItems(@pocket).length + 1; end
  def item; @bag.getPocketItems(@pocket)[index]; end
end

class RejuvenationBagTest < PokeAccessTest
  PROFILE = File.join(Harness::ROOT, "games", "rejuvenation", "bag_favourites.rb")
  NAMES = { :POTION => "Potion", :REPEL => "Repel" }
  POCKETS = [[].freeze, [:POTION, :REPEL].freeze].freeze
  COUNTS = { :POTION => 3, :REPEL => 1 }.freeze

  test "an item not starred is said without the mark" do
    with_favourites do
      window(bag([:REPEL]), 1).update
      assert_equal [["Potion: 3, #{list_place(1, 3)}", false]], SpeakCapture.log
    end
  end

  test "a starred item is said with the favourite mark" do
    with_favourites do
      window(bag([:POTION]), 1).update
      assert_equal [["Potion: 3, #{PokeAccess::I18n.t(:mb_favourite)}, #{list_place(1, 3)}", false]], SpeakCapture.log
    end
  end

  test "a bag without the game's favourites, or one whose check fails, is read without the mark" do
    plain = Class.new(RVEngineFavBag) { undef_method :isFavorite? }
    failing = Class.new(RVEngineFavBag) { def isFavorite?(_item); raise ArgumentError, "sin favoritos"; end }
    with_favourites do
      { "a bag without them" => plain, "a failing check" => failing }.each do |what, kind|
        window(bag([:POTION], kind), 1).update
        assert_equal [["Potion: 3, #{list_place(1, 3)}", false]], SpeakCapture.log, "for #{what}"
        SpeakCapture.clear
      end
    end
  end

  test "Z's star under a still cursor, with nothing said, says the row again at once, with the mark" do
    with_favourites do
      unstarred = bag([])
      win = window(unstarred, 1)
      win.update
      SpeakCapture.clear
      win.update
      assert_nothing_spoken "with nothing changed, the row is not said again"
      unstarred.addFavorite(:POTION)
      win.update
      assert_equal [["Potion: 3, #{PokeAccess::I18n.t(:mb_favourite)}, #{list_place(1, 3)}", true]], SpeakCapture.log
    end
  end

  test "the favourites pocket reads its starred items with their counts and the mark" do
    with_favourites do
      win = window(bag([:POTION, :REPEL]), RVEngineFavBag::FAVORITES)
      win.index = 1
      win.update
      assert_equal [["Repel: 1, #{PokeAccess::I18n.t(:mb_favourite)}, #{list_place(2, 3)}", false]], SpeakCapture.log
    end
  end

  test "a toss under a still cursor says the row again, queued behind the game's message" do
    with_favourites do
      held = bag([])
      win = window(held, 1)
      win.update
      SpeakCapture.clear
      toss(held, :POTION, "Threw away 1 Potion.")
      win.update
      assert_equal [["Threw away 1 Potion.", false], ["Potion: 2, #{list_place(1, 3)}", false]], SpeakCapture.log
    end
  end

  test "a toss under a still cursor in the favourites pocket says the row again, queued behind the game's message" do
    with_favourites do
      starred = bag([:POTION, :REPEL], RVEngineFavBag, :POTION => 3, :REPEL => 2)
      win = window(starred, RVEngineFavBag::FAVORITES)
      win.index = 1
      win.update
      SpeakCapture.clear
      toss(starred, :REPEL, "Threw away 1 Repel.")
      win.update
      assert_equal [["Threw away 1 Repel.", false],
                    ["Repel: 1, #{PokeAccess::I18n.t(:mb_favourite)}, #{list_place(2, 3)}", false]], SpeakCapture.log
    end
  end

  test "the last one of an item used under a still cursor says the item that slides into its place, queued" do
    with_favourites do
      held = bag([], RVEngineFavBag, :POTION => 1, :REPEL => 1)
      win = window(held, 1)
      win.update
      SpeakCapture.clear
      PokeAccess.say_screen_message(["Pikachu's HP was restored by 20 points."])
      held.pockets[1].delete(:POTION)
      held.contents.delete(:POTION)
      win.update
      assert_equal [["Pikachu's HP was restored by 20 points.", false], ["Repel: 1, #{list_place(1, 2)}", false]],
                   SpeakCapture.log
    end
  end

  private

  # A bag of kind holding a Potion and a Repel in pocket 1 with those counts, favs starred; its pockets and counts are
  # copies, free to change.
  def bag(favs, kind = RVEngineFavBag, counts = COUNTS)
    kind.new(POCKETS.map { |pocket| pocket.dup }, counts.dup, favs)
  end

  # The bag's list on a pocket.
  def window(bag, pocket)
    RVEngineFavBagWindow.new(bag, pocket)
  end

  # The toss of one item as the game orders it (rejuvenation/Bag.rb:1300-1302): its message said, then the count taken.
  def toss(bag, item, message)
    PokeAccess.say_screen_message([message])
    bag.contents[item] -= 1
  end

  # Runs the block with Rejuvenation's profile evaluated as boot does and the engine's data provider naming items
  # through the game's getItemName; the bag decorators and the provider are put back after.
  def with_favourites
    decorators = PokeAccess::Menus.bag_decorators
    was = decorators.dup
    eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
    Harness.with_provider(PokeAccess::DataRV) do
      GameFunctions.with(:getItemName => lambda { |item| NAMES[item].to_s }) { yield }
    end
  ensure
    decorators.replace(was)
  end
end
