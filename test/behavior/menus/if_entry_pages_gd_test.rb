# Infinite Fusion's Pokedex entry (games/infinitefusion_common/entry_pages.rb), gamedata pass: flipping a long entry
# says the page's text, then which page it is; Hoenn's sprite switch says the new artist, and the entry when it changed.

# The flip and the switch, painting what a test hands them, are added to the stub's scene before the file binds them.
class PokemonPokedexInfo_Scene
  # A flip of a long entry: the rows of @flip_rows painted with drawTextEx, else the second page of two.
  def changeEntryPage
    (@flip_rows || ["2/2", "y se esconde entre las rocas."]).each { |text| drawTextEx(nil, 40, 244, 400, 4, text) }
    :flipped
  end

  # Hoenn's Q/W: the info page repainted for another sprite, its artist line (@artist) and the entry's rows
  # (@entry_rows), which a fusion's custom entry changes.
  def update_displayed_sprite(_delta)
    pbDrawTextPositions(nil, [[@artist || "Sprite: Artista#9", 224, 156]])
    (@entry_rows || ["Una entrada."]).each { |text| drawTextEx(nil, 40, 244, 400, 4, text) }
    :switched
  end
end

entry_pages = File.join(Harness::ROOT, "games", "infinitefusion_common", "entry_pages.rb")
eval(Harness.source(entry_pages), TOPLEVEL_BINDING, entry_pages)

class IfEntryPagesGdTest < PokeAccessTest
  # The page heard last on the info page, which holds the entry "Una entrada.".
  HEARD = "Pikachu. Una entrada. Sprite: Artista#1"

  test "keeps the game's own return from a flip and from a sprite switch" do
    scene = PokemonPokedexInfo_Scene.new
    assert_equal [:flipped, :switched], [scene.changeEntryPage, scene.update_displayed_sprite(1)]
  end

  test "says the page a flip shows, then which page it is, interrupting" do
    { ["2/2", "y se esconde entre las rocas."] => "y se esconde entre las rocas. #{page(2, 2)}",
      ["1 / 3", "Vive en cuevas."] => "Vive en cuevas. #{page(1, 3)}" }.each do |rows, said|
      SpeakCapture.clear
      flip(rows)
      assert_equal [[said, true]], SpeakCapture.log, "for #{rows.inspect}"
    end
  end

  test "says a flipped page's text alone at brief, the page it is being a position" do
    rows = vb_levels do
      SpeakCapture.clear
      flip(["2/2", "y se esconde entre las rocas."])
      SpeakCapture.lines
    end
    full = ["y se esconde entre las rocas. #{page(2, 2)}"]
    assert_equal [["y se esconde entre las rocas."], full, full], rows
  end

  test "says a flipped text with no page mark alone, and nothing for a flip that paints nothing" do
    flip(["Una entrada corta."])
    flip([])
    assert_equal ["Una entrada corta."], SpeakCapture.lines
  end

  test "says the new sprite's artist alone when the entry is the one already heard" do
    switch(info_page)
    assert_equal [["Sprite: Artista#9", true]], SpeakCapture.log
  end

  test "says a fusion's entry that changed with the sprite after its artist, and once" do
    scene = info_page
    2.times { switch(scene, :@entry_rows => ["Otra entrada de fusión."]) }
    assert_equal ["Sprite: Artista#9. Otra entrada de fusión.", "Sprite: Artista#9"], SpeakCapture.lines
  end

  test "leaves the page mark out of the entry it compares with the one heard" do
    switch(info_page, :@entry_rows => ["1/2", "Una entrada."])
    assert_equal ["Sprite: Artista#9"], SpeakCapture.lines
  end

  test "finds the artist line by the label the game translates" do
    with_intl("Sprite: {1}" => "Grafismo: {1}") { switch(info_page, :@artist => "Grafismo: Artista#9") }
    assert_equal ["Grafismo: Artista#9"], SpeakCapture.lines
  end

  test "says the changed entry alone when no artist line is painted, and nothing when the entry was heard too" do
    switch(info_page, :@artist => "Pikachu", :@entry_rows => ["Otra entrada de fusión."])
    switch(info_page, :@artist => "Pikachu")
    assert_equal ["Otra entrada de fusión."], SpeakCapture.lines
  end

  private

  # Which page of how many, as said.
  def page(n, m)
    PokeAccess::I18n.t(:if_entry_page, :n => n, :m => m)
  end

  # Flips a long entry whose page paints rows.
  def flip(rows)
    scene = PokemonPokedexInfo_Scene.new
    scene.instance_variable_set(:@flip_rows, rows)
    scene.changeEntryPage
  end

  # The info page with HEARD as what was heard on it last.
  def info_page
    scene = PokemonPokedexInfo_Scene.new
    PokeAccess::Cursor.store(scene, :pdx_page, HEARD)
    scene
  end

  # Switches the scene's sprite, the paint set by the given ivars (:@artist, :@entry_rows).
  def switch(scene, paint = {})
    paint.each { |ivar, value| scene.instance_variable_set(ivar, value) }
    scene.update_displayed_sprite(1)
  end
end
