# Whether a bag item is REGISTERED to the ready menu, which the bag marks with an icon and the row reader
# turns into a spoken word. The fangames expose it five different ways, and a shape the probe does not know
# fails the way every reader bug in this mod fails: no exception, no nil, the row simply never says
# "registered" and sounds like any other.
#
# Surveying the fifteen script dumps, four games keep it ONLY as pbIsRegistered? over a registeredItems
# array -- Fire Ash, both Infinite Fusions and Awakening, which also keeps the old single slot -- and in
# three of them the mod had never said the word.
Suite.define("bag: every shape a fangame gives the registered flag is understood") do
  m = PokeAccess::Menus

  modern = Object.new
  def modern.registered?(id); id == :BICYCLE; end
  truthy "the modern predicate", m.bag_registered?(modern, :BICYCLE)
  falsy "and it answers no for the rest", m.bag_registered?(modern, :POTION)

  plural = Object.new
  def plural.pbIsRegistered?(id); registeredItems.include?(id); end
  def plural.registeredItems; [:BICYCLE, :OLDROD]; end
  truthy "the v18 plural predicate, which four of the surveyed games are the only ones to have",
         m.bag_registered?(plural, :OLDROD)
  falsy "and it too answers no", m.bag_registered?(plural, :POTION)

  slot = Object.new
  def slot.registeredItem; :BICYCLE; end
  truthy "the gen-6 single slot", m.bag_registered?(slot, :BICYCLE)
  falsy "with one item registered, another is not", m.bag_registered?(slot, :OLDROD)

  list = Object.new
  def list.registeredItems; [:BICYCLE, :OLDROD]; end
  truthy "a bare plural list with no predicate", m.bag_registered?(list, :OLDROD)

  ivar = Object.new
  ivar.instance_variable_set(:@registeredItems, [:OLDROD])
  truthy "and the same list reached through its instance variable", m.bag_registered?(ivar, :OLDROD)

  falsy "a bag that exposes none of the five is simply not registered", m.bag_registered?(Object.new, :BICYCLE)
  falsy "and neither is a nil bag", m.bag_registered?(nil, :BICYCLE)
end

# The SECOND frame of that same icon: the bag draws it on an important item the quick menu would accept but
# that is not registered yet (fireash/285_UI_Bag.rb:86, and the same in the eight games that have the
# function). It is the only thing on the screen that says which items the menu takes, and no game read it,
# so a player had to try them one by one.
Suite.define("bag: an item the quick menu would accept says so, and only where the game draws it") do
  m = PokeAccess::Menus
  bag = Object.new
  def bag.pbIsRegistered?(id); id == :BICYCLE; end

  saved_hides = m.method(:bag_hides_qty?)
  had = Object.respond_to?(:pbCanRegisterItem?, true)
  begin
    m.define_singleton_method(:bag_hides_qty?) { |id| [:BICYCLE, :OLDROD, :BIKEVOUCHER].include?(id) }
    Object.send(:define_method, :pbCanRegisterItem?) { |id| id == :OLDROD }

    truthy "an important item the game says can be registered is announced", m.bag_registrable?(bag, :OLDROD)
    falsy "one already registered is not announced twice", m.bag_registrable?(bag, :BICYCLE)
    falsy "an important item the game will not take says nothing", m.bag_registrable?(bag, :BIKEVOUCHER)
    falsy "and an ordinary item is not important, so the icon is not drawn on it either",
          m.bag_registrable?(bag, :POTION)
  ensure
    m.define_singleton_method(:bag_hides_qty?, saved_hides)
    Object.send(:remove_method, :pbCanRegisterItem?) unless had
  end

  falsy "in a game with no such function -- seven of the fifteen -- nothing is marked, as nothing is drawn",
        m.bag_registrable?(bag, :OLDROD)
end

# The party menu's rows are the member's own FIELD MOVES and then Summary, Switch, Item, Cancel -- and the
# screen tells the two kinds apart by COLOUR alone, a @colorKey of 1 painted blue. Nine of the fifteen games
# use that window. Read through @commands, already unpacked to strings, "Fly" and "Switch" sounded the same.
Suite.define("party menu: a field move says it is one, which is all that its colour said") do
  win = Class.new do
    attr_accessor :index
    def initialize(cmds, keys); @commands = cmds; @colorKey = keys; @index = 0; end
  end
  ex = PokeAccess::Menus::EXTRACTORS.find { |c, _b| c == "Window_CommandPokemonColor" }
  truthy "the extractor is registered for the window that carries the colour", !ex.nil?
  blk = ex[1]
  w = win.new(["Vuelo", "Corte", "Datos", "Cambiar", "Salir"], [1, 1, nil, nil, nil])

  eq "a field move is named as one", blk.call(w, 0), "Vuelo, #{PokeAccess::I18n.t(:mn_field_move)}"
  eq "and so is the next", blk.call(w, 1), "Corte, #{PokeAccess::I18n.t(:mn_field_move)}"
  eq "an ordinary row is left alone", blk.call(w, 2), "Datos"
  eq "including the one that used to sound like Fly", blk.call(w, 3), "Cambiar"
  falsy "and a row past the end is not an error", blk.call(w, 9)
end
