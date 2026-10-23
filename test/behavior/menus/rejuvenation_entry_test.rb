# Rejuvenation's entry screens of the Pokedex and PC searches (games/rejuvenation/text_entry.rb): the type pick, whose
# two reels paint only icons, and the bounded text entry, its matches and the one picked, whose field holds the mod's
# keys; and the letter grid its free text opens with the keyboard option off.
Harness.load_common("rv_common")

# A reel of the type pick, as the game builds it: up and down turn it only while it is selected, toggleSelect passes the
# selection on, and selected is the type under it (nil on the second reel's blank).
class PokemonTypeReel
  attr_writer :selected

  def initialize(index, reel)
    @index = index
    @reel = reel
    @pos = 0
    @selected = false
  end

  def selected; @reel[@pos]; end
  def up; return unless @selected; @pos = (@pos - 1) % @reel.length; end
  def down; return unless @selected; @pos = (@pos + 1) % @reel.length; end
  def toggleSelect; @selected = !@selected; end
end

# The type pick: the question, the first reel (selected), the second with its blank first, and the help under them.
class PokemonTypeSelectionScreen
  HELP = "Select types using the arrow keys.\nPress ESC to cancel, or ENTER to confirm."
  attr_reader :sprites

  def pbStartScene(helptext, _starttypes)
    @sprites = { "entry" => FakeTextWin.new(helptext), "type1" => PokemonTypeReel.new(0, [:NORMAL, :FIRE, :WATER]),
                 "type2" => PokemonTypeReel.new(1, [nil, :NORMAL, :FIRE, :WATER]), "helpwindow" => FakeTextWin.new(HELP) }
    @sprites["type1"].selected = true
  end
end

# The bounded entry's keyboard window: the names matching what is typed and the one picked, -1 while none is, else its
# place from 1, both changed by its own update, which answers :drawn.
class Window_BoundedTextEntry_Keyboard
  attr_accessor :active, :matchingnames, :highlightindex

  def initialize(names)
    @matchingnames = names
    @highlightindex = -1
    @active = true
  end

  def update; :drawn; end
end

# The bounded entry: the keyboard window under the question, and the help.
class BoundedPokemonEntryScene
  HELP = "Enter text using the keyboard.  Press\nESC to cancel, or ENTER to confirm."
  attr_reader :sprites

  def pbStartScene(_helptext, names)
    @sprites = { "entry" => Window_BoundedTextEntry_Keyboard.new(names), "helpwindow" => FakeTextWin.new(HELP) }
  end
end

# The letter grid the free text opens with the keyboard option off: the stock cursor screen renamed, in three tabs, its
# fade-in's pbUpdate inside pbStartScene; the game's loop then moves the cursor, switches tabs and types, each followed
# by pbUpdate.
class PokemonCharacterGridEntryScene
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [(",.:;!?").scan(/./), "other"]]
  Helper = Struct.new(:text)

  def pbStartScene(_helptext, _minlength, _maxlength, initial_text, _subject = 0, _pokemon = nil)
    @helper = Helper.new(initial_text)
    @mode = 0
    @cursorpos = 0
    pbUpdate
  end

  def pbUpdate; :updated; end
  def move_to(pos, mode = @mode); @cursorpos = pos; @mode = mode; end
  def type(c); @helper.text += c; end
end

