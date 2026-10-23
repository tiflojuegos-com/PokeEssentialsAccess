# The message history (History): the lines it files and keeps, how its keys step through a view, go to its ends and
# change category, and the place each view keeps as lines come and go.
class HistoryTest < PokeAccessTest
  H = PokeAccess::History
  T = PokeAccess::I18n

  test "files every line said with its category, oldest first" do
    three_lines
    assert_equal [["uno", :dialogue], ["dos", :battle], ["tres", :dialogue]], filed
  end

  test "never files its own readouts" do
    PokeAccess.speak(T.t(:hist_top), true, PokeAccess::Speech::REVIEW)
    assert_equal [], filed
  end

  test "files a repaint of the last line, in its category and within a second, only once" do
    assert_equal [["Hola", :dialogue]], filed_on_clock([["Hola", :dialogue, 10.0], ["Hola", :dialogue, 10.5]])
  end

  test "files the same line again once a second has passed since it was said" do
    assert_equal [["Hola", :dialogue], ["Hola", :dialogue]],
                 filed_on_clock([["Hola", :dialogue, 10.0], ["Hola", :dialogue, 11.0]])
  end

  test "keeps a line repainted without pause as one, each repaint starting the second again" do
    lines = [10.0, 10.6, 11.2, 11.8].map { |second| ["Hola", :dialogue, second] }
    assert_equal [["Hola", :dialogue]], filed_on_clock(lines)
  end

  test "files the same text again under another category or after another line" do
    {
      [["Hola", :dialogue, 10.0], ["Hola", :menu, 10.1]] => [["Hola", :dialogue], ["Hola", :menu]],
      [["Hola", :dialogue, 10.0], ["Adiós", :dialogue, 10.1], ["Hola", :dialogue, 10.2]] =>
        [["Hola", :dialogue], ["Adiós", :dialogue], ["Hola", :dialogue]]
    }.each do |lines, want|
      H.clear
      assert_equal want, filed_on_clock(lines), "for #{lines.inspect}"
    end
  end

  test "keeps 300 lines unless its size setting says otherwise" do
    assert_equal 300, H.capacity
  end

  test "drops the oldest lines past its size" do
    PokeAccess::Config.history_size = 3
    5.times { |i| say("linea #{i}", :nav) }
    assert_equal ["linea 2", "linea 3", "linea 4"], filed.map { |text, _category| text }
  end

  test "takes a smaller size into account with the next line filed" do
    PokeAccess::Config.history_size = 5
    5.times { |i| say("linea #{i}", :nav) }
    PokeAccess::Config.history_size = 2
    kept_before = filed.length
    say("nueva", :nav)
    assert_equal [5, ["linea 4", "nueva"]], [kept_before, filed.map { |text, _category| text }]
  end

  test "keeps at least the newest line whatever its size says" do
    { 0 => 1, -3 => 1, nil => 1 }.each do |size, want|
      PokeAccess::Config.history_size = size
      assert_equal want, H.capacity, "for a size of #{size.inspect}"
    end
    say("uno", :nav)
    say("dos", :nav)
    assert_equal [["dos", :nav]], filed
  end

  test "lists its size setting with the general options" do
    assert_equal :general, PokeAccess::Config.setting(:history_size).group
  end

  test "bounds its size from 100 to 2000 lines, as the menu steps it and as a settings file edited by hand gives it" do
    row = PokeAccess::Config.setting(:history_size)
    { [2000, 1] => 2000, [100, -1] => 100 }.each do |(from, dir), want|
      PokeAccess::Config.history_size = from
      PokeAccess::ConfigMenu.adjust_setting(row, dir)
      assert_equal want, PokeAccess::Config.history_size, "a step #{dir > 0 ? 'right' : 'left'} from #{from}"
    end
    { "5" => 100, "5000" => 2000, "700" => 700 }.each do |text, want|
      assert_equal want, PokeAccess::Config.parse(row, text), "a file saying #{text}"
    end
  end

  test "says an empty history is empty, naming its view, for every key" do
    [[:step, -1], [:step, 1], [:to_end, -1], [:to_end, 1]].each do |meth, dir|
      assert_equal [T.t(:hist_empty, :name => T.t(:msg_cat_all))], pressing { H.send(meth, dir) }, "#{meth}(#{dir})"
    end
  end

  test "reads the newest line on the first press, whichever way" do
    [-1, 1].each do |dir|
      H.clear
      three_lines
      assert_equal ["tres"], pressing { H.step(dir) }, "the first press #{dir < 0 ? 'back' : 'on'}"
    end
  end

  test "steps back a line per press, saying the start past the first and staying there" do
    three_lines
    assert_equal ["tres", "dos", "uno", T.t(:hist_top), T.t(:hist_top)], pressing { 5.times { H.step(-1) } }
    assert_equal ["dos"], pressing { H.step(1) }, "the press on from the start is the second line"
  end

  test "steps on a line per press, saying the end past the newest and staying there" do
    three_lines
    H.to_end(-1)
    assert_equal ["dos", "tres", T.t(:hist_bottom), T.t(:hist_bottom)], pressing { 4.times { H.step(1) } }
    assert_equal ["dos"], pressing { H.step(-1) }, "the press back from the end is the line before the newest"
  end

  test "goes with ctrl to the first or the newest line, its place left there" do
    three_lines
    assert_equal ["uno", "dos", "tres", "dos"], pressing { H.to_end(-1); H.step(1); H.to_end(1); H.step(-1) }
  end

  test "keeps its place as new lines arrive" do
    three_lines
    2.times { H.step(-1) }
    say("cuatro", :menu)
    assert_equal ["tres"], pressing { H.step(1) }
  end

  test "cuts in with its readouts and files none of them" do
    three_lines
    SpeakCapture.clear
    H.step(-1)
    H.step(1)
    H.switch_category(1)
    assert_equal [["tres", true], [T.t(:hist_bottom), true], [view_line(:msg_cat_dialogue, 2), true]], SpeakCapture.log
    assert_equal [["uno", :dialogue], ["dos", :battle], ["tres", :dialogue]], filed
  end

  test "goes on from a place whose line was dropped at the oldest line kept" do
    resting_on_a_dropped_line
    assert_equal ["medio"], pressing { H.step(1) }
  end

  test "says the start going back from a place whose line was dropped" do
    resting_on_a_dropped_line
    assert_equal [T.t(:hist_top)], pressing { H.step(-1) }
  end

  test "says a category's view is empty, by its name, once all its lines were dropped" do
    PokeAccess::Config.history_size = 2
    say("golpe", :battle)
    say("paso", :nav)
    H.switch_category(1)
    say("otro paso", :nav)
    assert_equal [T.t(:hist_empty, :name => T.t(:msg_cat_battle))], pressing { H.step(-1) }
  end

  test "goes with shift to the next category holding lines, said with how many it holds" do
    mixed_lines
    assert_equal [view_line(:msg_cat_dialogue, 2)], pressing { H.switch_category(1) }
  end

  test "skips the categories that hold nothing, either way" do
    mixed_lines
    H.switch_category(1)
    assert_equal [view_line(:msg_cat_nav, 1), view_line(:msg_cat_dialogue, 2)],
                 pressing { H.switch_category(1); H.switch_category(-1) }
  end

  test "wraps round to the view of everything, and back from it to the last category holding lines" do
    mixed_lines
    2.times { H.switch_category(1) }
    assert_equal [view_line(:msg_cat_all, 3), view_line(:msg_cat_nav, 1)],
                 pressing { H.switch_category(1); H.switch_category(-1) }
  end

  test "offers the view of everything even with nothing filed" do
    assert_equal [view_line(:msg_cat_all, 0), view_line(:msg_cat_all, 0)],
                 pressing { H.switch_category(1); H.switch_category(-1) }
  end

  test "reads only a category's own lines inside its view" do
    mixed_lines
    H.switch_category(1)
    assert_equal ["dos", "uno", T.t(:hist_top)], pressing { 3.times { H.step(-1) } }
  end

  test "keeps each view's place apart, taken up again where it was left" do
    mixed_lines
    say("giro", :nav)
    H.switch_category(1)
    2.times { H.step(-1) }
    H.switch_category(1)
    H.step(-1)
    H.switch_category(-1)
    assert_equal ["dos"], pressing { H.step(1) }, "the dialogue view goes on from its first line"
    H.switch_category(-1)
    assert_equal ["giro"], pressing { H.step(-1) }, "the view of everything, not browsed yet, starts at the newest"
  end

  test "takes its keys alone a line back or on, with ctrl to the first or newest line and with shift to another view" do
    {
      [nil, -1] => "dos", [nil, 1] => T.t(:hist_bottom), [:ctrl, -1] => "uno", [:ctrl, 1] => "tres",
      [:shift, 1] => view_line(:msg_cat_dialogue, 2), [:shift, -1] => view_line(:msg_cat_battle, 1)
    }.each do |(held, dir), want|
      H.clear
      three_lines
      H.to_end(1)
      assert_equal [want], pressing { holding(held) { PokeAccess::Keys.history_key(dir) } },
                   "the #{dir < 0 ? 'previous' : 'next'} key with #{held || 'no modifier'}, resting on the newest line"
    end
  end

  test "lets the player remap both of its keys as keys of the mod's own, not as game buttons" do
    assert_equal [true, true], [:hist_prev, :hist_next].map { |key| PokeAccess::Remap.mod_action?(key) }
  end

  test "forgets every line, every place and the view it was in when cleared" do
    say("uno", :dialogue)
    H.step(-1)
    H.switch_category(1)
    H.clear
    assert_equal [T.t(:hist_empty, :name => T.t(:msg_cat_all))], pressing { H.step(-1) },
                 "nothing kept, back in the view of everything"
    say("dos", :dialogue)
    assert_equal ["dos"], pressing { H.step(-1) }, "and no place left from before"
  end

  private

  # Says a line under a category, as the mod's readers do.
  def say(text, category)
    PokeAccess.speak(text, true, category)
  end

  # Two dialogue lines with a battle line between them.
  def three_lines
    say("uno", :dialogue)
    say("dos", :battle)
    say("tres", :dialogue)
  end

  # Two dialogue lines with a step on the map between them.
  def mixed_lines
    say("uno", :dialogue)
    say("paso", :nav)
    say("dos", :dialogue)
  end

  # Three lines in a history of three with the place on the oldest, then a fourth line that drops it.
  def resting_on_a_dropped_line
    PokeAccess::Config.history_size = 3
    ["viejo", "medio", "nuevo"].each { |text| say(text, :nav) }
    3.times { H.step(-1) }
    say("otro", :nav)
  end

  # The lines the history holds, oldest first, as [text, category].
  def filed
    H.lines_of(H::ALL).map { |m| [m.text, m.category] }
  end

  # What the block's presses said.
  def pressing
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  # Runs the block with only the modifier held (:ctrl, :shift or nil) down, the real probes put back after.
  def holding(held)
    keys = PokeAccess::Keys
    real = [keys.method(:ctrl_down?), keys.method(:shift_down?)]
    keys.define_singleton_method(:ctrl_down?) { held == :ctrl }
    keys.define_singleton_method(:shift_down?) { held == :shift }
    yield
  ensure
    keys.define_singleton_method(:ctrl_down?, real[0])
    keys.define_singleton_method(:shift_down?, real[1])
  end

  # How a category change names the view with the label key name and its count of lines.
  def view_line(name, n)
    T.t(:hist_view, :name => T.t(name), :n => n)
  end

  # The lines filed after saying each [text, category, second] in turn on a clock stopped at that second; the real
  # clock is put back after.
  def filed_on_clock(lines)
    real = PokeAccess.method(:clock)
    now = nil
    PokeAccess.define_singleton_method(:clock) { now }
    lines.each do |text, category, second|
      now = second
      say(text, category)
    end
    filed
  ensure
    PokeAccess.define_singleton_method(:clock, real)
  end
end
