# Soulstones 2's bag sort (V, A to Z and Z to A in turn): the direction said as it lands, then the list's first row,
# queued, even when the sort leaves the same item on it.

# The game's bag: one pocket, sorted by name, each press the other way round.
class SS2SortBag
  attr_reader :pockets
  def initialize(pockets); @pockets = pockets; @descending_sort = false; end

  def sort_pocket_alphabetically
    sorted = @pockets[1].sort_by { |e| e[0].to_s }
    sorted.reverse! if @descending_sort
    @descending_sort = !@descending_sort
    @pockets[1] = sorted
  end
end

# The bag's item list, its rows the pocket's item names.
class SS2SortList < Window_DrawableCommand
  attr_reader :pocket
  def initialize(bag); super([]); @bag = bag; @pocket = 1; sync; end
  def sync; @commands = @bag.pockets[1].map { |e| e[0].to_s }; end
end

# The bag screen: an item choice runs what the test hands it, as the game runs its key presses inside one.
class SS2SortScene
  attr_accessor :on_choose
  def initialize(bag); @sprites = { "itemlist" => SS2SortList.new(bag) }; end
  def list; @sprites["itemlist"]; end
  def pbChooseItem; @on_choose.call if @on_choose; end
end

# The profile file, evaluated once over the stand-ins above, put under the game's class names while its hooks bind;
# the names and the profile's name are taken back after.
ss2_sort_names = [:PokemonBag, :PokemonBag_Scene]
ss2_sort_held = ss2_sort_names.map { |c| Object.const_defined?(c) ? Object.const_get(c) : nil }
ss2_sort_profiles = PokeAccess::Game.profiles.dup
begin
  ss2_sort_names.each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
  Object.const_set(:PokemonBag, SS2SortBag)
  Object.const_set(:PokemonBag_Scene, SS2SortScene)
  ss2_sort_path = File.join(Harness::ROOT, "games", "soulstones2", "bag_sort.rb")
  eval(Harness.source(ss2_sort_path), TOPLEVEL_BINDING, ss2_sort_path)
ensure
  ss2_sort_names.each { |c| Object.send(:remove_const, c) if Object.const_defined?(c) }
  ss2_sort_names.zip(ss2_sort_held).each { |c, k| Object.const_set(c, k) if k }
  PokeAccess::Game.profiles.replace(ss2_sort_profiles)
end

class Ss2BagSortGdTest < PokeAccessTest
  test "says A to Z as the first sort lands, then the first row again though it holds the same item, queued" do
    bag, scene = opened
    press_sort(bag, scene)
    assert_equal [[PokeAccess::I18n.t(:bag_sorted_az), true], ["Antidote", false]], SpeakCapture.log
  end

  test "sorts Z to A on the next press, and says so before the new first row" do
    bag, scene = opened
    press_sort(bag, scene)
    SpeakCapture.clear
    press_sort(bag, scene)
    assert_equal [[PokeAccess::I18n.t(:bag_sorted_za), true], ["Repel", false]], SpeakCapture.log
  end

  test "says the direction alone for a sort with no item choice running" do
    bag, _scene = opened
    bag.sort_pocket_alphabetically
    assert_equal [[PokeAccess::I18n.t(:bag_sorted_az), true]], SpeakCapture.log
  end

  test "hands the outer item choice back when a nested one returns" do
    bag, scene = opened
    inner = SS2SortScene.new(SS2SortBag.new(1 => [["Ether", 1]]))
    scene.on_choose = lambda do
      inner.pbChooseItem
      bag.sort_pocket_alphabetically
      scene.list.sync
      scene.list.update
    end
    scene.pbChooseItem
    assert_equal [[PokeAccess::I18n.t(:bag_sorted_az), true], ["Antidote", false]], SpeakCapture.log
  end

  private

  # A bag of three items whose list was read on its first row inside an item choice, the speech cleared after.
  def opened
    bag = SS2SortBag.new(1 => [["Antidote", 1], ["Repel", 3], ["Potion", 2]])
    scene = SS2SortScene.new(bag)
    scene.on_choose = lambda { scene.list.update }
    scene.pbChooseItem
    SpeakCapture.clear
    [bag, scene]
  end

  # Presses the sort key inside the scene's item choice: the bag sorts, and the list follows it onto its first row.
  def press_sort(bag, scene)
    scene.on_choose = lambda do
      bag.sort_pocket_alphabetically
      scene.list.sync
      scene.list.index = 0
      scene.list.update
    end
    scene.pbChooseItem
  end
end
