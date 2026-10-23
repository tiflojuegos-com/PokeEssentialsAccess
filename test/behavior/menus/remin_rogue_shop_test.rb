# Reminiscencia's rogue mode (switch 152, games/reminiscencia/rogue_shop.rb): its shop says the row colours as words
# (held, found before), an unidentified item's description stays unknown on the info key, and its bag hides the count
# of every rogue item. The profile is evaluated once; its two overrides stand in for the core's only inside a test.
class Window_PokemonMart; end unless defined?(Window_PokemonMart)

class ReminRogueShopTest < PokeAccessTest
  ROGUE_SHOP = File.join(Harness::ROOT, "games", "reminiscencia", "rogue_shop.rb")
  OVERRIDDEN = [:mart_marks, :bag_hides_qty?].freeze
  CORE = OVERRIDDEN.map { |m| PokeAccess::Menus.method(m) }.freeze
  eval(Harness.source(ROGUE_SHOP), TOPLEVEL_BINDING, ROGUE_SHOP)
  ROGUE = OVERRIDDEN.map { |m| PokeAccess::Menus.method(m) }.freeze
  OVERRIDDEN.zip(CORE).each { |m, core| PokeAccess::Menus.define_singleton_method(m, core) }

  # The shop's adapter: each item's name and price, and its description ("???" for one not identified yet).
  class Adapter
    def getDisplayName(item); "Objeto#{item}"; end
    def getDisplayPrice(_item); "$ 100"; end
    def getDescription(item); item == 3 ? "???" : "Cura 20 PS."; end
  end

  # The bag as pbHasItem? answers it.
  class Bag
    def initialize(items); @items = items; end
    def pbHasItem?(item); @items.include?(item); end
  end

  test "marks an item the bag holds as held, found before or not" do
    held = "Objeto1, $ 100, #{PokeAccess::I18n.t(:rem_shop_have)}"
    with_rogue_shop do
      { "never found" => [2], "found before" => [1, 2] }.each do |what, found|
        in_rogue_mode([1], found) { assert_equal held, shop_row(0), what }
      end
    end
  end

  test "marks an item found before and gone as known" do
    with_rogue_shop do
      in_rogue_mode { assert_equal "Objeto2, $ 100, #{PokeAccess::I18n.t(:rem_shop_known)}", shop_row(1) }
    end
  end

  test "leaves an item never found plain" do
    with_rogue_shop do
      in_rogue_mode { assert_equal "Objeto3, $ 100", shop_row(2) }
    end
  end

  test "marks no row outside rogue mode" do
    with_rogue_shop do
      in_rogue_mode do
        $game_switches[152] = false
        assert_equal ["Objeto1, $ 100", "Objeto2, $ 100"], [shop_row(0), shop_row(1)]
      end
    end
  end

  test "marks nothing a bag or a player that cannot answer would decide" do
    with_rogue_shop do
      in_rogue_mode(nil, nil) { assert_equal "Objeto2, $ 100", shop_row(1), "no bag, no found list" }
      in_rogue_mode(nil, lambda { raise "no save loaded" }) { assert_equal "Objeto2, $ 100", shop_row(1), "a found list that raises" }
    end
  end

  test "keeps an unidentified item's real description off the info key, saying it is unknown as the shop does" do
    with_rogue_shop do
      in_rogue_mode do
        with_real_descriptions do
          shop_row(2)
          assert_equal "#{PokeAccess::Data.item_name(3)}. #{PokeAccess::I18n.t(:pdx_unknown_short)}", PokeAccess::Info.info_text
        end
      end
    end
  end

  test "hides a rogue item's count in the bag" do
    with_rogue_shop do
      GameFunctions.with(:pbIsRogueItem? => lambda { |item| item == 3 }) do
        assert_equal true, PokeAccess::Menus.bag_hides_qty?(3)
      end
    end
  end

  test "leaves any other item's count to the core's rule" do
    with_rogue_shop do
      GameFunctions.with(:pbIsRogueItem? => lambda { |item| item == 3 }, :pbIsImportantItem? => lambda { |item| item == 5 }) do
        assert_equal [false, true], [PokeAccess::Menus.bag_hides_qty?(4), PokeAccess::Menus.bag_hides_qty?(5)]
      end
      assert_equal false, PokeAccess::Menus.bag_hides_qty?(3), "a game with no rogue items"
    end
  end

  private

  # The focused shop row at index over a stock of items 1, 2 and 3.
  def shop_row(index)
    win = Window_PokemonMart.new
    win.instance_variable_set(:@stock, [1, 2, 3])
    win.instance_variable_set(:@adapter, Adapter.new)
    win.define_singleton_method(:index) { index }
    PokeAccess::Menus.focused_text(win)
  end

  # Runs the block in rogue mode with the bag holding held and the player having found the items found gives (a list,
  # nil, or a lambda the player's found_items calls); the bag and the player's list are put back after.
  def in_rogue_mode(held = [1], found = [2])
    saved = $PokemonBag
    $game_switches[152] = true
    $PokemonBag = held ? Bag.new(held) : nil
    list = found
    $game_player.define_singleton_method(:found_items) { list.respond_to?(:call) ? list.call : list }
    yield
  ensure
    $PokemonBag = saved
    $game_player.singleton_class.send(:remove_method, :found_items)
  end

  # Runs the block with the item data holding a real description for every item, the real lookup put back after.
  def with_real_descriptions
    real = PokeAccess::Data.method(:item_description)
    PokeAccess::Data.define_singleton_method(:item_description) { |id| "Descripcion real #{id}" }
    yield
  ensure
    PokeAccess::Data.define_singleton_method(:item_description, real)
  end

  # Runs the block with the rogue shop's overrides of the shop marks and the bag's hidden counts in place of the
  # core's, which are put back after.
  def with_rogue_shop
    OVERRIDDEN.zip(ROGUE).each { |m, own| PokeAccess::Menus.define_singleton_method(m, own) }
    yield
  ensure
    OVERRIDDEN.zip(CORE).each { |m, core| PokeAccess::Menus.define_singleton_method(m, core) }
  end
end
