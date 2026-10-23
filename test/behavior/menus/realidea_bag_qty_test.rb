# Realidea's bag (games/realidea/bag_qty.rb): the one key item its own vercantidad helper accepts, the Paper, keeps the
# count the bag paints; every other item keeps the core's rule, which hides a key item's count.
class RealideaBagQtyTest < PokeAccessTest
  PROFILE = File.join(Harness::ROOT, "games", "realidea", "bag_qty.rb")
  KEY_ITEMS = [:PAPEL, :BICI]

  test "the Paper shows its count, other key items hide theirs and ordinary items show theirs" do
    with_realidea(lambda { |item| item == :PAPEL }) do
      { :PAPEL => false, :BICI => true, :POCION => false }.each do |item, hidden|
        assert_equal hidden, PokeAccess::Menus.bag_hides_qty?(item), "for #{item}"
      end
    end
  end

  test "where the game's own helper fails, the core's rule stands" do
    with_realidea(lambda { |_item| raise ArgumentError, "sin cantidad" }) do
      assert_equal true, PokeAccess::Menus.bag_hides_qty?(:PAPEL), "the Paper, a key item, hides its count"
    end
  end

  private

  # Runs the block with Realidea's profile evaluated as boot does, vercantidad answering through counted and the key
  # items above as pbIsImportantItem? names them; the core's bag_hides_qty?, the game's functions, the overrides
  # listed and the profiles declared are put back after.
  def with_realidea(counted)
    core = PokeAccess::Menus.method(:bag_hides_qty?)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    important = lambda { |item| KEY_ITEMS.include?(item) }
    GameFunctions.with(:vercantidad => counted, :pbIsImportantItem? => important) do
      eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
      yield
    end
  ensure
    PokeAccess::Menus.define_singleton_method(:bag_hides_qty?, core)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    PokeAccess::Game.profiles.replace(profiles)
  end
end
