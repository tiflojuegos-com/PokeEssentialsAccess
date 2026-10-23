# The key hints a summary page paints ("[C]: Descripcion", a sentence asking for a key, even over two lines): a page
# composed from the data says them after it while key hints are said, with the key the player uses now.
class PartyKeyHintsTest < PokeAccessTest
  S = PokeAccess::Summary

  test "takes as hints a bracketed key and a sentence asking for one, its codes cleaned, each a sentence" do
    assert_equal ["[C]: Descripcion.", "Pulsa F para leer la descripcion completa."],
                 S.page_hints(["PS", "[C]: Descripcion", "Habilidad", "\\c[2]Pulsa F para leer la descripcion completa."])
  end

  test "joins a hint painted over several lines up to its stop" do
    assert_equal ["Pulsa S en cualquier pantalla para ver la descripcion."],
                 S.page_hints(["Pulsa S en cualquier pantalla", "para ver la descripcion.", "PS"])
  end

  test "ends with a stop a hint whose lines run out" do
    assert_equal ["Pulsa S en cualquier pantalla."], S.page_hints(["Pulsa S en", "cualquier", "pantalla"])
  end

  test "stops joining at the next hint, and never joins a line to a bracketed key" do
    assert_equal ["Pulsa A.", "Pulsa B."], S.page_hints(["Pulsa A", "Pulsa B"]), "a hint after a hint"
    assert_equal ["[C]: Ver."], S.page_hints(["[C]: Ver", "algo"]), "a line after a bracketed key"
  end

  test "finds no hints on a page that paints none, or nothing" do
    assert_equal [], S.page_hints(["PS", "Ataque", ""]), "no hint"
    assert_equal [], S.page_hints(nil), "nothing painted"
  end

  test "says a page's hints after it while key hints are said" do
    assert_equal "Estadisticas. [D]: Descripcion. [F]: Mas.", S.with_hints("  Estadisticas.  ", ["[D]: Descripcion", "[F]: Mas"])
  end

  test "says the page alone when it paints no hint" do
    assert_equal "Estadisticas.", S.with_hints("Estadisticas.", ["PS", "Ataque"])
  end

  test "says the page alone below the medium level, where key hints are left out" do
    assert_equal ["Estadisticas.", "Estadisticas. [D]: Descripcion.", "Estadisticas. [D]: Descripcion."],
                 vb_levels { S.with_hints("Estadisticas.", ["[D]: Descripcion"]) }
  end

  test "gives nothing for a page with no text, hints or not" do
    assert_nil S.with_hints(nil, ["[D]: Descripcion"])
  end

  test "says the key the player uses now, in a bracketed hint and in a sentence asking for it" do
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.rebinds = { :c => 0x4B }
    PokeAccess::Config.key_hint_letters = PokeAccess::KeyHints::RGSS_LETTERS
    assert_equal ["[K]: Descripcion.", "Pulsa la tecla K para ver mas."],
                 S.page_hints(["[C]: Descripcion", "Pulsa la tecla C para ver mas."])
  ensure
    PokeAccess::Config.rebinds = was[0]
    PokeAccess::Config.key_hint_letters = was[1]
  end
end
