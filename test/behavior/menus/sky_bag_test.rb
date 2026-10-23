# La Base de Sky's bag extras (plugins/sky_bag.rb): machines named by number and move, the favourite mark on the row
# and in the per-frame witness, the vanilla name without the fork's helpers, and the opening's key hints.

# The fork's bag scene, whose opening paints the rows it is given.
class SkyBagOpeningScene
  def initialize(rows); @rows = rows; end

  def pbStartScene
    pbDrawTextPositions(nil, @rows)
    :opened
  end
end

# No stub has the game's PokemonBag_Scene, so the plugin's opening hook bound nothing at boot: the plugin's
# registrations (the file from its bag_decorators line on) are evaluated once more with the scene above under the
# game's name, its module kept as boot left it, so the rows below also pin that a second evaluation adds the decorator
# no second time. The name then goes back to whatever held it, as a hook binds once per class name.
sky_bag_held = Object.const_defined?(:PokemonBag_Scene) ? Object.const_get(:PokemonBag_Scene) : nil
begin
  Object.send(:remove_const, :PokemonBag_Scene) if sky_bag_held
  Object.const_set(:PokemonBag_Scene, SkyBagOpeningScene)
  sky_bag_path = File.join(Harness::ROOT, "plugins", "sky_bag.rb")
  sky_bag_src = Harness.source(sky_bag_path)
  sky_bag_at = sky_bag_src.index(/^PokeAccess::Menus\.bag_decorators/)
  eval(sky_bag_src[sky_bag_at..-1], TOPLEVEL_BINDING, sky_bag_path, sky_bag_src[0, sky_bag_at].count("\n") + 1)
ensure
  Object.send(:remove_const, :PokemonBag_Scene)
  Object.const_set(:PokemonBag_Scene, sky_bag_held) if sky_bag_held
end

class SkyBagTest < PokeAccessTest
  # A bag whose pocket 1 holds a machine, a favourite potion and a plain repel.
  class Bag
    attr_reader :pockets
    def initialize; @pockets = { 1 => [[:TM01, 1], [:POTION, 3], [:REPEL, 2]] }; end
    def favourite?(item); item == :POTION; end
  end

  # The fork's mart adapter: a machine's number and move name; for any other item, both helpers answer its name.
  class ForkAdapter
    MACHINES = { :TM01 => ["MT01", "Puno Dinamico"] }
    def getDisplayName(item); item.to_s; end
    def getDescription(_item); ""; end
    def getDisplayNameMachineName(item); (MACHINES[item] || [item.to_s, item.to_s])[1]; end
    def getDisplayNameMachineNumber(item); (MACHINES[item] || [item.to_s, item.to_s])[0]; end
  end

  # An adapter whose machine helpers answer the given move name and number.
  class HelperAdapter
    def initialize(name, number); @name = name; @number = number; end
    def getDisplayNameMachineName(_item); @name; end
    def getDisplayNameMachineNumber(_item); @number; end
  end

  # The vanilla adapter, which names an item and nothing more.
  class PlainAdapter
    def getDisplayName(item); item.to_s; end
  end

  # The bag's item list on pocket 1, its close row after the items.
  class ItemList
    attr_accessor :index
    def initialize(bag, adapter); @bag = bag; @adapter = adapter; @index = 0; end
    def pocket; 1; end
    def itemCount; @bag.pockets[1].length + 1; end
  end

  # A bag whose favourites check raises.
  class BrokenBag
    def favourite?(_item); raise "no favourites yet"; end
  end

  HINTS = [["Z: Ordenar", 232, 7], ["D: Buscar", 317, 7]]
  ROWS = [["Objetos", 400, 10], ["Poción", 220, 50], ["x3", 480, 50]]

  test "names a machine by its number and move" do
    assert_equal "MT01 Puno Dinamico: 1, #{list_place(1, 4)}", row(ForkAdapter.new, 0)
  end

  test "marks a favourite after its name and count" do
    assert_equal "POTION: 3, #{PokeAccess::I18n.t(:mb_favourite)}, #{list_place(2, 4)}", row(ForkAdapter.new, 1)
  end

  test "names a plain item once, as both of the fork's helpers answer its name" do
    assert_equal "REPEL: 2, #{list_place(3, 4)}", row(ForkAdapter.new, 2)
  end

  test "hands the favourite mark to the per-frame witness, and none for a plain row" do
    list = ItemList.new(Bag.new, ForkAdapter.new)
    assert_equal [[:mb_favourite], []], [1, 2].map { |i| PokeAccess::Menus.bag_witness(list, i)[2] }
  end

  test "keeps the vanilla name where the adapter lacks the fork's helpers" do
    assert_equal "TM01: 1, #{list_place(1, 4)}", row(PlainAdapter.new, 0)
  end

  test "names no machine where a helper answers nothing, or there is no adapter" do
    { HelperAdapter.new("Puno Dinamico", "") => nil, HelperAdapter.new("", "MT01") => nil,
      HelperAdapter.new(nil, "MT01") => nil, nil => nil,
      HelperAdapter.new("Puno Dinamico", "MT01") => "MT01 Puno Dinamico" }.each do |adapter, want|
      got = PokeAccess::SkyBag.name(adapter, :TM01)
      want ? assert_equal(want, got) : assert_nil(got, "for #{adapter.inspect}")
    end
  end

  test "marks no favourite on a bag that cannot tell them" do
    [Object.new, BrokenBag.new].each { |bag| assert_equal [], PokeAccess::SkyBag.marks(bag, :POTION), bag.class.to_s }
  end

  test "says the key hints the bag paints as it opens, queued, and the bag opens as it would" do
    assert_equal :opened, SkyBagOpeningScene.new(HINTS + ROWS).pbStartScene
    assert_equal [["Z: Ordenar. D: Buscar", false]], SpeakCapture.log
  end

  test "takes as a key hint a key letter, or letters joined by a slash, a colon and what it does" do
    rows = [["A/S: Cambiar", 232, 7], ["Z:", 300, 7], ["ZR: algo", 340, 7], ["x3", 480, 50]]
    SkyBagOpeningScene.new(rows).pbStartScene
    assert_equal [["A/S: Cambiar", false]], SpeakCapture.log
  end

  test "says no key hints where the verbosity leaves them out" do
    PokeAccess::Config.verbosity = :brief
    SkyBagOpeningScene.new(HINTS + ROWS).pbStartScene
    assert_nothing_spoken
  end

  test "says nothing more for a bag that paints no hints" do
    SkyBagOpeningScene.new(ROWS).pbStartScene
    assert_nothing_spoken
  end

  private

  # The bag reader's row i of the pocket, through the given adapter.
  def row(adapter, i)
    PokeAccess::Menus.bag_row(ItemList.new(Bag.new, adapter), i)
  end
end
