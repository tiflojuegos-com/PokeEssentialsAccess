# Armonia's and Pokemon Z's Habilidades sheet (plugins/summary_habilidades.rb), fed their own paint calls, said in paint
# order but for the ability's value, sex sign and description, which join their owners; and the stats page's C key.
class SummaryHabilidadesTest < PokeAccessTest
  SH = PokeAccess::SummaryHabilidades
  MALE = "\xE2\x99\x82"
  DESC = "Potencia los ataques de tipo Planta en un apuro."
  # Armonia's rows as take_pairs gives them: the header under the ability's label painted before its value, the stats
  # in two columns, the sign pushed last and the description by drawTextEx after them all.
  ARMONIA = [["INFORMACIÓN", :positions, 26, 16], ["Bulbasaur", :positions, 46, 62], ["5", :positions, 46, 92],
             ["Habilidad:", :positions, 200, 0], ["EV / IV / Poder Oculto ", :positions, 200, 225],
             ["Espesura", :positions, 320, 0], ["  HP  ", :positions, 228, 260], ["1/31", :positions, 350, 260],
             ["ATAQ.", :positions, 200, 285], ["2/30", :positions, 350, 285], ["DEFE.", :positions, 200, 310],
             ["3/29", :positions, 350, 310], ["AT.E.", :positions, 360, 260], ["4/28", :positions, 500, 260],
             ["DE.E.", :positions, 360, 285], ["5/27", :positions, 500, 285], ["VELO.", :positions, 360, 310],
             ["6/26", :positions, 500, 310], ["Felicidad", :positions, 20, 345], ["70", :positions, 150, 345],
             ["Poder Oculto", :positions, 210, 345], ["Planta", :positions, 450, 345], [MALE, :positions, 160, 62],
             [DESC, :dtex, 200, 30]].freeze
  # Pokemon Z's: the same calls moved, with the happiness label a line above its value, on the Defense row.
  POKEMON_Z = [["INFORMACIÓN", :positions, 26, 16], ["Bulbasaur", :positions, 46, 62], ["5", :positions, 46, 92],
               ["Habilidad:", :positions, 200, 2], ["EV / IV", :positions, 200, 227], ["Espesura", :positions, 310, 2],
               ["  HP  ", :positions, 228, 260], ["1/31", :positions, 350, 260], ["ATAQ.", :positions, 200, 290],
               ["2/30", :positions, 350, 290], ["DEFE.", :positions, 200, 320], ["3/29", :positions, 350, 320],
               ["AT.E.", :positions, 360, 260], ["4/28", :positions, 500, 260], ["DE.E.", :positions, 360, 290],
               ["5/27", :positions, 500, 290], ["VELO.", :positions, 360, 320], ["6/26", :positions, 500, 320],
               ["Felicidad", :positions, 22, 320], ["70", :positions, 55, 352], ["Poder Oculto", :positions, 195, 353],
               ["Planta", :positions, 435, 353], [MALE, :positions, 160, 62], [DESC, :dtex, 200, 32]].freeze
  # A summary scene that has the sheet, as Armonia's and Pokemon Z's do.
  SheetScene = Class.new { def Habilidades(_pokemon); nil; end }

  test "orders Armonia's sheet: the ability's value after its label, the sign after the name, the paragraph under the ability" do
    assert_equal sheet("EV / IV / Poder Oculto"), SH.ordered(ARMONIA)
  end

  test "orders Pokemon Z's sheet the same, its happiness label still before its value a line below" do
    assert_equal sheet("EV / IV"), SH.ordered(POKEMON_Z)
  end

  test "keeps rows with no position in their place" do
    assert_equal ["A:", "B"], SH.ordered([["A:", :formatted, nil, nil], ["B", :positions, 5, 5]])
  end

  test "leaves out blank rows and rows of markup alone" do
    assert_equal ["A"], SH.ordered(at([["", 0, 0], ["<c3=F83818,E09890>", 0, 0], ["A", 0, 0]]))
  end

  test "a label takes the nearest value still to come right of it on its line, and nothing else" do
    { "the nearest of two" => [[["L:", 0, 0], ["far", 300, 0], ["near", 100, 0]], ["L: near", "far"]],
      "one on another line" => [[["L:", 0, 0], ["below", 100, 10]], ["L:", "below"]],
      "one left of it" => [[["L:", 200, 0], ["left", 100, 0]], ["L:", "left"]],
      "its own copy painted in place" => [[["L:", 200, 0], ["L:", 200, 0]], ["L:", "L:"]] }.each do |what, (rows, want)|
      assert_equal want, SH.ordered(at(rows)), what
    end
    assert_equal ["L: B", "loose"],
                 SH.ordered([["L:", :positions, 0, 5], ["loose", :formatted, nil, 5], ["B", :positions, 100, 5]]),
                 "a row with no x on its line is no value of it"
  end

  test "a sex sign joins the nearest row left of it on its line, and stays alone with none" do
    { "the nearest of two" => [[["Zeta", 0, 10], ["Alfa", 100, 10], [MALE, 200, 10]], ["Zeta", "Alfa #{MALE}"]],
      "painted before its row" => [[[MALE, 200, 10], ["Alfa", 100, 10]], [MALE, "Alfa"]],
      "a row on another line" => [[["Alfa", 100, 0], [MALE, 200, 10]], ["Alfa", MALE]],
      "a row at the sign's own x" => [[["Alfa", 100, 10], [MALE, 100, 10]], ["Alfa", MALE]] }.each do |what, (rows, want)|
      assert_equal want, SH.ordered(at(rows)), what
    end
  end

  test "a paragraph follows the lowest row above it at its left edge, and keeps its place with none" do
    { "under the lower of two" => [[["H1", :positions, 200, 0], ["H2", :positions, 200, 20], ["X", :positions, 0, 30],
                                    ["P", :dtex, 200, 40]], ["H1", "H2", "P", "X"]],
      "no row at its edge" => [[["X", :positions, 0, 0], ["P", :dtex, 200, 40]], ["X", "P"]],
      "only a row below it" => [[["X", :positions, 0, 0], ["B", :positions, 200, 60], ["P", :dtex, 200, 40]],
                                ["X", "B", "P"]],
      "only a row at its own place" => [[["Y", :positions, 200, 40], ["X", :positions, 0, 50], ["P", :dtex, 200, 40]],
                                        ["Y", "X", "P"]] }.each do |what, (rows, want)|
      assert_equal want, SH.ordered(rows), what
    end
  end

  test "the frame poll says the painted sheet once, queued" do
    paint(ARMONIA)
    SH.poll
    SH.poll
    assert_equal [[sheet("EV / IV / Poder Oculto").join(", "), false]], SpeakCapture.log
  end

  test "the frame poll says nothing of a sheet that painted nothing to say" do
    paint([["<c3=F83818,E09890>", :positions, 0, 0]])
    SH.poll
    assert_nothing_spoken
    assert_equal false, PokeAccess::PaintCapture.armed?(:sum_habilidades), "the capture is taken all the same"
  end

  test "the frame poll says nothing before the sheet paints" do
    PokeAccess::PaintCapture.arm(:sum_habilidades)
    SH.poll
    assert_nothing_spoken
  ensure
    PokeAccess::PaintCapture.arm(nil)
  end

  test "the stats page says the C key its picture draws, from medium" do
    key = PokeAccess::I18n.t(:sumh_key)
    said = vb_levels { stats_page_said(SheetScene.new, "Estadísticas.") }
    assert_equal [["Estadísticas."], ["Estadísticas. #{key}"], ["Estadísticas. #{key}"]], said
  end

  test "the key is said once, even on a page that already ends with it" do
    key = PokeAccess::I18n.t(:sumh_key)
    assert_equal ["Estadísticas. #{key}"], stats_page_said(SheetScene.new, "Estadísticas. #{key}")
  end

  test "another page says no key" do
    PokeAccess::Summary.speak_page(SheetScene.new, Poke.build(:name => "Bulbasaur"), 2, "Recuerdos.")
    assert_equal [["Recuerdos.", false]], SpeakCapture.log
  end

  test "a summary without the sheet says no key" do
    assert_equal ["Estadísticas."], stats_page_said(Object.new, "Estadísticas.")
  end

  private

  # What both sheets should say: the ability with its value and description, the header right before the figures.
  def sheet(header)
    ["INFORMACIÓN", "Bulbasaur #{MALE}", "5", "Habilidad: Espesura", DESC, header, "HP", "1/31", "ATAQ.", "2/30",
     "DEFE.", "3/29", "AT.E.", "4/28", "DE.E.", "5/27", "VELO.", "6/26", "Felicidad", "70", "Poder Oculto", "Planta"]
  end

  # Rows painted as [text, x, y] positions, as take_pairs gives them.
  def at(rows)
    rows.map { |t, x, y| [t, :positions, x, y] }
  end

  # Arms the sheet's capture and paints the rows into it, as entering the sheet and its paint calls do.
  def paint(rows)
    PokeAccess::PaintCapture.arm(:sum_habilidades)
    rows.each do |text, source, x, y|
      source == :dtex ? PokeAccess::PaintCapture.note(text, :dtex, x, y) : PokeAccess::PaintCapture.note_positions([[text, x, y]])
    end
  end

  # The lines a stats page with text says on scene.
  def stats_page_said(scene, text)
    SpeakCapture.clear
    PokeAccess::Summary.speak_page(scene, Poke.build(:name => "Bulbasaur"), 3, text)
    SpeakCapture.lines.dup
  end
end
