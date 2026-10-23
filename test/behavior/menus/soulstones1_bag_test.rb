# Soulstones' own bag (games/soulstones1/bag.rb) never draws the frame the stock bag gives an item that could be
# registered, so no row is said as registrable.
class Soulstones1BagTest < PokeAccessTest
  test "says no key item as registrable, as Soulstones' bag paints no such frame" do
    bag = Object.new
    def bag.registered?(_item); false; end
    with_registrable_items do
      assert_equal true, PokeAccess::Menus.bag_registrable?(bag, 5), "the stock bag's reading marks it"
      with_soulstones_bag { assert_equal false, PokeAccess::Menus.bag_registrable?(bag, 5) }
    end
  end

  private

  # Runs the block with the engine's pbCanRegisterItem? and pbIsImportantItem? answering yes for every item.
  def with_registrable_items
    added = [:pbCanRegisterItem?, :pbIsImportantItem?].reject do |m|
      Object.method_defined?(m) || Object.private_method_defined?(m)
    end
    added.each { |m| Object.send(:define_method, m) { |_item| true } }
    yield
  ensure
    (added || []).each { |m| Object.send(:remove_method, m) }
  end

  # Runs the block with Soulstones' bag profile evaluated; its override of Menus.bag_registrable?, its entry in the
  # overrides listing and its profile name are taken back after.
  def with_soulstones_bag
    meta = PokeAccess::Menus.singleton_class
    meta.send(:alias_method, :ss1_test_registrable, :bag_registrable?)
    overrides = PokeAccess::Hooks.overrides.length
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "soulstones1", "bag.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    meta.send(:alias_method, :bag_registrable?, :ss1_test_registrable)
    meta.send(:remove_method, :ss1_test_registrable)
    PokeAccess::Hooks.overrides.slice!(overrides..-1)
    PokeAccess::Game.profiles.replace(profiles)
  end
end
