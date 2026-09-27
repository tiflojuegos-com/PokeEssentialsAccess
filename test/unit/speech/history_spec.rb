# The message history (Home and End; ctrl to the ends, shift between categories): its own readouts are not filed, a
# repaint is filed once, the oldest lines go past the capacity, and a view keeps its place as lines arrive.
Suite.define("history: files every line said with its category, but not its own readouts or a repeat") do
  h = PokeAccess::History
  h.clear
  PokeAccess.speak("Hola", true, :dialogue)
  PokeAccess.speak("Hola", true, :dialogue)
  PokeAccess.speak("Hola", true, :menu)
  PokeAccess.speak("Lectura del historial", true, PokeAccess::Speech::REVIEW)
  eq "the same line in the same category is filed once, in another category again",
     h.lines_of(h::ALL).map { |m| [m.text, m.category] }, [["Hola", :dialogue], ["Hola", :menu]]

  h.clear
  eq "it keeps as many lines as the setting says, 300 by default", h.capacity, 300
  PokeAccess::Config.history_size = 100
  105.times { |i| PokeAccess.speak("linea #{i}", true, :nav) }
  eq "past that size the oldest lines go", h.lines_of(h::ALL).length, 100
  eq "and the newest is kept", h.lines_of(h::ALL).last.text, "linea 104"
  PokeAccess::Config.history_size = 50
  PokeAccess.speak("otra", true, :nav)
  eq "a smaller size takes effect with the next line filed", h.lines_of(h::ALL).length, 50
  row = PokeAccess::Config.schema_row(:history_size)
  eq "the setting sits in the general options", row[3], :general
  PokeAccess::Config.history_size = 2000
  PokeAccess::ConfigMenu.adjust_setting(row, 1)
  eq "and the menu keeps it within its bounds", PokeAccess::Config.history_size, 2000
  PokeAccess::Settings.set_numeric(:history_size, "5", :msgs)
  eq "as does a settings file edited by hand", PokeAccess::Config.history_size, 100
  h.clear
end

Suite.define("history: steps back and on, stops at each end, and keeps its place when new lines arrive") do
  h = PokeAccess::History
  t = PokeAccess::I18n
  h.clear
  SpeakCapture.clear
  h.step(-1)
  eq "an empty history says so, naming the view", SpeakCapture.last, t.t(:hist_empty, :name => t.t(:msg_cat_all))

  PokeAccess.speak("uno", true, :dialogue)
  PokeAccess.speak("dos", true, :battle)
  PokeAccess.speak("tres", true, :dialogue)
  SpeakCapture.clear
  h.step(-1)
  eq "the first press reads the latest line, whichever way", SpeakCapture.last, "tres"
  h.step(-1)
  h.step(-1)
  eq "each press goes one back", SpeakCapture.lines, ["tres", "dos", "uno"]
  h.step(-1)
  eq "and past the first it says so and stays", SpeakCapture.last, t.t(:hist_top)
  h.step(1)
  eq "so the next press forward is the second line", SpeakCapture.last, "dos"

  PokeAccess.speak("cuatro", true, :menu)
  SpeakCapture.clear
  h.step(1)
  eq "a line said meanwhile does not move the cursor", SpeakCapture.last, "tres"
  h.to_end(1)
  eq "ctrl and forward is the last line", SpeakCapture.last, "cuatro"
  h.step(1)
  eq "past which it says it is the end", SpeakCapture.last, t.t(:hist_bottom)
  h.to_end(-1)
  eq "and ctrl and back the first", SpeakCapture.last, "uno"
  falsy "none of the readouts was filed", h.lines_of(h::ALL).any? { |m| m.text == t.t(:hist_bottom) }
  h.clear
end

Suite.define("history: shift moves between the categories that hold something, each with its own place") do
  h = PokeAccess::History
  t = PokeAccess::I18n
  h.clear
  PokeAccess.speak("uno", true, :dialogue)
  PokeAccess.speak("paso", true, :nav)
  PokeAccess.speak("dos", true, :dialogue)
  SpeakCapture.clear
  h.switch_category(1)
  eq "the next view with lines is named with how many it holds", SpeakCapture.last,
     t.t(:hist_view, :name => t.t(:msg_cat_dialogue), :n => 2)
  h.step(-1)
  h.step(-1)
  eq "and inside it only its own lines are read", SpeakCapture.lines.last(2), ["dos", "uno"]
  h.switch_category(1)
  eq "the empty categories between are skipped", SpeakCapture.last, t.t(:hist_view, :name => t.t(:msg_cat_nav), :n => 1)
  h.switch_category(-1)
  h.step(1)
  eq "and a view taken up again goes on from where it was left", SpeakCapture.last, "dos"
  h.switch_category(1)
  h.switch_category(1)
  eq "the view of everything is always offered, and the list wraps to it",
     SpeakCapture.last, t.t(:hist_view, :name => t.t(:msg_cat_all), :n => 3)
  h.clear
end

Suite.define("history: a place whose line has gone resumes at the next line still kept") do
  h = PokeAccess::History
  h.clear
  PokeAccess.speak("viejo", true, :nav)
  PokeAccess.speak("medio", true, :nav)
  PokeAccess.speak("nuevo", true, :nav)
  SpeakCapture.clear
  3.times { h.step(-1) }
  eq "the cursor rests on the oldest line", SpeakCapture.last, "viejo"
  h.lines_of(h::ALL).shift
  h.step(1)
  eq "and when that line is dropped the next press on reads the line that followed it", SpeakCapture.last, "medio"
  h.lines_of(h::ALL).shift
  h.lines_of(h::ALL).shift
  PokeAccess.speak("otro", true, :nav)
  SpeakCapture.clear
  h.step(-1)
  eq "and back from a place older than every line kept is the start", SpeakCapture.last,
     PokeAccess::I18n.t(:hist_top)
  h.clear
end

Suite.define("history: Home and End drive it, ctrl to the ends and shift between categories") do
  h = PokeAccess::History
  k = PokeAccess::Keys
  saved = [k.method(:ctrl_down?), k.method(:shift_down?)]
  h.clear
  PokeAccess.speak("uno", true, :dialogue)
  PokeAccess.speak("dos", true, :battle)
  begin
    k.define_singleton_method(:ctrl_down?) { false }
    k.define_singleton_method(:shift_down?) { false }
    SpeakCapture.clear
    k.history_key(-1)
    eq "the previous key alone steps back", SpeakCapture.last, "dos"
    k.define_singleton_method(:ctrl_down?) { true }
    k.history_key(-1)
    eq "with ctrl it goes to the first", SpeakCapture.last, "uno"
    k.define_singleton_method(:ctrl_down?) { false }
    k.define_singleton_method(:shift_down?) { true }
    k.history_key(1)
    eq "with shift it changes category", SpeakCapture.last,
       PokeAccess::I18n.t(:hist_view, :name => PokeAccess::I18n.t(:msg_cat_dialogue), :n => 1)
  ensure
    k.define_singleton_method(:ctrl_down?, saved[0])
    k.define_singleton_method(:shift_down?, saved[1])
    h.clear
  end
  eq "the history keys ship on Home and End", [PokeAccess::Config::KEY_DEFAULTS[:hist_prev],
                                               PokeAccess::Config::KEY_DEFAULTS[:hist_next]], [0x24, 0x23]
  truthy "and both can be remapped", PokeAccess::Remap.mod_action?(:hist_prev) && PokeAccess::Remap.mod_action?(:hist_next)
end