class RejuvenationEntryTest < PokeAccessTest
  # The game's getTypeName, which answers "" for a type it has no name for.
  TYPE_NAMES = { :getTypeName => lambda { |ty| { :NORMAL => "Normal", :FIRE => "Fire", :WATER => "Water" }[ty].to_s } }
  # The names a move search lists before anything is typed.
  MOVES = ["Tackle", "Thunder", "Thunderbolt"]
  # A keyboard window that cannot say whether it is active.
  Unflagged = Class.new(Window_BoundedTextEntry_Keyboard) { def active; raise NoMethodError, "active"; end }

  # Evaluates the profile file once, as boot does, leaving the list of profiles as it was.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(Harness::ROOT, "games", "rejuvenation", "text_entry.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  test "the type pick opens with its question, the first reel's type and the help, queued" do
    with_type_pick do
      line = "Which types? #{t(:rj_type_slot, :n => 1, :t => 'Normal')}. Select types using the arrow keys. " \
             "Press ESC to cancel, or ENTER to confirm."
      assert_equal [[line, false]], SpeakCapture.log
    end
  end

  test "with key hints left out, the type pick opens without the help's key line" do
    PokeAccess::Config.verbosity = :brief
    with_type_pick do
      line = "Which types? #{t(:rj_type_slot, :n => 1, :t => 'Normal')}. Select types using the arrow keys."
      assert_equal [[line, false]], SpeakCapture.log
    end
  end

  test "up and down on the selected reel say the type they turn it to, cutting in" do
    { :down => "Fire", :up => "Water" }.each do |key, type|
      with_type_pick do |scene|
        SpeakCapture.clear
        scene.sprites["type1"].send(key)
        assert_equal [[type, true]], SpeakCapture.log, "#{key} from Normal"
      end
    end
  end

  test "up and down say nothing on the reel that is not selected" do
    with_type_pick do |scene|
      SpeakCapture.clear
      scene.sprites["type2"].down
      scene.sprites["type2"].up
      assert_nothing_spoken
    end
  end

  test "left or right says the reel the selection moves to, with its blank as none" do
    with_type_pick do |scene|
      SpeakCapture.clear
      scene.sprites["type1"].toggleSelect
      scene.sprites["type2"].toggleSelect
      assert_equal [[t(:rj_type_slot, :n => 2, :t => t(:sum_none)), true]], SpeakCapture.log
    end
  end

  test "a type the game has no name for is said by its id" do
    with_type_pick do
      reel = PokemonTypeReel.new(0, [:NORMAL, :SHADOW])
      reel.selected = true
      SpeakCapture.clear
      reel.down
      assert_equal [["SHADOW", true]], SpeakCapture.log
    end
  end

  test "the text entry opens with its question, how many names match with the first, and the help, queued" do
    { MOVES => t(:rj_matches, :n => 3, :first => "Tackle"), ["Tackle"] => t(:rj_matches, :n => 1, :first => "Tackle") }.each do |names, matches|
      SpeakCapture.clear
      bounded_entry(names)
      line = "Name of the move? #{matches}. Enter text using the keyboard. Press ESC to cancel, or ENTER to confirm."
      assert_equal [[line, false]], SpeakCapture.log, "#{names.length} names"
    end
  end

  test "the text entry with no names to match opens with its question and the help alone" do
    [nil, []].each do |names|
      SpeakCapture.clear
      bounded_entry(names)
      line = "Name of the move? Enter text using the keyboard. Press ESC to cancel, or ENTER to confirm."
      assert_equal [[line, false]], SpeakCapture.log, "names #{names.inspect}"
    end
  end

  test "the field's first frame says nothing, its matches said as it opened" do
    win = bounded_entry(MOVES)
    SpeakCapture.clear
    win.update
    assert_nothing_spoken
  end

  test "each frame of the active field holds the mod's keys" do
    win = bounded_entry(MOVES)
    win.update
    assert_operator typing_hold, :>, 0
  end

  test "an inactive field neither holds the mod's keys nor says its matches" do
    win = bounded_entry(MOVES)
    win.active = false
    win.update
    win.matchingnames = ["Thunder", "Thunderbolt"]
    SpeakCapture.clear
    win.update
    assert_equal 0, typing_hold, "the keys are the mod's"
    assert_nothing_spoken
  end

  test "a field that cannot say whether it is active is followed as an active one" do
    win = Unflagged.new(MOVES)
    win.update
    win.matchingnames = ["Thunder", "Thunderbolt"]
    win.update
    assert_operator typing_hold, :>, 0, "the keys are held"
    assert_equal [[t(:rj_matches, :n => 2, :first => "Thunder"), false]], SpeakCapture.log
  end

  test "a key that narrows the matches says how many are left with the first, queued behind its echo" do
    win = primed_field
    win.matchingnames = ["Thunder", "Thunderbolt"]
    win.update
    assert_equal [[t(:rj_matches, :n => 2, :first => "Thunder"), false]], SpeakCapture.log
  end

  test "a frame with nothing changed says nothing" do
    win = primed_field
    win.matchingnames = ["Thunder", "Thunderbolt"]
    win.update
    SpeakCapture.clear
    win.update
    assert_nothing_spoken
  end

  test "down onto a match says it with its place, cutting in" do
    { 1 => "Tackle, #{t(:list_pos, :i => 1, :n => 3)}", 3 => "Thunderbolt, #{t(:list_pos, :i => 3, :n => 3)}" }.each do |hl, line|
      win = primed_field
      win.highlightindex = hl
      win.update
      assert_equal [[line, true]], SpeakCapture.log, "match #{hl}"
    end
  end

  test "back from the matches to the text says nothing" do
    win = primed_field
    win.highlightindex = 2
    win.update
    SpeakCapture.clear
    win.highlightindex = -1
    win.update
    assert_nothing_spoken
  end

  test "a key typed on a picked match says the matches it leaves" do
    win = primed_field
    win.highlightindex = 2
    win.update
    SpeakCapture.clear
    win.highlightindex = -1
    win.matchingnames = ["Thunderbolt"]
    win.update
    assert_equal [[t(:rj_matches, :n => 1, :first => "Thunderbolt"), false]], SpeakCapture.log
  end

  test "a frame whose pick cannot be read passes in silence" do
    win = primed_field
    win.highlightindex = Object.new
    assert_equal :drawn, win.update, "the window's update runs, its answer handed back"
    assert_nothing_spoken
  end

  test "the letter grid opens on its question, then the letter under the cursor, both queued" do
    assert_equal :updated, PokemonCharacterGridEntryScene.new.pbStartScene("Nickname?", 0, 10, "")
    assert_equal [["Nickname?", false], ["A", false]], SpeakCapture.log
  end

  test "a move on the letter grid says the character under it, and its controls by name, cutting in" do
    grid = opened_grid
    { 1 => "B", 10 => t(:key_space), -5 => t(:nm_upper), -4 => t(:nm_lower), -3 => t(:nm_symbols),
      -2 => t(:nm_back), -1 => t(:nm_ok) }.each do |pos, said|
      SpeakCapture.clear
      grid.move_to(pos)
      grid.pbUpdate
      assert_equal [[said, true]], SpeakCapture.log, "the cursor on #{pos}"
    end
  end

  test "a letter typed on the grid is echoed" do
    grid = opened_grid
    grid.type("A")
    grid.pbUpdate
    assert_equal [[PokeAccess::TextEntry.char_text("A"), true]], SpeakCapture.log
  end

  test "a tab switched under the grid's cursor is named before the letter it shows" do
    grid = opened_grid
    grid.move_to(0, 1)
    grid.pbUpdate
    assert_equal [["#{t(:nm_lower)}. a", true]], SpeakCapture.log
  end

  private

  # The letter grid opened on its first letter, its opening read cleared.
  def opened_grid
    grid = PokemonCharacterGridEntryScene.new
    grid.pbStartScene("Nickname?", 0, 10, "")
    SpeakCapture.clear
    grid
  end

  def t(key, vars = nil)
    PokeAccess::I18n.t(key, vars)
  end

  # Runs the block on the type pick opened on "Which types?", with the game's type names in place.
  def with_type_pick
    GameFunctions.with(TYPE_NAMES) do
      scene = PokemonTypeSelectionScreen.new
      scene.pbStartScene("Which types?", [])
      yield scene
    end
  end

  # The keyboard window of the bounded entry opened on "Name of the move?" over names.
  def bounded_entry(names)
    scene = BoundedPokemonEntryScene.new
    scene.pbStartScene("Name of the move?", names)
    scene.sprites["entry"]
  end

  # The keyboard window over the three moves past its first frame, with nothing said yet.
  def primed_field
    win = bounded_entry(MOVES)
    win.update
    SpeakCapture.clear
    win
  end

  # The frames the mod's keys are held for.
  def typing_hold
    PokeAccess::Keys.instance_variable_get(:@typing_ttl)
  end
end
