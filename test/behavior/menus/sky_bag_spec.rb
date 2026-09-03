# The Sky-fork bag decorators (plugins/sky_bag.rb): the machine name and the favourite mark reach the row
# through Menus.bag_decorators, and the per-frame witness carries the mark so toggling a favourite on the
# focused item re-reads it. Core probes none of it: an adapter without the fork methods keeps the vanilla row.
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
