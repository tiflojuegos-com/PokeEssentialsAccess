# Royal's ribbons page is the page of the memento the Pokemon wears (Improved Mementos): type, number, rank,
# name and conferred title, painted label by value, the rank up to four as icons.
Suite.define("improved mementos: the page is read label by value, the rank drawn as icons included") do
  x = 290
  y = 96
  paint = [["Tipo:", x + 104, y + 12], ["No. ID:", x + 104, y + 44], ["12", x + 234, y + 44],
           ["Rango:", x + 104, y + 76], ["Nombre:", x + 145, y + 116], ["Cinta Campeon", x + 145, y + 148],
           ["Titulo Conferido:", x + 145, y + 190], ["'el Campeon'", x + 145, y + 222],
           ["[C]: Ver Emblemas", x + 212, y + 268], ["Cinta", x + 213, y + 12],
           ["Pika", 46, 62]]
  pairs = paint.map { |t, px, py| [t, :positions, px, py] }
  pk = Poke.build(:name => "Pika")
  pk.define_singleton_method(:memento) { :CHAMPION }
  pk.define_singleton_method(:getMementoRank) { |_m| 3 }
  eq "each label with its value in reading order, the rank from the icons, the header and the key hint left out",
     PokeAccess::ImprovedMementos.page_text(pk, pairs),
     "Tipo: Cinta. No. ID: 12. Rango: 3. Nombre: Cinta Campeon. Titulo Conferido: 'el Campeon'"

  none = [["Tipo:", x + 104, y + 12], ["---", x + 232, y + 12], ["No. ID:", x + 104, y + 44], ["---", x + 234, y + 44],
          ["Rango:", x + 104, y + 76], ["Nombre:", x + 145, y + 116], ["---", x + 145, y + 148],
          ["Titulo Conferido:", x + 145, y + 190], ["---", x + 145, y + 222], ["[C]: Ver Emblemas", x + 212, y + 268]]
  bare = Poke.build(:name => "Pika")
  bare.define_singleton_method(:memento) { nil }
  bare.define_singleton_method(:getMementoRank) { |_m| 0 }
  eq "with none worn, the rank the page leaves empty is not made up",
     PokeAccess::ImprovedMementos.page_text(bare, none.map { |t, px, py| [t, :positions, px, py] }),
     "Tipo: ---. No. ID: ---. Nombre: ---. Titulo Conferido: ---"
end

# The grid of all the mementos names the focused one and its description; its category, its place in the
# list and the conferred title are painted too, and the rank and the worn mark are pictures.
Suite.define("improved mementos: the grid's focused memento is read as its painter draws it") do
  t = PokeAccess::I18n
  paint = [["3/20", 210, 34], ["Cinta Campeon", 256, 246], ["Titulo Conferido:", 10, 282], ["'el Campeon'", 444, 282],
           ["Cinta", 40, 34], ["6", 526, 246]]
  pairs = paint.map { |s, px, py| [s, :positions, px, py] } + [["Ganada en la Liga.", :dtex, 10, 314]]
  pk = Poke.build(:name => "Pika")
  pk.define_singleton_method(:memento) { :CHAMPION }
  pk.define_singleton_method(:getMementoRank) { |_m| 6 }
  eq "category and place, name, title, description, then the rank once and the worn mark, one mark each",
     PokeAccess::ImprovedMementos.grid_text(pk, pairs, :CHAMPION),
     "Cinta 3/20. Cinta Campeon. Titulo Conferido: 'el Campeon'. Ganada en la Liga. " \
     "#{t.t(:mem_rank, :n => 6)}. #{t.t(:mem_worn)}"
  whole = PokeAccess::Info.info_text
  rows = vb_levels { PokeAccess::ImprovedMementos.grid_text(pk, pairs, :CHAMPION) }
  eq "brief: without its place in the list or its description", rows[0],
     "Cinta. Cinta Campeon. Titulo Conferido: 'el Campeon'. #{t.t(:mem_rank, :n => 6)}. #{t.t(:mem_worn)}"
  eq "medium: with its place", rows[1],
     "Cinta 3/20. Cinta Campeon. Titulo Conferido: 'el Campeon'. #{t.t(:mem_rank, :n => 6)}. #{t.t(:mem_worn)}"
  PokeAccess::Config.verbosity = :brief
  PokeAccess::ImprovedMementos.grid_text(pk, pairs, :CHAMPION)
  PokeAccess::Config.verbosity = :full
  eq "the info key keeps the whole memento", PokeAccess::Info.info_text, whole
end

# Both readers take over only where the plugin runs: on the ribbons page of a summary that draws mementos, and
# on the grid's paged redraw. A summary without the plugin keeps the core's own readings.
Suite.define("improved mementos: the page and the grid are the plugin's only on a summary that draws mementos") do
  t = PokeAccess::I18n
  pk = Poke.build(:name => "Pika")
  pk.define_singleton_method(:memento) { :CHAMPION }
  pk.define_singleton_method(:getMementoRank) { |_m| 2 }
  pairs = [["Tipo:", :positions, 394, 108], ["Cinta", :positions, 503, 108], ["Rango:", :positions, 394, 172],
           ["Nombre:", :positions, 435, 212], ["Cinta Campeon", :positions, 435, 244]]
  mementos = World.stub_scene(:@pokemon => pk, :@page_id => :page_ribbons)
  def mementos.drawPageMementos; end
  eq "the ribbons page of a memento summary is the memento's", PokeAccess::SummaryGameData.page_text(mementos, 5, nil, nil, pairs),
     "Tipo: Cinta. Rango: 2. Nombre: Cinta Campeon"
  plain = World.stub_scene(:@pokemon => pk, :@page_id => :page_ribbons)
  falsy "a plain summary's ribbons page is not", PokeAccess::SummaryGameData.page_text(plain, 5, nil, nil, pairs).to_s.include?("Rango: 2")

  PokeAccess::PaintCapture.arm(:mementos_sel)
  PokeAccess::PaintCapture.note_positions([["Cinta Campeon", 256, 246]])
  eq "the grid's paged redraw is read from its paint", PokeAccess::RibbonsV21.focused_text(mementos, [[:CHAMPION], 0, 0, 1]),
     "Cinta Campeon. #{t.t(:mem_rank, :n => 2)}. #{t.t(:mem_worn)}"
end
