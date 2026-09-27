# The Sky-fork bag decorators (plugins/sky_bag.rb): the machine name and the favourite mark reach the row and the
# per-frame witness through Menus.bag_decorators; an adapter without the fork methods keeps the vanilla row.
class SkyBagSpecBag
  attr_reader :pockets
  def initialize(pockets, favs); @pockets = pockets; @favs = favs; end
  def favourite?(item); @favs.include?(item); end
end

class SkyBagSpecAdapter
  def initialize(machines); @machines = machines; end
  def getDisplayName(item); item.to_s; end
  def getDescription(_item); ""; end
  def getDisplayNameMachineName(item); (@machines[item] || [item.to_s, item.to_s])[1]; end
  def getDisplayNameMachineNumber(item); (@machines[item] || [item.to_s, item.to_s])[0]; end
end

class SkyBagSpecWindow
  attr_accessor :index
  def initialize(bag, adapter); @bag = bag; @adapter = adapter; @index = 0; end
  def pocket; 1; end
  def itemCount; @bag.pockets[1].length + 1; end
end

Suite.define("sky bag: the machine name and the favourite mark decorate the row, and the witness sees them") do
  bag = SkyBagSpecBag.new({ 1 => [[:TM01, 1], [:POTION, 3]] }, [:POTION])
  win = SkyBagSpecWindow.new(bag, SkyBagSpecAdapter.new({ :TM01 => ["MT01", "Puno Dinamico"] }))
  truthy "the plugin registered its decorator", PokeAccess::Menus.bag_decorators.include?(PokeAccess::SkyBag)
  row = PokeAccess::Menus.bag_row(win, 0)
  truthy "a machine is named by number and move: #{row}", row.include?("MT01 Puno Dinamico")
  fav = PokeAccess::Menus.bag_row(win, 1)
  truthy "a favourite carries its mark: #{fav}", fav.include?(PokeAccess::I18n.t(:mb_favourite))
  truthy "and a plain item, for which both fork helpers answer its name, is named ONCE: #{fav}",
         fav.index("POTION") == 0 && !fav.include?("POTION POTION")
  truthy "and a plain item does not", !row.include?(PokeAccess::I18n.t(:mb_favourite))
  wit = PokeAccess::Menus.bag_witness(win, 1)
  eq "the witness carries the same mark", wit[2], [:mb_favourite]
  eq "and none for the plain row", PokeAccess::Menus.bag_witness(win, 0)[2], []

  plain = SkyBagSpecWindow.new(bag, Object.new.tap { |o| o.define_singleton_method(:getDisplayName) { |i| i.to_s } })
  truthy "an adapter without the fork methods keeps the vanilla name", PokeAccess::Menus.bag_row(plain, 0).index("TM01") == 0
end

# The fork's bag scene, whose opening paints what it is given: two key hints above the pocket, the pocket and its rows.
# It stands under the game's name while this repo's plugins/sky_bag.rb loads again, then the name goes back to the bag
# another spec keeps under it: a hook binds once per class name.
class SkyBagSpecScene
  def initialize(rows); @rows = rows; end
  def pbStartScene
    pbDrawTextPositions(nil, @rows)
    :opened
  end
end

sky_bag_held = Object.const_defined?(:PokemonBag_Scene) ? Object.const_get(:PokemonBag_Scene) : nil
verbose = $VERBOSE
begin
  $VERBOSE = nil
  Object.send(:remove_const, :PokemonBag_Scene) if sky_bag_held
  Object.const_set(:PokemonBag_Scene, SkyBagSpecScene)
  load File.expand_path("../../../plugins/sky_bag.rb", File.dirname(__FILE__))
ensure
  $VERBOSE = verbose
  Object.send(:remove_const, :PokemonBag_Scene)
  Object.const_set(:PokemonBag_Scene, sky_bag_held) if sky_bag_held
end

# The fork's bag paints two key hints above its pocket as it opens ("Z: Ordenar", "D: Buscar"), which nothing else says.
Suite.define("sky bag: the key hints the bag paints as it opens are said, queued, while key hints are said") do
  hints = [["Z: Ordenar", 232, 7], ["D: Buscar", 317, 7]]
  rows = [["Objetos", 400, 10], ["Poción", 220, 50], ["x3", 480, 50]]
  SpeakCapture.clear
  eq "the bag opens as it would", SkyBagSpecScene.new(hints + rows).pbStartScene, :opened
  eq "the two hints as painted, the pocket and the rows left to their readers", SpeakCapture.log,
     [["Z: Ordenar. D: Buscar", false]]
  PokeAccess::Config.verbosity = :brief
  begin
    SpeakCapture.clear
    SkyBagSpecScene.new(hints + rows).pbStartScene
    silent "and nothing where the verbosity leaves key hints out"
  ensure
    PokeAccess::Config.verbosity = :full
  end
  SpeakCapture.clear
  SkyBagSpecScene.new(rows).pbStartScene
  silent "a bag that paints no hints says nothing more"
end
