# The Ready Menu's second half: the owner beside a move row and the quantity beside an item row.
#
# Twice wrong before this. First the reader demanded four fields and read the fourth as the quantity, which
# no game puts there. Then it asked the WINDOW for the tuple -- and the window never has one: the scene
# builds its lists out of tuple[1] alone (Essentials 016_UI/016_UI_ReadyMenu.rb:108-113, same in the nine
# games that ship the screen), so what came back was a String and the extra was silently dropped. Both times
# the spec passed, because it fed the tuples straight into the window.
#
# So the doubles here are shaped like the real screen: NAMES in the window, tuples on the scene, and the
# cursor split across the two lists exactly as @index is.
Suite.define("ready menu: an item row says how many are left, a move row says whose it is") do
  rm = PokeAccess::ReadyMenu
  win_class = Class.new do
    attr_accessor :commands, :index
    def initialize(names); @commands = names; @index = 0; end
  end
  scene_class = Class.new do
    def initialize(cmds, index); @commands = cmds; @index = index; end
  end
  moves = [[:FLY, "Vuelo", true, 0]]
  items = [[:POTION, "Pocion"], [:REPEL, "Repelente"]]

  bag = Object.new
  def bag.pbQuantity(id); { :POTION => 5, :REPEL => 1, :BICYCLE => 1 }[id].to_i; end
  old_bag = (defined?($PokemonBag) ? $PokemonBag : nil)
  begin
    $PokemonBag = bag

    scene = scene_class.new([moves, items], [0, 0, 1])
    win = win_class.new(items.map { |e| e[1] })
    eq "an item row says its quantity the way the bag says it", rm.row_text(scene, win, "Pocion"),
       PokeAccess::I18n.t(:bag_item, :name => "Pocion", :qty => 5)
    win.index = 1
    eq "and the next one says its own", rm.row_text(scene, win, "Repelente"),
       PokeAccess::I18n.t(:bag_item, :name => "Repelente", :qty => 1)

    # A move row names the party member whose move it is: the screen lists one row per member that knows
    # it, so the owner is the only thing being chosen.
    who = Object.new
    def who.name; "Chispa"; end
    trainer = PokeAccess::Engine.player
    trainer.define_singleton_method(:party) { [who] } unless trainer.respond_to?(:party)
    if trainer.respond_to?(:party)
      mscene = scene_class.new([moves, items], [0, 0, 0])
      mwin = win_class.new(moves.map { |e| e[1] })
      eq "crossing to the move list says which member is being chosen",
         rm.row_text(mscene, mwin, "Vuelo"), "Vuelo, #{trainer.party[0].name}"
    end

    # The one game that never split the screen keeps a flat list and an integer cursor.
    flat = scene_class.new(items, 1)
    fwin = win_class.new(items.map { |e| e[1] })
    fwin.index = 1
    eq "the flat shape reads the same", rm.row_text(flat, fwin, "Repelente"),
       PokeAccess::I18n.t(:bag_item, :name => "Repelente", :qty => 1)

    win.index = 9
    eq "an index past the list leaves the name alone", rm.row_text(scene, win, "Pocion"), "Pocion"
    bare = scene_class.new(nil, nil)
    eq "and a scene with no tuples at all is not an error", rm.row_text(bare, win, "Pocion"), "Pocion"
  ensure
    $PokemonBag = old_bag
  end
end

Suite.define("ready menu: an important item shows no quantity, as its screen does not") do
  rm = PokeAccess::ReadyMenu
  m = PokeAccess::Menus
  saved = m.method(:bag_hides_qty?)
  begin
    m.define_singleton_method(:bag_hides_qty?) { |id| id == :BICYCLE }
    falsy "an important item has no number beside it", rm.item_quantity(:BICYCLE)
    bag = Object.new
    def bag.pbQuantity(id); 7; end
    old = (defined?($PokemonBag) ? $PokemonBag : nil)
    begin
      $PokemonBag = bag
      eq "an ordinary one does", rm.item_quantity(:POTION), 7
      falsy "and a bag that answers nothing is not guessed at", rm.item_quantity(nil)
    ensure
      $PokemonBag = old
    end
  ensure
    m.define_singleton_method(:bag_hides_qty?, saved)
  end
end
