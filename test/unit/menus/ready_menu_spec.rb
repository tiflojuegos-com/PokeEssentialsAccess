# The Ready Menu's rows: an item's quantity and a move's owner. As in the real screen, the window holds only the
# names and the scene the tuples, the cursor split across the two lists as @index is.
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

    flat =scene_class.new(items, 1)
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
