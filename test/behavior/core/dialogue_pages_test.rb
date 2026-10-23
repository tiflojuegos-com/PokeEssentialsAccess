# DialoguePages (the dialogue_pages option, off by default): each page said as the message window stops at it, cutting
# the one before; a message it never followed said whole as it closes; what it cannot follow left to the whole reading.
class DialoguePagesTest < PokeAccessTest
  Pages = PokeAccess::DialoguePages

  # A paging message window as Window_AdvancedTextPokemon keeps one: its characters, how far it has drawn them, and
  # whether it stands at a page break or is still busy drawing.
  class MessageWindow
    attr_accessor :pausing, :busy
    def initialize; @textchars = []; @curchar = 0; @pausing = false; @busy = true; end
    def pausing?; @pausing; end
    def busy?; @busy; end
    # What setText does: a fresh array of characters, drawn from the start.
    def show(text); @textchars = text.split(//); @curchar = 0; @pausing = false; @busy = true; end
    # Draws up to the i-th character, still drawing.
    def draw_to(i); @curchar = i; end
    # Draws up to the i-th character and stops there, at a page break.
    def pause_at(i); @curchar = i; @pausing = true; end
    # Draws the rest and finishes.
    def draw_all; @curchar = @textchars.length; @busy = false; @pausing = false; end
    # The window's characters, replaced as a test needs them.
    def chars=(chars); @textchars = chars; end
  end

  # A value whose text cannot be read: to_s raises, as join and clean ask for it.
  class Unprintable
    def to_s; raise "unreadable"; end
  end

  def setup
    super
    forget_dialogue
  end

  def teardown
    forget_dialogue
    super
  end

  test "is off by default, leaving each message to the whole reading" do
    assert_equal false, Pages.open(MessageWindow.new, "Hola.", true)
  end

  test "takes a message over without saying a word before the window draws it" do
    PokeAccess::Config.dialogue_pages = true
    assert_equal true, Pages.open(MessageWindow.new, "Primera línea. Segunda página.", true)
    assert_nothing_spoken
  end

  test "says each page once as the window stops at it, cutting the one before" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.pause_at(14)
    Pages.poll
    Pages.poll
    win.draw_all
    Pages.poll
    assert_equal [["Primera línea.", true], ["Segunda página.", true]], SpeakCapture.log
  end

  test "says nothing while the window is still drawing a page" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.draw_to(7)
    Pages.poll
    assert_nothing_spoken
  end

  test "says nothing more on closing a message whose pages were all heard" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.pause_at(14)
    Pages.poll
    win.draw_all
    Pages.poll
    SpeakCapture.clear
    Pages.close(win)
    assert_nothing_spoken
  end

  test "keeps the whole message for the repeat key" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.pause_at(14)
    Pages.poll
    win.draw_all
    Pages.poll
    Pages.close(win)
    assert_equal "Primera línea. Segunda página.", PokeAccess.last_dialogue
  end

  test "follows the window on every frame's pulse" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.pause_at(14)
    PokeAccess::Frame.run_pollers
    assert_includes SpeakCapture.log, ["Primera línea.", true]
  end

  test "says nothing on a frame with no message open" do
    Pages.poll
    assert_nothing_spoken
  end

  test "says a message the window never drew whole as it closes, queued" do
    win = follow("Nadie la dibujó.")
    Pages.close(win)
    assert_equal [["Nadie la dibujó.", false]], SpeakCapture.log
  end

  test "says a message the window finished between two frames whole as it closes, queued" do
    win = follow("Una pregunta final.", "Una pregunta final.")
    win.draw_all
    Pages.close(win)
    assert_equal [["Una pregunta final.", false]], SpeakCapture.log
  end

  test "files what it says, page or whole, as dialogue in the history" do
    win = follow("Primera línea. Segunda página.", "Primera línea.\1Segunda página.")
    win.pause_at(14)
    Pages.poll
    win.draw_all
    Pages.poll
    Pages.close(win)
    Pages.close(follow("Nadie la dibujó."))
    assert_equal ["Primera línea.", "Segunda página.", "Nadie la dibujó."],
                 PokeAccess::History.lines_of(:dialogue).map { |m| m.text }
  end

  test "says the line promised for after the message once it closes, queued" do
    PokeAccess.after_next_line("Es variocolor.")
    win = follow("Otra.", "Otra.")
    win.draw_all
    Pages.poll
    Pages.close(win)
    assert_equal [["Otra.", true], ["Es variocolor.", false]], SpeakCapture.log
  end

  test "leads the first page heard with the promised head, and only the first" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    win = follow("Cuento uno. Y dos.", "Cuento uno.\1Y dos.")
    win.pause_at(11)
    Pages.poll
    win.draw_all
    Pages.poll
    Pages.close(win)
    assert_equal [["Niño, 2 izquierda: Cuento uno.", true], ["Y dos.", true]], SpeakCapture.log
  end

  test "keeps the message led by its head for the repeat key" do
    PokeAccess.before_next_line("Niño, 2 izquierda")
    win = follow("Cuento uno. Y dos.", "Cuento uno.\1Y dos.")
    win.draw_all
    Pages.poll
    Pages.close(win)
    assert_equal "Niño, 2 izquierda: Cuento uno. Y dos.", PokeAccess.last_dialogue
  end

  test "leads a message never followed with its head when it says it whole" do
    PokeAccess.before_next_line("Niña, 1 arriba")
    Pages.close(follow("Nadie la vio."))
    assert_equal [["Niña, 1 arriba: Nadie la vio.", false]], SpeakCapture.log
  end

  test "keeps the head for the first page that says something, past a blank one" do
    PokeAccess.before_next_line("Niño")
    win = follow("Hola de nuevo.", "   \1Hola de nuevo.")
    win.pause_at(3)
    Pages.poll
    win.draw_all
    Pages.poll
    assert_equal [["Niño: Hola de nuevo.", true]], SpeakCapture.log
  end

  test "follows each message afresh: one never drawn is said whole after one heard by pages" do
    win = follow("Otra.", "Otra.")
    win.draw_all
    Pages.poll
    Pages.close(win)
    SpeakCapture.clear
    Pages.close(follow("Nadie la dibujó."))
    assert_equal [["Nadie la dibujó.", false]], SpeakCapture.log
  end

  test "reads a new text the window shows from its start" do
    win = follow("Uno.", "Uno.")
    win.draw_all
    Pages.poll
    win.show("Dos.")
    win.draw_all
    Pages.poll
    assert_equal [["Uno.", true], ["Dos.", true]], SpeakCapture.log
  end

  test "stops following the window once the message closes" do
    win = follow("Uno.", "Uno.")
    win.draw_all
    Pages.poll
    Pages.close(win)
    SpeakCapture.clear
    win.show("Dos.")
    win.draw_all
    Pages.poll
    assert_nothing_spoken
  end

  test "closing another window leaves the message it follows alone" do
    win = follow("Nadie la dibujó.")
    Pages.close(MessageWindow.new)
    assert_nothing_spoken
    Pages.close(win)
    assert_equal [["Nadie la dibujó.", false]], SpeakCapture.log
  end

  test "says nothing of a window whose characters are gone, and the message whole as it closes" do
    win = follow("Nadie la vio.", "Nadie la vio.")
    win.draw_all
    win.chars = nil
    Pages.poll
    assert_nothing_spoken
    Pages.close(win)
    assert_equal [["Nadie la vio.", false]], SpeakCapture.log
  end

  test "survives a window whose characters cannot be read, and stops following it as it closes" do
    win = follow("Rota.", "Rota.")
    win.chars = [Unprintable.new]
    win.draw_all
    Pages.poll
    Pages.close(win)
    SpeakCapture.clear
    win.show("Otra vez.")
    win.draw_all
    Pages.poll
    assert_nothing_spoken
  end

  test "waits on a window whose page state cannot be read, as if it were still drawing" do
    [:pausing?, :busy?].each do |state|
      forget_dialogue
      win = follow("Hola. Adiós.", "Hola.\1Adiós.")
      win.define_singleton_method(state) { raise "unreadable" }
      win.draw_to(5)
      Pages.poll
      assert_nothing_spoken "with #{state} raising"
    end
  end

  test "leaves a message drawn all at once to the whole reading" do
    PokeAccess::Config.dialogue_pages = true
    assert_equal false, Pages.open(MessageWindow.new, "Hola.", false)
  end

  test "leaves a message shown inside another to the whole reading" do
    PokeAccess::Config.dialogue_pages = true
    PokeAccess.message_enter
    assert_equal false, Pages.open(MessageWindow.new, "Hola.", true)
  ensure
    PokeAccess.message_leave
  end

  test "leaves a window it cannot follow to the whole reading" do
    PokeAccess::Config.dialogue_pages = true
    no_chars = MessageWindow.new
    no_chars.chars = nil
    text_only = Object.new
    text_only.instance_variable_set(:@textchars, [])
    { "a window that does not page" => Object.new, "a paging window with no characters" => no_chars,
      "a text window with no page breaks" => text_only }.each do |what, win|
      assert_equal false, Pages.open(win, "Hola.", true), what
    end
  end

  test "leaves a message it cannot read to the whole reading" do
    PokeAccess::Config.dialogue_pages = true
    assert_equal false, Pages.open(MessageWindow.new, Unprintable.new, true)
  end

  test "does not say again a line a reader has just said, page or whole" do
    PokeAccess.say_dialogue("Has obtenido una Poción.")
    SpeakCapture.clear
    win = follow("Has obtenido una Poción.", "Has obtenido una Poción.")
    win.draw_all
    Pages.poll
    Pages.close(win)
    assert_nothing_spoken
  end

  test "the message hook reads a message by pages while the option is on" do
    PokeAccess::Config.dialogue_pages = true
    display(MessageWindow.new, "Uno.\1Dos.", true)
    assert_equal [["Uno.", true], ["Dos.", true]], SpeakCapture.log
  end

  test "the message hook says a message the engine never drew whole as it closes, while the option is on" do
    PokeAccess::Config.dialogue_pages = true
    assert_equal [], display(MessageWindow.new, "Desde el motor.", false), "nothing as it opens"
    assert_equal [["Desde el motor.", false]], SpeakCapture.log, "the whole message as it closes"
  end

  test "the message hook lets the window go once the message closes" do
    PokeAccess::Config.dialogue_pages = true
    win = MessageWindow.new
    display(win, "Uno.", true)
    SpeakCapture.clear
    win.show("Otra.")
    win.draw_all
    Pages.poll
    assert_nothing_spoken
  end

  test "the message hook says the message whole as it opens while the option is off" do
    assert_equal [["Uno. Dos.", false]], display(MessageWindow.new, "Uno.\1Dos.", true), "as it opens"
    assert_equal [["Uno. Dos.", false]], SpeakCapture.log, "and nothing as the window draws it"
  end

  private

  # Turns the option on and opens message on a new window that then shows text (when given) as setText does; the
  # window, with nothing said yet.
  def follow(message, text = nil)
    PokeAccess::Config.dialogue_pages = true
    win = MessageWindow.new
    Pages.open(win, message, true)
    win.show(text) if text
    SpeakCapture.clear
    win
  end

  # Shows message on win through the message hook, the engine's display stood in for by one that, when draw is true,
  # draws it page by page ("\1" a break), polled at each break and at the end as the frame's pulse polls; answers what
  # had been said when the display began. The stub's own display is put back afterwards.
  def display(win, message, draw)
    started = nil
    k = Kernel.singleton_class
    k.send(:alias_method, :pa_spec_display, :pbMessageDisplay__access_orig)
    k.send(:define_method, :pbMessageDisplay__access_orig) do |w, text, *_args|
      started = SpeakCapture.log.dup
      next unless draw
      w.show(text)
      text.split(//).each_with_index { |c, i| (w.pause_at(i); Pages.poll) if c == "\1" }
      w.draw_all
      Pages.poll
    end
    Kernel.pbMessageDisplay(win, message)
    started
  ensure
    k.send(:alias_method, :pbMessageDisplay__access_orig, :pa_spec_display)
    k.send(:remove_method, :pa_spec_display)
  end

  # Drops what a message leaves behind for the next one: the window followed, a promised head or tail, the line just
  # said (the half-second guard against a copy) and the depth of messages inside messages.
  def forget_dialogue
    Pages.instance_variable_set(:@win, nil)
    PokeAccess.take_head
    PokeAccess.take_tail
    PokeAccess.instance_variable_set(:@last_say, nil)
    PokeAccess.instance_variable_set(:@msg_depth, 0)
  end
end
