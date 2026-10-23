# The Emerald UI Pack's starter choice (RSEStarters): the message its window shows as it opens, then the focused
# starter by name and place in the row, with the category line the screen paints while the starter's sprite is hidden.

# The starter choice as the game builds it: its window shows the call's message from pbStartScene on, and each pbUpdate
# is a frame of the carousel over @species_cache under @index; the starter's sprite stays hidden while the row is
# browsed (the screen paints the category line then) and shows as a choice is confirmed. Built from the ivars given.
class RSESTarterChoice
  def initialize(ivars = {}); ivars.each { |k, v| instance_variable_set(k, v) }; end
  def pbStartScene; :started; end
  def pbUpdate; :updated; end
end

path = File.join(Harness::ROOT, "plugins", "rse_starters.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class RseStartersOpeningTest < PokeAccessTest
  # A starter's entry in the scene's species cache.
  Species = Struct.new(:name, :category)
  # An entry the game left unnamed, which the species data names by its number.
  Unnamed = Struct.new(:number) do
    def name; ""; end
    def to_s; number.to_s; end
  end
  # The starter's sprite, shown or hidden.
  Sprite = Struct.new(:visible)
  ROW = [Species.new("Treecko", "Geco Bosque"), Species.new("Torchic", "Polluelo"), Species.new("Mudkip", "Pez Lodo")]
  MESSAGE = "Choose your Starter Pokemon."

  test "leaves the choice's own values to the game" do
    scene = choice
    assert_equal [:started, :updated], [scene.pbStartScene, scene.pbUpdate]
  end

  test "says the message its window shows as the choice opens, queued" do
    choice.pbStartScene
    assert_equal [[MESSAGE, false]], SpeakCapture.log
  end

  test "says the call's own message when its window shows none" do
    scene = RSESTarterChoice.new(:@message => "Elige a tu compañero.", :@sprites => { "messageWindow" => FakeTextWin.new("") })
    scene.pbStartScene
    assert_equal [["Elige a tu compañero.", false]], SpeakCapture.log
  end

  test "says nothing as it opens with no message in its window or the call" do
    { "a blank window and message" => { :@message => "", :@sprites => { "messageWindow" => FakeTextWin.new("") } },
      "no window and no message" => { :@sprites => {} } }.each do |what, ivars|
      SpeakCapture.clear
      RSESTarterChoice.new(ivars).pbStartScene
      assert_nothing_spoken what
    end
  end

  test "reads the first starter with the category line it paints, queued behind the opening message" do
    scene = choice
    scene.pbStartScene
    scene.pbUpdate
    assert_equal [[MESSAGE, false], ["#{entry("Treecko", 1)}. #{category("Geco Bosque")}", false]], SpeakCapture.log
  end

  test "reads the next starter as the carousel moves, interrupting, and a starter once while it stays" do
    scene = choice
    scene.pbUpdate
    scene.instance_variable_set(:@index, 2)
    SpeakCapture.clear
    scene.pbUpdate
    scene.pbUpdate
    assert_equal [["#{entry("Mudkip", 3)}. #{category("Pez Lodo")}", true]], SpeakCapture.log
  end

  test "reads the starter again by name alone while the screen shows its sprite instead of the category" do
    scene = choice
    scene.pbUpdate
    scene.instance_variable_get(:@sprites)["pokemon"].visible = true
    SpeakCapture.clear
    scene.pbUpdate
    assert_equal [[entry("Treecko", 1), true]], SpeakCapture.log
  end

  test "leaves the category out where the screen has none to show" do
    { "no category" => choice(0, [Species.new("Treecko", nil)]),
      "a blank category" => choice(0, [Species.new("Treecko", "")]),
      "no sprite to tell what the screen shows" => choice(0, [ROW[0]], nil) }.each do |what, scene|
      SpeakCapture.clear
      scene.pbUpdate
      assert_equal [entry("Treecko", 1, 1)], SpeakCapture.lines, what
    end
  end

  test "names a starter from the species data when its cache entry carries no name" do
    choice(0, [252], true).pbUpdate
    choice(0, [Unnamed.new(252)], true).pbUpdate
    assert_equal [entry("Especie252", 1, 1), entry("Especie252", 1, 1)], SpeakCapture.lines,
                 "a species number, and an entry with a blank name, as the engine names species 252"
  end

  test "names no starter the species data cannot name either" do
    nameless = Object.new
    def nameless.species_name(_id); ""; end
    Harness.with_provider(nameless, 30) { choice(0, [Unnamed.new(252)], true).pbUpdate }
    assert_nothing_spoken
  end

  test "reads nothing for a cursor outside the row or a row it cannot read" do
    { "before the row" => [-1, ROW], "past the row" => [3, ROW], "no cursor" => [nil, ROW], "no row" => [0, nil],
      "a cursor that is no number" => ["0", ROW] }.each do |what, (index, row)|
      SpeakCapture.clear
      choice(index, row).pbUpdate
      assert_nothing_spoken what
    end
  end

  private

  # The starter choice with its window's message and the cursor on index of row, the starter's sprite shown or hidden
  # (nil: no such sprite).
  def choice(index = 0, row = ROW, shown = false)
    sprites = { "messageWindow" => FakeTextWin.new(MESSAGE) }
    sprites["pokemon"] = Sprite.new(shown) unless shown.nil?
    RSESTarterChoice.new(:@index => index, :@species_cache => row, :@sprites => sprites, :@message => MESSAGE)
  end

  # A starter's row as the list says it: its name and place among tot.
  def entry(name, n, tot = ROW.length)
    PokeAccess::I18n.t(:list_entry, :name => name, :n => n, :tot => tot)
  end

  # The category line the screen paints for a starter's category.
  def category(cat)
    PokeAccess::I18n.t(:rse_category, :cat => cat)
  end
end
