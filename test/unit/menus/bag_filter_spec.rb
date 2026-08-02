# Bag extractor with a choose-item filter (v21): in choose-item mode Window_PokemonBag filters the pocket
# through @filterlist and exposes the mapped id via #item, so the visual index differs from the real pocket
# index. The extractor must announce the item under the cursor (name + quantity of the RIGHT entry, not a
# neighbour) and must read the trailing row as "Close bag", never as an item. The fake window mirrors the
# real v21 API the extractor relies on: #pocket, #index, #item and #itemCount are filterlist-aware, and the
# raw pocket lives in @bag.pockets. filter keeps pocket indices [1, 3], so visual 0 -> real 1, visual 1 ->
# real 3, and visual 2 is the close row -- the exact mapping the pre-fix code got wrong.
# The bag window stand-in, at file level: it used to be built inside the FIRST suite and used by the
# second, so running them in any other order was a NameError. A fixture two suites share belongs to
# neither of them.
unless Object.const_defined?(:Window_PokemonBag)
  win_klass = Class.new do
    attr_accessor :index
    attr_reader :pocket
    def initialize(bag, filterlist, pocket, adapter)
      @bag = bag; @filterlist = filterlist; @pocket = pocket; @adapter = adapter; @index = 0
    end

    def itemCount
      (@filterlist ? @filterlist[@pocket].length : @bag.pockets[@pocket].length) + 1
    end

    def item
      return nil if @filterlist && !@filterlist[@pocket][@index]
      row = @filterlist ? @bag.pockets[@pocket][@filterlist[@pocket][@index]] : @bag.pockets[@pocket][@index]
      row ? row[0] : nil
    end
  end
  Object.const_set(:Window_PokemonBag, win_klass)
end

Suite.define("menus: filtered bag announces the mapped item, not a neighbour") do
  bag_klass = Class.new do
    attr_reader :pockets
    def initialize(pockets); @pockets = pockets; end
  end
  adapter = Class.new do
    def initialize(names); @names = names; end
    def getDisplayName(id); @names[id] || id.to_s; end
  end


  names = { :POTION => "Pocion", :REPEL => "Repelente", :RARECANDY => "Caramelo", :FULLHEAL => "Cura total" }
  pockets = { 1 => [[:POTION, 5], [:REPEL, 2], [:RARECANDY, 9], [:FULLHEAL, 1]] }
  bag = bag_klass.new(pockets)
  filterlist = { 1 => [1, 3] }
  win = Window_PokemonBag.new(bag, filterlist, 1, adapter.new(names))

  win.index = 0
  eq "visual 0 maps to real 1 (Repelente x2), not the unfiltered Pocion",
     PokeAccess::Menus.focused_text(win), "Repelente: 2"

  win.index = 1
  eq "visual 1 maps to real 3 (Cura total x1), not the unfiltered Repelente",
     PokeAccess::Menus.focused_text(win), "Cura total: 1"

  win.index = 2
  eq "the trailing row is Close bag, not an item",
     PokeAccess::Menus.focused_text(win), PokeAccess::I18n.t(:mn_close_bag)
  not_spoke_close = PokeAccess::Menus.focused_text(win)
  truthy "the close row never names a pocket item",
         !(not_spoke_close.include?("Caramelo") || not_spoke_close.include?(":"))
end

# The same extractor with no filter (normal browse) keeps reading the pocket directly by visual index, so the
# fix does not regress the common path: id and quantity come straight from @bag.pockets[pocket][index] and
# the trailing row is still Close bag.
Suite.define("menus: unfiltered bag reads the pocket directly and closes on the last row") do
  bag_klass = Class.new do
    attr_reader :pockets
    def initialize(pockets); @pockets = pockets; end
  end
  adapter = Class.new do
    def initialize(names); @names = names; end
    def getDisplayName(id); @names[id] || id.to_s; end
  end
  names = { :POTION => "Pocion", :REPEL => "Repelente" }
  pockets = { 1 => [[:POTION, 5], [:REPEL, 2]] }
  bag = bag_klass.new(pockets)
  win = Window_PokemonBag.new(bag, nil, 1, adapter.new(names))

  win.index = 0
  eq "unfiltered visual 0 is the first pocket item", PokeAccess::Menus.focused_text(win), "Pocion: 5"
  win.index = 1
  eq "unfiltered visual 1 is the second pocket item", PokeAccess::Menus.focused_text(win), "Repelente: 2"
  win.index = 2
  eq "unfiltered trailing row is Close bag",
     PokeAccess::Menus.focused_text(win), PokeAccess::I18n.t(:mn_close_bag)
end
