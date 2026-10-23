# Improved Mementos (Royal): the ribbons page is the worn memento's, read label by value with its rank, and the grid's
# focused memento is read from what its redraw paints; a summary without the plugin keeps the core's readings.
class ImprovedMementosGdTest < PokeAccessTest
  T = PokeAccess::I18n
  MEM = PokeAccess::ImprovedMementos
  Move = Struct.new(:id, :name, :pp, :total_pp, :type)
  X = 290
  Y = 96
  PAGE = [["Tipo:", X + 104, Y + 12], ["No. ID:", X + 104, Y + 44], ["12", X + 234, Y + 44], ["Rango:", X + 104, Y + 76],
          ["Nombre:", X + 145, Y + 116], ["Cinta Campeon", X + 145, Y + 148], ["Titulo Conferido:", X + 145, Y + 190],
          ["'el Campeon'", X + 145, Y + 222], ["[C]: Ver Emblemas", X + 212, Y + 268], ["Cinta", X + 213, Y + 12],
          ["Pika", 46, 62]].freeze
  BARE = [["Tipo:", X + 104, Y + 12], ["---", X + 232, Y + 12], ["No. ID:", X + 104, Y + 44], ["---", X + 234, Y + 44],
          ["Rango:", X + 104, Y + 76], ["Nombre:", X + 145, Y + 116], ["---", X + 145, Y + 148],
          ["Titulo Conferido:", X + 145, Y + 190], ["---", X + 145, Y + 222], ["[C]: Ver Emblemas", X + 212, Y + 268]].freeze
  GRID = [["3/20", 210, 34], ["Cinta Campeon", 256, 246], ["Titulo Conferido:", 10, 282], ["'el Campeon'", 444, 282],
          ["Cinta", 40, 34]].freeze
  DESCRIPTION = ["Ganada en la Liga.", :dtex, 10, 314].freeze

  test "reads the worn memento's page label by value in reading order, the rank its icons draw after its bare label" do
    assert_equal "Tipo: Cinta. No. ID: 12. Rango: 3. Nombre: Cinta Campeon. Titulo Conferido: 'el Campeon'",
                 MEM.page_text(wearing(:CHAMPION, 3), positions(PAGE))
  end

  test "reads the page's own block only, from its first row and column, and leaves the key hint out" do
    rows = [["Tipo:", X, Y], ["Cinta", X + 110, Y], ["Izquierda", X - 1, Y + 40], ["Arriba", X + 110, Y - 1],
            ["[C]: Ver Emblemas", X + 212, Y + 268]]
    assert_equal "Tipo: Cinta", MEM.page_text(wearing(:CHAMPION, 0), positions(rows))
  end

  test "drops the rank label the page leaves empty when none is worn" do
    assert_equal "Tipo: ---. No. ID: ---. Nombre: ---. Titulo Conferido: ---",
                 MEM.page_text(wearing(nil, 0), positions(BARE))
  end

  test "says a rank of one after its bare label" do
    assert_equal "Rango: 1. Nombre: Cinta Campeon",
                 MEM.page_text(wearing(:CHAMPION, 1), positions([["Rango:", X + 104, Y + 76], ["Nombre:", X + 145, Y + 116],
                                                                ["Cinta Campeon", X + 145, Y + 148]]))
  end

  test "takes a rank it cannot read as none" do
    pk = wearing(:CHAMPION, 0)
    pk.define_singleton_method(:getMementoRank) { |_m| raise "no rank" }
    assert_equal "Tipo: ---. No. ID: ---. Nombre: ---. Titulo Conferido: ---", MEM.page_text(pk, positions(BARE))
  end

  test "gives no page when nothing of it was captured" do
    assert_nil MEM.page_text(wearing(:CHAMPION, 3), [])
  end

  test "reads the grid's focused memento as painted: category and place, name, title, description, then rank and worn mark" do
    assert_equal "Cinta 3/20. Cinta Campeon. Titulo Conferido: 'el Campeon'. Ganada en la Liga. " \
                 "#{T.t(:mem_rank, :n => 6)}. #{T.t(:mem_worn)}",
                 MEM.grid_text(wearing(:CHAMPION, 6), grid(6), :CHAMPION)
  end

  test "leaves the grid's place in the list out at brief, and its description below full" do
    tail = "Cinta Campeon. Titulo Conferido: 'el Campeon'"
    marks = "#{T.t(:mem_rank, :n => 6)}. #{T.t(:mem_worn)}"
    assert_equal ["Cinta. #{tail}. #{marks}", "Cinta 3/20. #{tail}. #{marks}", "Cinta 3/20. #{tail}. Ganada en la Liga. #{marks}"],
                 vb_levels { MEM.grid_text(wearing(:CHAMPION, 6), grid(6), :CHAMPION) }
  end

  test "keeps the whole focused memento for the info key at any verbosity" do
    PokeAccess::Config.verbosity = :brief
    MEM.grid_text(wearing(:CHAMPION, 6), grid(6), :CHAMPION)
    assert_equal "Cinta 3/20. Cinta Campeon. Titulo Conferido: 'el Campeon'. Ganada en la Liga. " \
                 "#{T.t(:mem_rank, :n => 6)}. #{T.t(:mem_worn)}", PokeAccess::Info.info_text
  end

  test "reads a rank from five, one icon and its number, as the rank alone, the number left off the name's row" do
    assert_equal "Cinta 3/20. Cinta Campeon. Titulo Conferido: 'el Campeon'. Ganada en la Liga. " \
                 "#{T.t(:mem_rank, :n => 5)}. #{T.t(:mem_worn)}",
                 MEM.grid_text(wearing(:CHAMPION, 5), grid(5), :CHAMPION)
  end

  test "says a rank of one, and none for an unranked memento" do
    assert_equal "Cinta Campeon. #{T.t(:mem_rank, :n => 1)}. #{T.t(:mem_worn)}",
                 MEM.grid_text(wearing(:CHAMPION, 1), positions([["Cinta Campeon", 256, 246]]), :CHAMPION), "rank 1"
    assert_equal "Cinta Campeon. #{T.t(:mem_worn)}",
                 MEM.grid_text(wearing(:CHAMPION, 0), positions([["Cinta Campeon", 256, 246]]), :CHAMPION), "unranked"
  end

  test "marks as worn only the memento the Pokemon wears" do
    assert_equal "Cinta Siempre. #{T.t(:mem_rank, :n => 2)}",
                 MEM.grid_text(wearing(:CHAMPION, 2), positions([["Cinta Siempre", 256, 246]]), :FOREVER)
  end

  test "gives no grid text when nothing is painted, ranked or worn" do
    assert_nil MEM.grid_text(wearing(:CHAMPION, 0), [], :FOREVER)
  end

  test "makes the ribbons page of a summary that draws mementos the memento's page" do
    pk = wearing(:CHAMPION, 2)
    rows = positions([["Tipo:", 394, 108], ["Cinta", 503, 108], ["Rango:", 394, 172], ["Nombre:", 435, 212],
                      ["Cinta Campeon", 435, 244]])
    assert_equal "Tipo: Cinta. Rango: 2. Nombre: Cinta Campeon",
                 PokeAccess::SummaryGameData.page_text(memento_summary(pk), 5, nil, nil, rows)
  end

  test "keeps the core's ribbons page on a plain summary, or where nothing of the memento's was captured" do
    pk = wearing(:CHAMPION, 2)
    rows = positions([["Tipo:", 394, 108], ["Cinta", 503, 108]])
    plain = World.stub_scene(:@pokemon => pk, :@page_id => :page_ribbons)
    assert_equal T.t(:sm_ribbons_none), PokeAccess::SummaryGameData.page_text(plain, 5, nil, nil, rows), "a plain summary"
    assert_equal T.t(:sm_ribbons_none), PokeAccess::SummaryGameData.page_text(memento_summary(pk), 5, nil, nil, []),
                 "nothing captured"
  end

  test "keeps the core's reading for the other pages of a memento summary" do
    pk = wearing(:CHAMPION, 2)
    pk.moves = [Move.new(:TACKLE, "Placaje", 35, 35, :NORMAL), Move.new(:THUNDERSHOCK, "Impactrueno", 30, 30, :ELECTRIC)]
    scene = memento_summary(pk)
    scene.instance_variable_set(:@page_id, :page_moves)
    moves = "Placaje. #{T.t(:mv_type, :t => 'TypeNORMAL')}. #{T.t(:mv_pp, :pp => 35, :tot => 35)}, " \
            "Impactrueno. #{T.t(:mv_type, :t => 'TypeELECTRIC')}. #{T.t(:mv_pp, :pp => 30, :tot => 30)}"
    assert_equal T.t(:sm_moves, :list => moves),
                 PokeAccess::SummaryGameData.page_text(scene, 4, nil, nil, positions([["Tipo:", 394, 108]]))
  end

  test "reads the grid's paged redraw from its paint" do
    scene = memento_summary(wearing(:CHAMPION, 2))
    PokeAccess::PaintCapture.arm(:mementos_sel)
    PokeAccess::PaintCapture.note_positions([["Cinta Campeon", 256, 246]])
    assert_equal "Cinta Campeon. #{T.t(:mem_rank, :n => 2)}. #{T.t(:mem_worn)}",
                 PokeAccess::RibbonsV21.focused_text(scene, [[:CHAMPION], 0, 0, 1])
  end

  test "keeps the core's cell reading on a plain summary's grid" do
    plain = World.stub_scene(:@pokemon => wearing(:CHAMPION, 2), :@page_id => :page_ribbons)
    assert_equal PokeAccess::Summary.ribbon_cell_text(plain, :CHAMPION),
                 PokeAccess::RibbonsV21.focused_text(plain, [[:CHAMPION], 0, 0, 1])
  end

  test "reads only what a redraw with the plugin's four arguments paints, not the rows painted before it" do
    scene = memento_scene(wearing(:CHAMPION, 2))
    PokeAccess::PaintCapture.arm(:mementos_sel)
    PokeAccess::PaintCapture.note_positions([["Cinta Vieja", 256, 246]])
    SpeakCapture.clear
    scene.drawSelectedRibbon([:CHAMPION], 0, 0, 1)
    assert_equal [["#{T.t(:mem_rank, :n => 2)}. #{T.t(:mem_worn)}", true]], SpeakCapture.log
  end

  test "keeps the core's cell reading for a vanilla one-argument redraw, even on a memento summary" do
    scene = memento_scene(wearing(:CHAMPION, 2))
    SpeakCapture.clear
    scene.drawSelectedRibbon(:CHAMPION)
    assert_equal [[PokeAccess::Summary.ribbon_cell_text(scene, :CHAMPION), true]], SpeakCapture.log
  end

  private

  # Pika wearing memento (nil for none), whose mementos all rank rank.
  def wearing(memento, rank)
    pk = Poke.build(:name => "Pika")
    pk.define_singleton_method(:memento) { memento }
    pk.define_singleton_method(:getMementoRank) { |_m| rank }
    pk
  end

  # Painted rows as the capture keeps a pbDrawTextPositions batch.
  def positions(rows)
    rows.map { |t, px, py| [t, :positions, px, py] }
  end

  # The grid's paint for a memento of the given rank: from five, the number beside its one icon; the description
  # written with drawTextEx.
  def grid(rank)
    rows = positions(GRID)
    rows += positions([[rank.to_s, 526, 246]]) if rank >= 5
    rows + [DESCRIPTION]
  end

  # A summary scene stand-in on the ribbons page, of a summary that draws mementos.
  def memento_summary(pk)
    scene = World.stub_scene(:@pokemon => pk, :@page_id => :page_ribbons)
    def scene.drawPageMementos; end
    scene
  end

  # The engine's summary scene over pk, as the plugin turns it into one that draws mementos.
  def memento_scene(pk)
    scene = PokemonSummary_Scene.new(pk)
    def scene.drawPageMementos; end
    scene
  end
end
