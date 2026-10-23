# The dialogue reader every message hook funnels through (core/dialogue/dialogue.rb): a line is said queued and kept
# for the repeat key, its copy within half a second is swallowed, a promised head leads the next line and a promised
# tail follows it; on gen 6 through the Kernel.pbMessageDisplay singleton the toolkit wraps at load.
class SayDialogueTest < PokeAccessTest
  # A message window whose pages the page reader can follow: the characters it has drawn, none yet.
  class PagedWindow
    def initialize; @textchars = []; @curchar = 0; end
    def pausing?; false; end
    def busy?; true; end
  end

  def setup
    super
    forget_dialogue
  end

  def teardown
    forget_dialogue
    super
  end

  test "says a line queued and keeps it for the repeat key" do
    PokeAccess.say_dialogue("Hola entrenador")
    assert_equal [["Hola entrenador", false]], SpeakCapture.log
    assert_equal "Hola entrenador", PokeAccess.last_dialogue
  end

  test "a copy of the last line within half a second is swallowed" do
    with_clock do |at|
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
      at.call(100.49)
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    end
    assert_equal [["Bienvenido a Pueblo Paleta", false]], SpeakCapture.log
  end

  test "half a second after the line was said its copy speaks again, swallowed copies not counting" do
    with_clock do |at|
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
      at.call(100.4)
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
      at.call(100.5)
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    end
    assert_equal [["Bienvenido a Pueblo Paleta", false]] * 2, SpeakCapture.log
  end

  test "a line said again starts its half second over" do
    with_clock do |at|
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
      at.call(100.6)
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
      at.call(101.0)
      PokeAccess.say_dialogue("Bienvenido a Pueblo Paleta")
    end
    assert_equal [["Bienvenido a Pueblo Paleta", false]] * 2, SpeakCapture.log
  end

  test "a different line always speaks, and the first speaks again once another came between" do
    with_clock do
      ["Hola entrenador", "Te daré un Pokémon", "Hola entrenador"].each { |line| PokeAccess.say_dialogue(line) }
    end
    assert_equal [["Hola entrenador", false], ["Te daré un Pokémon", false], ["Hola entrenador", false]],
                 SpeakCapture.log
  end

  test "a swallowed copy still puts its line back on the repeat key" do
    with_clock do
      PokeAccess.say_dialogue("Toma esta Poke Ball")
      PokeAccess.note_dialogue("Una línea de otro lector")
      SpeakCapture.clear
      PokeAccess.say_dialogue("Toma esta Poke Ball")
    end
    assert_nothing_spoken "the copy inside the window says nothing"
    assert_equal "Toma esta Poke Ball", PokeAccess.last_dialogue
  end

  test "an empty or missing message is no line: nothing said and the repeat key kept" do
    PokeAccess.say_dialogue("Toma esta Poke Ball")
    SpeakCapture.clear
    ["", nil, "   ", "\\c[2]"].each do |message|
      PokeAccess.say_dialogue(message)
      assert_equal "Toma esta Poke Ball", PokeAccess.last_dialogue, "after #{message.inspect}"
    end
    assert_nothing_spoken
  end

  test "a line and its form paused with control bytes are one line, said clean once" do
    { ["\x01Pikachu usó Impactrueno\x02", "Pikachu usó Impactrueno"] => ["Pikachu usó Impactrueno"],
      ["\x01Pikachu usó Impactrueno\x02", "\x01Charmander usó Ascuas\x02"] =>
        ["Pikachu usó Impactrueno", "Charmander usó Ascuas"] }.each do |messages, said|
      forget_dialogue
      SpeakCapture.clear
      with_clock { messages.each { |m| PokeAccess.say_dialogue(m) } }
      assert_equal said.map { |line| [line, false] }, SpeakCapture.log, "for #{messages.inspect}"
    end
  end

  test "is filed under dialogue, and under battle during a fight" do
    said = filed_under { PokeAccess.say_dialogue("Hola") }
    PokeAccess::Battle.battle_started
    fought = filed_under { PokeAccess.say_dialogue("¡Pikachu usó Placaje!") }
    assert_equal [:dialogue], said
    assert_equal [:battle], fought
  ensure
    PokeAccess::Battle.battle_ended
  end

  test "a promised head leads the next line, and the repeat key keeps the line as it was said" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    PokeAccess.say_dialogue("¡Uno!")
    assert_equal [["Niño, 2 izquierda: ¡Uno!", false]], SpeakCapture.log
    assert_equal "Niño, 2 izquierda: ¡Uno!", PokeAccess.last_dialogue
  end

  test "the line after a led one goes without the head" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    PokeAccess.say_dialogue("¡Uno!")
    SpeakCapture.clear
    PokeAccess.say_dialogue("¡Dos!")
    assert_equal [["¡Dos!", false]], SpeakCapture.log
  end

  test "another hook's copy of a led line is swallowed and leaves the repeat key led" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    with_clock { 2.times { PokeAccess.say_dialogue("¡Uno!") } }
    assert_equal [["Niño, 2 izquierda: ¡Uno!", false]], SpeakCapture.log
    assert_equal "Niño, 2 izquierda: ¡Uno!", PokeAccess.last_dialogue
  end

  test "an empty message leaves the head for the next line" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    PokeAccess.say_dialogue("")
    PokeAccess.say_dialogue("¡Uno!")
    assert_equal [["Niño, 2 izquierda: ¡Uno!", false]], SpeakCapture.log
  end

  test "a head dropped before its line, or an empty one, leads nothing" do
    [["Niña, 1 arriba", nil], [""]].each do |heads|
      forget_dialogue
      SpeakCapture.clear
      heads.each { |head| PokeAccess.before_next_line(head) }
      PokeAccess.say_dialogue("¡Tres!")
      assert_equal [["¡Tres!", false]], SpeakCapture.log, "with the heads #{heads.inspect} promised"
    end
  end

  test "a promised tail follows the next line once, queued" do
    PokeAccess.after_next_line("¡Es variocolor!")
    PokeAccess.say_dialogue("¡Ha nacido un Pichu!")
    PokeAccess.say_dialogue("Cuídalo bien.")
    assert_equal [["¡Ha nacido un Pichu!", false], ["¡Es variocolor!", false], ["Cuídalo bien.", false]],
                 SpeakCapture.log
  end

  test "an empty message leaves the tail for the next line" do
    PokeAccess.after_next_line("¡Es variocolor!")
    PokeAccess.say_dialogue("")
    PokeAccess.say_dialogue("¡Ha nacido un Pichu!")
    assert_equal [["¡Ha nacido un Pichu!", false], ["¡Es variocolor!", false]], SpeakCapture.log
  end

  test "a line kept unsaid goes on the repeat key at once, and swallows the engine's copy of it" do
    kept = nil
    with_clock do
      PokeAccess.say_dialogue_skip("Has pescado un Magikarp.")
      kept = PokeAccess.last_dialogue
      PokeAccess.say_dialogue("Has pescado un Magikarp.")
    end
    assert_nothing_spoken
    assert_equal ["Has pescado un Magikarp."] * 2, [kept, PokeAccess.last_dialogue]
  end

  test "a line kept unsaid with the head its reader says keeps that head on the repeat key" do
    kept = nil
    with_clock do
      PokeAccess.say_dialogue_skip("¡Hola!", "Niño, 1 abajo")
      kept = PokeAccess.last_dialogue
      PokeAccess.say_dialogue("¡Hola!")
    end
    assert_nothing_spoken
    assert_equal ["Niño, 1 abajo: ¡Hola!"] * 2, [kept, PokeAccess.last_dialogue]
  end

  test "a screen's message is said only when its first argument is text" do
    { ["Elige un objeto."] => [["Elige un objeto.", false]], [["Sí", "No"], "Elige"] => [], [""] => [], [nil] => [],
      [] => [] }.each do |args, said|
      forget_dialogue
      SpeakCapture.clear
      PokeAccess.say_screen_message(args)
      assert_equal said, SpeakCapture.log, "for #{args.inspect}"
    end
  end

  test "a message's letter-by-letter flag is the first argument after its text, true without one or with options" do
    { [] => true, [false] => false, [true] => true, [false, nil] => false,
      [{ :tts => false }] => true }.each do |args, flag|
      assert_equal flag, PokeAccess.letter_by_letter(args), "for #{args.inspect}"
    end
  end

  test "the game's Kernel.pbMessageDisplay says each message once, queued, and keeps the last for the repeat key" do
    with_clock do
      ["Este cartel dice algo", "Este cartel dice algo", "Aquí vive el Profesor"].each do |message|
        Kernel.pbMessageDisplay(nil, message)
      end
    end
    assert_equal [["Este cartel dice algo", false], ["Aquí vive el Profesor", false]], SpeakCapture.log
    assert_equal "Aquí vive el Profesor", PokeAccess.last_dialogue
  end

  test "a message counts one level deeper while the game's window shows it, and none after, even when it fails" do
    depths = []
    showing(lambda { depths.push(PokeAccess.message_depth) }) { Kernel.pbMessageDisplay(nil, "Primero") }
    showing(lambda { raise ArgumentError, "the window failed" }) do
      assert_raises(ArgumentError) { Kernel.pbMessageDisplay(nil, "Segundo") }
    end
    assert_equal [1], depths, "one level deep while the window shows it"
    assert_equal 0, PokeAccess.message_depth, "none after either"
  end

  test "with dialogue pages on, a message whose window pages is left to the page reader, said as the window closes" do
    PokeAccess::Config.dialogue_pages = true
    during = nil
    showing(lambda { during = SpeakCapture.log.dup }) { Kernel.pbMessageDisplay(PagedWindow.new, "Hola.") }
    assert_equal [], during, "nothing while the window shows it"
    assert_equal [["Hola.", false]], SpeakCapture.log
  end

  test "counts every message handed over for the diag from none, the swallowed copy included" do
    counts = from_no_messages do
      before = PokeAccess.dialogue_seen
      with_clock { 2.times { Kernel.pbMessageDisplay(nil, "Una línea") } }
      [before, PokeAccess.dialogue_seen]
    end
    assert_equal [0, 2], counts
  end

  test "on gen 6 the Kernel singleton, the form the game defines, is the one wrapped" do
    assert_equal [:singleton], PokeAccess.dialogue_wraps
    assert_equal [:singleton], PokeAccess::Keys.dialogue_forms
  end

  private

  # Drops what a line leaves for the next one: the repeat key's line, the line just said and its time (the half-second
  # guard), the line as led, a promised head or tail, the depth of messages inside messages and the window the page
  # reader follows.
  def forget_dialogue
    PokeAccess.take_head
    PokeAccess.take_tail
    [:@last_dialogue, :@last_say, :@last_say_t, :@last_led, :@msg_depth].each do |ivar|
      PokeAccess.instance_variable_set(ivar, nil)
    end
    PokeAccess::DialoguePages.instance_variable_set(:@win, nil)
  end

  # Runs the block with the mod's clock standing at 100 s, or wherever the block's argument moves it, the real clock
  # put back after: time passing without waiting.
  def with_clock
    now = [100.0]
    real = PokeAccess.method(:clock)
    PokeAccess.define_singleton_method(:clock) { now[0] }
    yield lambda { |t| now[0] = t }
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end

  # Runs the block with the diag's message count as the mod starts it, none yet; the count kept before is put back
  # after.
  def from_no_messages
    kept = PokeAccess.instance_variable_get(:@dialogue_seen)
    PokeAccess.instance_variable_set(:@dialogue_seen, nil)
    yield
  ensure
    PokeAccess.instance_variable_set(:@dialogue_seen, kept)
  end

  # The categories the lines said inside the block are filed under.
  def filed_under
    filed = []
    PokeAccess::Speech.observe(:say_dialogue_test) { |m| filed.push(m.category) }
    yield
    filed
  ensure
    PokeAccess::Speech.unobserve(:say_dialogue_test)
  end

  # Runs the block with the game's own message window, which the wrap calls, standing in as show; the stub's own is
  # put back after.
  def showing(show)
    k = Kernel.singleton_class
    k.send(:alias_method, :pa_spec_display, :pbMessageDisplay__access_orig)
    k.send(:define_method, :pbMessageDisplay__access_orig) { |*_args| show.call }
    yield
  ensure
    k.send(:alias_method, :pbMessageDisplay__access_orig, :pa_spec_display)
    k.send(:remove_method, :pa_spec_display)
  end
end
