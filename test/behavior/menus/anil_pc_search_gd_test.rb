# Anil's PC search (games/anil/pc_search.rb), gamedata pass: once the search has jumped to the chosen box, the frames of
# its fade say the box's name and the Pokemon left bright, each with its row and column, once.
class AnilPcSearchGdTest < PokeAccessTest
  # A box icon, as bright as its opacity.
  Icon = Struct.new(:opacity)
  # A box as the storage keeps it.
  Box = Struct.new(:name)

  test "names the box it jumped to, then the Pokemon the fade leaves bright with where they sit, queued" do
    search(scene(%w[Pikachu Bulbasaur Pichu], [255, 240, 255]))
    assert_equal [["Caja 3. #{hits(["Pikachu", 1, 1], ["Pichu", 1, 3])}", false]], SpeakCapture.log
  end

  test "keeps the search's and the jump's own returns" do
    s = scene(%w[Pikachu], [255])
    assert_equal [:searched, :jumped], [search(s), s.pbJumpToBox(0)]
  end

  test "says the matches once, however many frames the fade runs" do
    search(scene(%w[Pikachu], [255]), 3)
    assert_equal ["Caja 3. #{hits(["Pikachu", 1, 1])}"], SpeakCapture.lines
  end

  test "says nothing while the box is still being chosen" do
    PokeAccess::AnilPCSearch.start(scene(%w[Pikachu], [255]))
    PokeAccess::AnilPCSearch.poll
    assert_nothing_spoken
  ensure
    PokeAccess::AnilPCSearch.stop
  end

  test "waits for its own jump in a new search, whatever a search ended before its fade left behind" do
    s = scene(%w[Pikachu], [255])
    s.pbSearch(0)
    PokeAccess::AnilPCSearch.start(s)
    PokeAccess::AnilPCSearch.poll
    assert_nothing_spoken
  ensure
    PokeAccess::AnilPCSearch.stop
  end

  test "says nothing once the search is over" do
    s = scene(%w[Pikachu], [255])
    search(s)
    SpeakCapture.clear
    s.pbJumpToBox(0)
    PokeAccess::AnilPCSearch.poll
    assert_nothing_spoken
  end

  test "says every Pokemon of a box where everything matches" do
    search(scene(%w[Pikachu Bulbasaur Pichu], [255, 255, 255]))
    assert_equal ["Caja 3. #{hits(["Pikachu", 1, 1], ["Bulbasaur", 1, 2], ["Pichu", 1, 3])}"], SpeakCapture.lines
  end

  test "says nothing when the fade leaves none bright" do
    search(scene(%w[Pikachu Bulbasaur], [254, 0]))
    assert_nothing_spoken
  end

  test "passes over the box's empty places" do
    search(scene(["Pikachu", nil, "Pichu"], [255, 255, 255]))
    assert_equal ["Caja 3. #{hits(["Pikachu", 1, 1], ["Pichu", 1, 3])}"], SpeakCapture.lines
  end

  test "counts the rows of six down the box" do
    mons = %w[A B C D E F G Pikachu]
    search(scene(mons, [0] * 6 + [255, 255]))
    assert_equal ["Caja 3. #{hits(["G", 2, 1], ["Pikachu", 2, 2])}"], SpeakCapture.lines
  end

  test "says the matches alone where the box has no name to say" do
    ["", nil].each do |name|
      SpeakCapture.clear
      search(scene(%w[Pikachu], [255], name))
      assert_equal [hits(["Pikachu", 1, 1])], SpeakCapture.lines, "box name #{name.inspect}"
    end
  end

  test "cleans the box's name of the game's codes" do
    search(scene(%w[Pikachu], [255], "\\c[1]Caja 3"))
    assert_equal ["Caja 3. #{hits(["Pikachu", 1, 1])}"], SpeakCapture.lines
  end

  test "says nothing, and leaves the search running, over a box that cannot answer for its icons" do
    s = scene(%w[Pikachu], [255])
    s.instance_variable_set(:@sprites, { "box" => Object.new })
    assert_equal :searched, search(s)
    assert_nothing_spoken
  end

  private

  # A storage scene over one box named name, whose places hold Pokemon of these names (nil for an empty place) and
  # whose icons stand at these opacities.
  def scene(names, opacities, name = "Caja 3")
    icons = opacities.map { |o| Icon.new(o) }
    pokes = names.map { |n| n && Poke.build(:name => n) }
    box = Object.new
    box.define_singleton_method(:getPokemon) { |i| icons[i] }
    storage = Object.new
    storage.define_singleton_method(:currentBox) { 0 }
    storage.define_singleton_method(:maxPokemon) { |_b| pokes.length }
    storage.define_singleton_method(:[]) { |_b, i = nil| i.nil? ? Box.new(name) : pokes[i] }
    s = PokemonStorageScene.new(storage)
    s.instance_variable_set(:@sprites, { "box" => box })
    s
  end

  # Runs the scene's search: the jump to the box, then frames of the fade, each a pulse of the frame's pollers.
  def search(scene, frames = 1)
    scene.on_search_frame = lambda { frames.times { PokeAccess::Frame.run_pollers } }
    scene.pbSearch(0)
  end

  # The matches line for [name, row, column] entries.
  def hits(*entries)
    list = entries.map { |n, row, col| "#{n}#{PokeAccess::I18n.t(:pc_pos, :row => row, :col => col)}" }
    PokeAccess::I18n.t(:anil_search_hits, :list => list.join("; "))
  end
end
