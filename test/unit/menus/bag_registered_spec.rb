# Whether a bag item is registered to the ready menu (the bag's icon), in each of the five shapes fangames give it.
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

# The icon's second frame, drawn on an important item the quick menu would accept but that is not registered yet
# (pbCanRegisterItem?), said only where the game has that function.
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

# The party menu's field moves, told apart by colour alone (@colorKey 1, painted blue), are said as field moves.
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
