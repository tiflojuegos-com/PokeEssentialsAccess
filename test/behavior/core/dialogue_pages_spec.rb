# DialoguePages (off by default): each page said as the window draws it, cutting the one before; a message never
# followed is said whole on closing; what it cannot follow keeps the whole-message reading.
class PagesSpecWindow
  attr_accessor :pausing, :busy
  def initialize; @textchars = []; @curchar = 0; @pausing = false; @busy = true; end
  def pausing?; @pausing; end
  def busy?; @busy; end
  # What setText does: a fresh array of characters, drawn from the start.
  def show(text); @textchars = text.split(//); @curchar = 0; end
  def draw_to(i); @curchar = i; end
  def draw_all; @curchar = @textchars.length; @busy = false; @pausing = false; end
end

def with_dialogue_pages(on)
  had = PokeAccess::Config.dialogue_pages
  PokeAccess::Config.dialogue_pages = on
  yield
ensure
  PokeAccess::Config.dialogue_pages = had
end

Suite.define("dialogue pages: each page is said as the window shows it, cutting the one before") do
  dp = PokeAccess::DialoguePages
  with_dialogue_pages(true) do
    win = PagesSpecWindow.new
    SpeakCapture.clear
    truthy "the message is taken over", dp.open(win, "Primera línea. Segunda página.", true)
    eq "and nothing is said before the window draws it", SpeakCapture.lines, []
    win.show("Primera línea.\1Segunda página.")
    win.draw_to(14)
    win.pausing = true
    dp.poll
    eq "the first page at its break", SpeakCapture.log, [["Primera línea.", true]]
    dp.poll
    eq "once", SpeakCapture.log.length, 1
    win.draw_all
    dp.poll
    eq "the last page when the window finishes", SpeakCapture.log.last, ["Segunda página.", true]
    SpeakCapture.clear
    dp.close(win)
    eq "and nothing again on closing", SpeakCapture.lines, []
    eq "the repeat key has the whole message", PokeAccess.last_dialogue, "Primera línea. Segunda página."
  end
end

Suite.define("dialogue pages: a message never followed is said whole when it closes") do
  dp = PokeAccess::DialoguePages
  with_dialogue_pages(true) do
    win = PagesSpecWindow.new
    SpeakCapture.clear
    dp.open(win, "Nadie la dibujó.", true)
    dp.close(win)
    eq "said whole, queued", SpeakCapture.log, [["Nadie la dibujó.", false]]
    PokeAccess.after_next_line("Es variocolor.")
    SpeakCapture.clear
    dp.open(win, "Otra.", true)
    win.show("Otra.")
    win.draw_all
    dp.poll
    dp.close(win)
    eq "the line promised for after it follows", SpeakCapture.lines, ["Otra.", "Es variocolor."]
    PokeAccess::History.clear
    dp.open(win, "Una pregunta final.", true)
    win.show("Una pregunta final.")
    win.draw_all
    dp.close(win)
    eq "what it says on closing is filed as dialogue in the history",
       PokeAccess::History.lines_of(:dialogue).map { |m| m.text }, ["Una pregunta final."]
  end
end

Suite.define("dialogue pages: a promised head leads the first page heard, or the whole message") do
  dp = PokeAccess::DialoguePages
  with_dialogue_pages(true) do
    win = PagesSpecWindow.new
    PokeAccess.before_next_line("Niño, 2 izquierda")
    SpeakCapture.clear
    dp.open(win, "Cuento uno. Y dos.", true)
    win.show("Cuento uno.\1Y dos.")
    win.draw_to(11)
    win.pausing = true
    dp.poll
    win.draw_all
    dp.poll
    dp.close(win)
    eq "the head leads the first page only", SpeakCapture.log,
       [["Niño, 2 izquierda: Cuento uno.", true], ["Y dos.", true]]
    eq "and the repeat key has the message led", PokeAccess.last_dialogue, "Niño, 2 izquierda: Cuento uno. Y dos."

    unseen = PagesSpecWindow.new
    PokeAccess.before_next_line("Niña, 1 arriba")
    SpeakCapture.clear
    dp.open(unseen, "Nadie la vio.", true)
    dp.close(unseen)
    eq "a message never followed is said whole, led", SpeakCapture.log, [["Niña, 1 arriba: Nadie la vio.", false]]
  end
end

Suite.define("dialogue pages: what it cannot follow keeps the whole-message reading") do
  dp = PokeAccess::DialoguePages
  win = PagesSpecWindow.new
  with_dialogue_pages(false) { falsy "off by default and when turned off", dp.open(win, "Hola.", true) }
  with_dialogue_pages(true) do
    falsy "a message drawn all at once", dp.open(win, "Hola.", false)
    PokeAccess.message_enter
    falsy "a message inside a message", dp.open(win, "Hola.", true)
    PokeAccess.message_leave
    falsy "a window that does not page", dp.open(Object.new, "Hola.", true)
    PokeAccess.say_dialogue("Has obtenido una Poción.")
    SpeakCapture.clear
    dp.open(win, "Has obtenido una Poción.", true)
    win.show("Has obtenido una Poción.")
    win.draw_all
    dp.poll
    dp.close(win)
    eq "a line a reader has just said is not said again, page or whole", SpeakCapture.lines, []
  end
end

Suite.define("dialogue pages: the message function hands the message over when the option is on") do
  with_dialogue_pages(true) do
    win = PagesSpecWindow.new
    SpeakCapture.clear
    Kernel.pbMessageDisplay(win, "Desde el motor.")
    eq "the stub draws nothing, so it is said whole as it closes", SpeakCapture.log, [["Desde el motor.", false]]
  end
  with_dialogue_pages(false) do
    SpeakCapture.clear
    Kernel.pbMessageDisplay(PagesSpecWindow.new, "Entero.")
    eq "off, the message is said whole as it opens", SpeakCapture.lines, ["Entero."]
  end
end
