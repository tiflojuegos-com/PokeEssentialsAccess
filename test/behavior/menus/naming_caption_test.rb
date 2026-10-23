# The naming screens: the cursor screen's caption and what its cursor, typing and tabs say (PokemonEntryScene2), and
# the keyboard screen's caption and then its help, its painted question and sign not said twice (PokemonEntryScene).

# The cursor-mode screen: paints in the real screen's order (grids, sex sign, help and typed text), then the
# fade-in's pbUpdate; the game's loop then types, deletes, moves the cursor and switches tabs, each followed by
# pbUpdate.
class PokemonEntryScene2
  @@Characters = [[("ABCDEFGHIJ ,.").scan(/./), "UPPER"], [("abcdefghij ,.").scan(/./), "lower"],
                  [("áéí").scan(/./), "accents"], [("!?-").scan(/./), "symbols"]]
  Helper = Struct.new(:text, :cursor)

  def pbStartScene(helptext, _minlength, _maxlength, initial_text, subject = 0, pokemon = nil)
    @helptext = helptext
    @helper = Helper.new(initial_text, initial_text.length)
    @mode = 0
    @cursorpos = 0
    @@Characters.each { |tab| pbDrawTextPositions(Object.new, tab[0].map { |c| [c, 0, 0, 2, nil, nil] }) }
    if subject == 2 && pokemon
      sign = pokemon.gender == 0 ? "\xE2\x99\x82" : (pokemon.gender == 1 ? "\xE2\x99\x80" : nil)
      pbDrawTextPositions(Object.new, sign ? [[sign, 0, -6, false, nil, nil]] : [])
    end
    rows = [[@helptext, 160, 6, false, nil, nil]]
    initial_text.scan(/./).each { |ch| rows.push([ch, 0, 42, false, nil, nil]) }
    pbDrawTextPositions(Object.new, rows)
    pbUpdate
  end

  def pbUpdate; end
  def move_to(pos); @cursorpos = pos; end
  def switch_to(mode); @mode = mode; end
  def type(text); @helper.text += text; end
  def erase; @helper.text = @helper.text[0...-1]; end
end

# The key keyboard screen: paints its question (as a heading window does), the sign of a Pokemon with one, and its help.
class PokemonEntryScene
  def initialize(help = "Escribe texto usando el teclado."); @help = help; end

  def pbStartScene(helptext, _minlength, _maxlength, initial_text, subject = 0, pokemon = nil)
    @heading = helptext
    @text = initial_text
    drawTextEx(Object.new, 0, 0, 448, 1, helptext)
    sign = (subject == 2 && pokemon) ? ["\xE2\x99\x82", "\xE2\x99\x80"][pokemon.gender] : nil
    pbDrawTextPositions(Object.new, [[sign, 400, 20, false, nil, nil]]) if sign
    drawTextEx(Object.new, 32, 288, 448, 2, @help)
  end
end

