# The cursor-mode naming screen (PokemonEntryScene2): its caption is read without the character grids painted beside
# it, and the first cursor read waits behind it.

# Paints in the real screen's order (grids, sex sign, help and typed text), then the fade-in's pbUpdate.
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
end

# The key keyboard screen (PokemonEntryScene): its question and the box's text are read before its help.
class PokemonEntryScene
  def pbStartScene(helptext, _minlength, _maxlength, initial_text, subject = 0, pokemon = nil)
    @heading = helptext
    @text = initial_text
    if subject == 2 && pokemon && pokemon.gender == 1
      pbDrawTextPositions(Object.new, [["\xE2\x99\x80", 400, 20, false, nil, nil]])
    end
    drawTextEx(Object.new, 32, 288, 448, 2, "Escribe texto usando el teclado.")
  end
end

# Hooks bind at load, so this repo's text_entry.rb is evaluated again over the classes above.
verbose = $VERBOSE
begin
  $VERBOSE = nil
  path = File.join(Harness::ROOT, "core", "menus", "text_entry.rb")
  eval(File.read(path), TOPLEVEL_BINDING, path)
ensure
  $VERBOSE = verbose
end

NamingSubject = Struct.new(:gender)

Suite.define("naming: the cursor screen reads its question, not its keyboard") do
  scene = PokemonEntryScene2.new
  scene.pbStartScene("Mote de Pikachu?", 1, 10, "", 2, NamingSubject.new(0))
  eq "the caption is the question and the sex sign beside the box, queued",
     SpeakCapture.log[0], ["Mote de Pikachu? \xE2\x99\x82", false]

  SpeakCapture.clear
  scene = PokemonEntryScene2.new
  scene.pbStartScene("Nombre de la caja?", 1, 16, "Caja 1", 3, nil)
  eq "a text already in the box follows the question, labelled", SpeakCapture.lines[0],
     "Nombre de la caja? #{PokeAccess::I18n.t(:nm_current, :t => "Caja 1")}"

  SpeakCapture.clear
  scene = PokemonEntryScene2.new
  scene.pbStartScene("Mote de Magnemite?", 1, 10, "", 2, NamingSubject.new(2))
  eq "a genderless subject has no sign to read", SpeakCapture.lines[0], "Mote de Magnemite?"
end

Suite.define("naming: the first letter under the cursor waits for the question") do
  scene = PokemonEntryScene2.new
  SpeakCapture.clear
  scene.pbStartScene("Tu nombre?", 1, 8, "", 1, nil)
  eq "the question first, and the letter the fade-in reads after it, both queued", SpeakCapture.log,
     [["Tu nombre?", false], ["A", false]]

  SpeakCapture.clear
  scene.move_to(1)
  scene.pbUpdate
  eq "a real move still interrupts", SpeakCapture.log, [["B", true]]
end

Suite.define("naming: the key keyboard screen reads its question and what the box holds, then its help") do
  scene = PokemonEntryScene.new
  SpeakCapture.clear
  scene.pbStartScene("What is thy name?", 1, 10, "Mallie", 1, nil)
  eq "the question, the text already in the box, then the help, all queued", SpeakCapture.log,
     [["What is thy name? #{PokeAccess::I18n.t(:nm_current, :t => "Mallie")}", false],
      ["Escribe texto usando el teclado.", false]]

  SpeakCapture.clear
  PokemonEntryScene.new.pbStartScene("Mote de Eevee?", 1, 10, "", 2, NamingSubject.new(1))
  eq "a build that paints the sign as text too does not say it twice", SpeakCapture.log,
     [["Mote de Eevee? \xE2\x99\x80", false], ["Escribe texto usando el teclado.", false]]
end

# Typing a name's last character jumps the cursor to OK, said after the letter; a tab change names the tab before the
# character under the cursor.
Suite.define("naming: the jump to OK is said after the letter, and a tab change names the tab") do
  t = PokeAccess::I18n
  scene = PokemonEntryScene2.new
  scene.pbStartScene("Tu nombre?", 1, 1, "", 1, nil)
  SpeakCapture.clear
  scene.instance_variable_get(:@helper).text = "A"
  scene.move_to(-1)
  scene.pbUpdate
  eq "the letter interrupting, then OK queued behind it", SpeakCapture.log, [["A", true], [t.t(:nm_ok), false]]

  scene.instance_variable_get(:@helper).text = ""
  scene.move_to(0)
  scene.pbUpdate
  SpeakCapture.clear
  scene.instance_variable_set(:@mode, 1)
  scene.pbUpdate
  eq "the new tab, then the character under the cursor", SpeakCapture.lines, ["#{t.t(:nm_lower)}. a"]
end

# The game's own switch to lower case after the first capital is named after the letter; a tab picked from its
# control is named once, by the control.
Suite.define("naming: the tab the game switches to is named, and a tab picked from its control once") do
  t = PokeAccess::I18n
  scene = PokemonEntryScene2.new
  scene.pbStartScene("Tu nombre?", 1, 10, "", 1, nil)
  SpeakCapture.clear
  scene.instance_variable_get(:@helper).text = "A"
  scene.instance_variable_set(:@mode, 1)
  scene.pbUpdate
  eq "the letter, then the lower-case tab the game went to and the character it points at, queued",
     SpeakCapture.log, [["A", true], ["#{t.t(:nm_lower)}. a", false]]

  scene.move_to(-5)
  scene.instance_variable_set(:@mode, 0)
  scene.pbUpdate
  SpeakCapture.clear
  scene.instance_variable_set(:@mode, 1)
  scene.pbUpdate
  eq "picked from its control, the tab is the control's own word, once", SpeakCapture.lines, [t.t(:nm_lower)]
end
