# A bag row's count follows the page's test (show_quantity? where the item data has it), register icon or not; a
# key item may show one (Anil's Prismatic Offerings). The PC's item storage follows the same rule.
class QtySpecBag
  attr_reader :pockets
  def initialize(pockets); @pockets = pockets; end
  def registered?(_item); false; end
end

class QtySpecWindow
  attr_accessor :index
  def initialize(bag); @bag = bag; @adapter = nil; @index = 0; end
  def pocket; 1; end
  def itemCount; @bag.pockets[1].length + 1; end
end

class Window_PokemonItemStorage; end unless defined?(Window_PokemonItemStorage)

Suite.define("bag: a count is read where the row paints one, the register icon beside it or not") do
  m = PokeAccess::Menus
  bag = QtySpecBag.new(1 => [[:KEYBIKE, 1], [:KEYQTY_OFFERING, 3], [:POTION, 5], [:REPEL, 2]])
  win = QtySpecWindow.new(bag)
  falsy "a key item shows no count", m.bag_row(win, 0).include?(": 1")
  truthy "a key item that shows one anyway is read with it", m.bag_row(win, 1).include?(": 3")
  truthy "an ordinary item is read with its count", m.bag_row(win, 2).include?(": 5")

  meta = (class << m; self; end)
  meta.send(:alias_method, :royal_spec_bag_registrable?, :bag_registrable?)
  Object.send(:define_method, :pbCanRegisterItem?) { |item| item == :REPEL }
  begin
    load File.expand_path("../../../games/royal/bag_register.rb", File.dirname(__FILE__))
    row = m.bag_row(win, 3)
    truthy "in Royal an ordinary registrable item carries the mark", row.include?(PokeAccess::I18n.t(:bag_registrable))
    truthy "and keeps the count the row paints beside the icon", row.include?(": 2")
  ensure
    meta.send(:alias_method, :bag_registrable?, :royal_spec_bag_registrable?)
    meta.send(:remove_method, :royal_spec_bag_registrable?)
    Object.send(:remove_method, :pbCanRegisterItem?)
  end
end

Suite.define("pc item storage: the count follows the same rule as the bag") do
  ad = Object.new
  def ad.getDisplayName(item); item.to_s; end
  win = Window_PokemonItemStorage.new
  win.instance_variable_set(:@bag, [[:KEYBIKE, 1], [:KEYQTY_OFFERING, 3], [:POTION, 5]])
  win.instance_variable_set(:@adapter, ad)
  def win.index; @i || 0; end
  def win.index=(v); @i = v; end
  m = PokeAccess::Menus
  eq "a key item is read without a count", m.focused_text(win), "KEYBIKE"
  win.index = 1
  eq "one that shows its count, with it", m.focused_text(win), "KEYQTY_OFFERING: 3"
  win.index = 2
  eq "and an ordinary item with its count", m.focused_text(win), "POTION: 5"
end