# Hooks bind at load, so this repo's text_entry.rb is evaluated again over the classes above.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "core", "menus", "text_entry.rb")
  eval(Harness.source(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

class NamingCaptionTest < PokeAccessTest
  # The Pokemon a naming screen names: only its sex, as the engines number it (0 male, 1 female, 2 none).
  Subject = Struct.new(:gender)
  MALE = "\xE2\x99\x82"
  FEMALE = "\xE2\x99\x80"
  HELP = "Escribe texto usando el teclado."

  test "the cursor screen's caption is its question, the Pokemon's sex sign and the text already in the box" do
    { ["Mote de Pikachu?", 1, 10, "", 2, Subject.new(0)] => "Mote de Pikachu? #{MALE}",
      ["Mote de Eevee?", 1, 10, "", 2, Subject.new(1)] => "Mote de Eevee? #{FEMALE}",
      ["Mote de Magnemite?", 1, 10, "", 2, Subject.new(2)] => "Mote de Magnemite?",
      ["Mote?", 1, 10, "", 2, nil] => "Mote?",
      ["Tu nombre?", 1, 8, "  ", 1, nil] => "Tu nombre?",
      ["Nombre de la caja?", 1, 16, "Caja 1", 3, nil] => "Nombre de la caja? #{t(:nm_current, :t => "Caja 1")}",
      ["Tu nombre?", 1, 8, "", 1, Subject.new(0)] => "Tu nombre?",
      ["Tu nombre?", 1, 8, ""] => "Tu nombre?" }.each do |args, caption|
      SpeakCapture.clear
      PokemonEntryScene2.new.pbStartScene(*args)
      assert_equal [caption, false], SpeakCapture.log.first, "opened with #{args.inspect}"
    end
  end

  test "the cursor screen opens on its question, then the letter under the cursor, both queued, its grids unread" do
    PokemonEntryScene2.new.pbStartScene("Tu nombre?", 1, 8, "", 1, nil)
    assert_equal [["Tu nombre?", false], ["A", false]], SpeakCapture.log
  end

  test "a move of the cursor says the character under it, interrupting, and a space by its name" do
    scene = opened
    { 1 => "B", 10 => t(:key_space), 12 => "." }.each do |pos, said|
      SpeakCapture.clear
      scene.move_to(pos)
      scene.pbUpdate
      assert_equal [[said, true]], SpeakCapture.log, "the cursor on #{pos}"
    end
  end

  test "the controls before the grid are said by name: the four tabs, Back and OK" do
    scene = opened
    { -6 => :nm_upper, -5 => :nm_lower, -4 => :nm_accents, -3 => :nm_symbols, -2 => :nm_back,
      -1 => :nm_ok }.each do |pos, key|
      SpeakCapture.clear
      scene.move_to(pos)
      scene.pbUpdate
      assert_equal [[t(key), true]], SpeakCapture.log, "the cursor on #{pos}"
    end
  end

  test "a gen-6 layout of three tabs has no accents: its third tab is the symbols" do
    with_tabs(3) do
      scene = opened
      { -5 => :nm_upper, -4 => :nm_lower, -3 => :nm_symbols }.each do |pos, key|
        SpeakCapture.clear
        scene.move_to(pos)
        scene.pbUpdate
        assert_equal [[t(key), true]], SpeakCapture.log, "the cursor on #{pos}"
      end
    end
  end

  test "a layout of a size it does not know names no tab on a tab change, only the character" do
    with_tabs(2) do
      scene = opened
      scene.switch_to(1)
      scene.pbUpdate
      assert_equal [["!", true]], SpeakCapture.log
    end
  end

  test "on a layout of a size it does not know a tab control says nothing, and the way back is said" do
    with_tabs(2) do
      scene = opened
      scene.move_to(-3)
      scene.pbUpdate
      scene.move_to(0)
      scene.pbUpdate
      assert_equal [["A", true]], SpeakCapture.log
    end
  end

  test "a layout it cannot read is taken for the modern four tabs, and a tab change names the tab with no character" do
    scene = opened
    without_layout do
      scene.switch_to(1)
      scene.pbUpdate
      scene.move_to(-6)
      scene.pbUpdate
    end
    assert_equal [["#{t(:nm_lower)}.", true], [t(:nm_upper), true]], SpeakCapture.log
  end

  test "a cursor still on the same character says nothing" do
    scene = opened
    scene.pbUpdate
    assert_nothing_spoken
  end

  test "typing echoes the character, interrupting, and a space by its name" do
    scene = opened
    { "A" => "A", " " => t(:key_space) }.each do |typed, said|
      SpeakCapture.clear
      scene.type(typed)
      scene.pbUpdate
      assert_equal [[said, true]], SpeakCapture.log, "typed #{typed.inspect}"
    end
  end

  test "deleting says the character deleted, interrupting" do
    scene = opened
    scene.type("AB")
    scene.pbUpdate
    SpeakCapture.clear
    scene.erase
    scene.pbUpdate
    assert_equal [[t(:te_deleted_char, :c => "B"), true]], SpeakCapture.log
  end

  test "the jump to OK as the name fills is said after the letter, queued" do
    scene = opened
    scene.type("A")
    scene.move_to(-1)
    scene.pbUpdate
    assert_equal [["A", true], [t(:nm_ok), false]], SpeakCapture.log
  end

  test "the tab the game switches to after a capital is named after the letter, with the character it points at" do
    scene = opened
    scene.type("A")
    scene.switch_to(1)
    scene.pbUpdate
    assert_equal [["A", true], ["#{t(:nm_lower)}. a", false]], SpeakCapture.log
  end

  test "a tab change under the cursor names the tab before the character, interrupting" do
    scene = opened
    scene.switch_to(1)
    scene.pbUpdate
    assert_equal [["#{t(:nm_lower)}. a", true]], SpeakCapture.log
  end

  test "a tab picked from its control is named once, by the control" do
    scene = opened
    scene.move_to(-5)
    scene.pbUpdate
    SpeakCapture.clear
    scene.switch_to(1)
    scene.pbUpdate
    assert_equal [[t(:nm_lower), true]], SpeakCapture.log
  end

  test "the keyboard screen reads its question and what the box holds, then its help, all queued" do
    PokemonEntryScene.new.pbStartScene("What is thy name?", 1, 10, "Mallie", 1, nil)
    assert_equal [["What is thy name? #{t(:nm_current, :t => "Mallie")}", false], [HELP, false]], SpeakCapture.log
  end

  test "the keyboard screen does not say twice the sign it paints beside the question" do
    { 0 => MALE, 1 => FEMALE }.each do |gender, sign|
      SpeakCapture.clear
      PokemonEntryScene.new.pbStartScene("Mote de Eevee?", 1, 10, "", 2, Subject.new(gender))
      assert_equal [["Mote de Eevee? #{sign}", false], [HELP, false]], SpeakCapture.log, "gender #{gender}"
    end
  end

  test "the keyboard screen's key hint is said down to medium and left out in brief" do
    help = "#{HELP} Pulsa ESC para cancelar o ENTER para confirmar."
    said = vb_levels do
      SpeakCapture.clear
      PokemonEntryScene.new(help).pbStartScene("Tu nombre?", 1, 10, "", 1, nil)
      SpeakCapture.lines
    end
    assert_equal [["Tu nombre?", HELP], ["Tu nombre?", help], ["Tu nombre?", help]], said
  end

  test "the keyboard screen that paints nothing besides its question says the caption alone" do
    PokemonEntryScene.new("").pbStartScene("Tu nombre?", 1, 10, "", 1, nil)
    assert_equal [["Tu nombre?", false]], SpeakCapture.log
  end

  private

  # The mod's line for an i18n key.
  def t(key, args = {})
    PokeAccess::I18n.t(key, args)
  end

  # A cursor screen naming the player, opened on its first character, its opening read cleared.
  def opened
    scene = PokemonEntryScene2.new
    scene.pbStartScene("Tu nombre?", 1, 10, "", 1, nil)
    SpeakCapture.clear
    scene
  end

  # Runs the block with the cursor screen laid out in count tabs (the gen-6 three), its own four put back after.
  def with_tabs(count)
    was = PokemonEntryScene2.class_variable_get(:@@Characters)
    PokemonEntryScene2.class_variable_set(:@@Characters, was.first(count - 1) + [was.last])
    yield
  ensure
    PokemonEntryScene2.class_variable_set(:@@Characters, was)
  end

  # Runs the block with the cursor screen's layout (@@Characters) gone, as in a game that keeps it elsewhere; put back
  # after.
  def without_layout
    was = PokemonEntryScene2.class_variable_get(:@@Characters)
    PokemonEntryScene2.send(:remove_class_variable, :@@Characters)
    yield
  ensure
    PokemonEntryScene2.class_variable_set(:@@Characters, was)
  end
end
