# What the diagnostic shows of a silent screen: the strings painted lately, armed capture or not, and the first rows
# of the live command windows.

class PaintRecentTest < PokeAccessTest
  test "keeps what the painters drew, armed capture or not, the latest last" do
    with_clean_recent do
      drawTextEx(nil, 0, 0, 100, 1, "Bolsa")
      pbDrawTextPositions(nil, [["Poción", 10, 20, 0, nil, nil], ["x3", 90, 20, 0, nil, nil]])
      pbDrawShadowText(nil, 0, 0, 100, 32, "Usar")

      assert_equal ["dtex:Bolsa", "positions:Poción", "positions:x3", "shadow:Usar"], PokeAccess::PaintCapture.recent
    end
  end

  test "moves a repainted string to the end instead of repeating it" do
    with_clean_recent do
      %w[A B A].each { |t| drawTextEx(nil, 0, 0, 100, 1, t) }

      assert_equal ["dtex:B", "dtex:A"], PokeAccess::PaintCapture.recent
    end
  end

  test "keeps the last forty strings and leaves blanks out" do
    with_clean_recent do
      45.times { |i| drawTextEx(nil, 0, 0, 100, 1, "row #{i}") }
      drawTextEx(nil, 0, 0, 100, 1, "   ")

      recent = PokeAccess::PaintCapture.recent
      assert_equal 40, recent.length
      assert_equal ["dtex:row 5", "dtex:row 44"], [recent.first, recent.last]
    end
  end

  test "still hands an armed capture its rows" do
    with_clean_recent do
      PokeAccess::PaintCapture.arm(:spec_recent)
      drawTextEx(nil, 4, 8, 100, 1, "Título")

      assert_equal [["Título", :dtex, 4, 8]], PokeAccess::PaintCapture.take_pairs(:spec_recent)
    end
  end

  test "the scene section lists the painted strings and the rows of the live command windows" do
    with_clean_recent do
      ObjectSpace.each_object(Window_DrawableCommand) { |w| w.dispose }
      drawTextEx(nil, 0, 0, 100, 1, "Cartel")
      Window_DrawableCommand.new(["Objetos", ["Salir", 2]])
      out = PokeAccess::Keys.diag_build([:diag_scene])

      assert_match(/^painted=.*dtex:Cartel/, out)
      assert_match(%r{rows=Objetos / Salir 2}, out)
    end
  end

  private

  def with_clean_recent
    saved = PokeAccess::PaintCapture.instance_variable_get(:@recent)
    PokeAccess::PaintCapture.instance_variable_set(:@recent, nil)
    yield
  ensure
    PokeAccess::PaintCapture.instance_variable_set(:@recent, saved)
  end
end
