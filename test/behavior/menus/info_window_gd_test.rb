# InfoWindow, gamedata pass: the modern dex header, painted from pbRefresh with no windows, is read as the list opens
# and when a total changes; a declared window a screen lacks is noted for the diagnostic, and a hidden one waits.

class InfoWindowGdTest < PokeAccessTest
  test "reads the modern dex header as the list opens, without the focused species the list reader says" do
    SpeakCapture.clear
    PokemonPokedex_Scene.new.pbStartScene
    assert_equal [["Pokedex, Seen:, 42", false]], SpeakCapture.log
  end

  test "does not repeat the dex header when only the focused species changes" do
    scene = PokemonPokedex_Scene.new
    scene.pbStartScene
    scene.focus_species = 4
    SpeakCapture.clear
    scene.pbRefresh
    assert_nothing_spoken
  end

  test "reads the dex header again when a total changes" do
    scene = PokemonPokedex_Scene.new
    scene.pbStartScene
    scene.seen_total = 43
    SpeakCapture.clear
    scene.pbRefresh
    assert_equal [["Pokedex, Seen:, 43", false]], SpeakCapture.log
  end

  test "notes none of the header windows the modern dex lacks" do
    PokemonPokedex_Scene.new.pbStartScene
    SpeakCapture.clear
    PokeAccess::InfoWindow.tick
    assert_equal [], PokeAccess::InfoWindow.silent.grep(/Pokedex/)
  end

  test "notes a declared window the screen lacks, once, and says nothing for it" do
    with_absent_window do |iw, before|
      PokemonPhone_Scene.new.pbStartScene
      SpeakCapture.clear
      iw.tick
      iw.tick
      assert_nothing_spoken
      assert_equal ["PokemonPhone_Scene.no_such_window"], iw.silent - before
    end
  end

  test "notes no more than twenty missing windows" do
    with_absent_window do |iw, _before|
      iw.silent.replace((1..20).map { |i| "SpecScene#{i}.window" })
      PokemonPhone_Scene.new.pbStartScene
      iw.tick
      assert_equal 20, iw.silent.length
      refute_includes iw.silent, "PokemonPhone_Scene.no_such_window"
    end
  end

  test "leaves a hidden window unread, and reads what it holds the moment it is shown" do
    scene = PokemonPhone_Scene.new
    scene.pbStartScene
    scene.sprites["bottom"].visible = false
    scene.sprites["bottom"].text = "<ac>Ruta 9"
    SpeakCapture.clear
    PokeAccess::InfoWindow.tick
    assert_nothing_spoken "hidden"
    scene.sprites["bottom"].visible = true
    PokeAccess::InfoWindow.tick
    assert_equal [["Ruta 9", false]], SpeakCapture.log, "shown"
  end

  private

  # Runs the block with a watch on a phone window that does not exist, yielding InfoWindow and the diagnostic's list
  # as it stood; the watch and the list are put back afterwards.
  def with_absent_window
    iw = PokeAccess::InfoWindow
    before = iw.silent.dup
    iw.watch("PokemonPhone_Scene", "no_such_window", :spec_absent)
    yield iw, before
  ensure
    iw.watches.reject! { |w| w[2] == :spec_absent }
    iw.silent.replace(before)
  end
end
