# The speech dispatcher (PokeAccess.speak, Speech): every line reaches each observer as a message (text, category,
# interrupt, number) and then the reader; its category is the call's, else the innermost scope's, else the moment's.
class SpeechTest < PokeAccessTest
  Speech = PokeAccess::Speech
  KEY = :speech_test
  FAILING = :speech_test_failing

  test "hands each line to the observers with its text, category and whether it cuts in, then to the reader" do
    seen = observing do
      PokeAccess.speak("uno", false, :battle)
      PokeAccess.speak("dos", true, :menu)
    end
    assert_equal [["uno", :battle, false], ["dos", :menu, true]], seen.map { |m| [m.text, m.category, m.interrupt] }
    assert_equal [["uno", false], ["dos", true]], SpeakCapture.log
  end

  test "numbers each line one past the line before" do
    before = PokeAccess.spoken_seq
    seen = observing { ["uno", "dos", "tres"].each { |text| PokeAccess.speak(text) } }
    assert_equal [before + 1, before + 2, before + 3], seen.map { |m| m.seq }
  end

  test "counts the session's lines from none, its first line numbered one" do
    in_fresh_session do
      before = PokeAccess.spoken_seq
      seen = observing { PokeAccess.speak("uno") }
      assert_equal [0, 1, [1]], [before, PokeAccess.spoken_seq, seen.map { |m| m.seq }]
    end
  end

  test "collapses and trims a line's whitespace before anyone hears it" do
    seen = observing { PokeAccess.speak("  Hola \n\t mundo  ") }
    assert_equal [["Hola mundo"], [["Hola mundo", true]]], [seen.map { |m| m.text }, SpeakCapture.log]
  end

  test "says, hands on and numbers nothing for a blank line" do
    before = PokeAccess.spoken_seq
    seen = observing { [nil, "", " \n\t "].each { |text| PokeAccess.speak(text) } }
    assert_equal [[], [], before], [seen, SpeakCapture.log, PokeAccess.spoken_seq]
  end

  test "remembers the last line spoken, which a blank line leaves as it was" do
    PokeAccess.speak("  Hola   mundo ")
    PokeAccess.speak("  ")
    assert_equal "Hola mundo", PokeAccess.last_spoken
  end

  test "writes a failure while filing a line to the marker file instead of raising" do
    mark = PokeAccess.marker_file
    before = File.exist?(mark) ? File.size(mark) : 0
    at_moment { failing(PokeAccess::Control, :on_map?) { PokeAccess.speak("uno") } }
    assert_match(/speak_error: RuntimeError: a probe fails @ /, File.binread(mark)[before..-1])
  end

  test "speaks game text with its control codes stripped, cutting in and filed by the moment unless told otherwise" do
    seen = at_moment do
      observing do
        PokeAccess.speak_clean("\\c[2]Hola\\n mundo")
        PokeAccess.speak_clean("<b>Adiós</b>", false, :battle)
      end
    end
    assert_equal [[["Hola mundo", true], ["Adiós", false]], [:nav, :battle]],
                 [SpeakCapture.log, seen.map { |m| m.category }]
  end

  test "files a line under the category its call names, whatever scope it is in" do
    seen = observing { Speech.as(:menu) { PokeAccess.speak("uno", true, :battle) } }
    assert_equal [:battle], seen.map { |m| m.category }
  end

  test "files an unnamed line under the innermost scope, and the outer one's again once that ends" do
    seen = observing do
      Speech.as(:menu) do
        Speech.as(:info) { PokeAccess.speak("uno") }
        PokeAccess.speak("dos")
      end
    end
    assert_equal [:info, :menu], seen.map { |m| m.category }
  end

  test "files an unnamed line outside every scope under the moment" do
    seen = at_moment(:message => true) { observing { PokeAccess.speak("uno") } }
    assert_equal [:dialogue], seen.map { |m| m.category }
  end

  test "ends a scope its block leaves by an exception" do
    seen = at_moment do
      (Speech.as(:info) { raise "a reader fails" } rescue nil)
      observing { PokeAccess.speak("uno") }
    end
    assert_equal [:nav], seen.map { |m| m.category }
  end

  test "tells the moment from the game: a fight, then a message, then the map under free control, else a menu" do
    {
      {} => :nav,
      { :in_menu => true } => :menu,
      { :scene => :other } => :menu,
      { :message => true } => :dialogue,
      { :message => true, :scene => :other } => :dialogue,
      { :battle => true } => :battle,
      { :battle => true, :message => true } => :battle
    }.each do |moment, want|
      assert_equal want, at_moment(moment) { Speech.deduce }, "at #{moment.inspect}"
    end
  end

  test "takes a moment's probe that fails for that moment not holding" do
    [[PokeAccess::Battle, :in_battle?], [PokeAccess, :message_depth]].each do |mod, probe|
      assert_equal :nav, at_moment { failing(mod, probe) { Speech.deduce } }, "#{mod}.#{probe} failing"
    end
  end

  test "names the categories the history offers, and none for its own readouts or an unknown one" do
    assert_equal [:msg_cat_dialogue, :msg_cat_system, nil, nil],
                 [:dialogue, :system, Speech::REVIEW, :unknown].map { |category| Speech.label(category) }
  end

  test "replaces an observer registered again under its key" do
    heard = []
    Speech.observe(KEY) { |m| heard.push("first #{m.text}") }
    Speech.observe(KEY) { |m| heard.push("again #{m.text}") }
    PokeAccess.speak("hola")
    assert_equal ["again hola"], heard
  ensure
    Speech.unobserve(KEY)
  end

  test "stops only the observer taken off by its key" do
    heard = []
    Speech.observe(KEY) { |m| heard.push(m.text) }
    Speech.unobserve(KEY)
    PokeAccess.speak("hola", true, :menu)
    filed = PokeAccess::History.lines_of(PokeAccess::History::ALL).map { |m| [m.text, m.category] }
    assert_equal [[], [["hola", :menu]]], [heard, filed]
  ensure
    Speech.unobserve(KEY)
  end

  test "passes over an observer that fails, logged under its key, the others and the reader still getting the line" do
    heard = []
    forgetting_log("observer_#{FAILING}") do
      Speech.observe(FAILING) { |_m| raise "an instrument fails" }
      Speech.observe(KEY) { |m| heard.push(m.text) }
      PokeAccess.speak("hola")
      assert_equal [["hola"], [["hola", true]]], [heard, SpeakCapture.log]
      assert_match(/\ARuntimeError: an instrument fails @ /, PokeAccess.logged["observer_#{FAILING}"])
    end
  ensure
    Speech.unobserve(FAILING)
    Speech.unobserve(KEY)
  end

  test "files a pause panel's lines as a menu" do
    seen = with_fresh_pause_panel { observing { PokeAccess::PausePanel.say(["Dinero: 500"]) } }
    assert_equal [["Dinero: 500", :menu]], seen.map { |m| [m.text, m.category] }
  end

  private

  # The messages the observers got while the block ran, through an observer of this test's own, taken off after.
  def observing
    seen = []
    Speech.observe(KEY) { |msg| seen.push(msg) }
    yield
    seen
  ensure
    Speech.unobserve(KEY)
  end

  # The block's value at a moment of the game: the map under free control unless moment says otherwise (:scene
  # :other for another screen, :in_menu its pause menu, :message a message on screen, :battle a fight); the scene,
  # the temp, the message depth and the fight are put back after.
  def at_moment(moment = {})
    had = [$scene, $game_temp, PokeAccess.message_depth, PokeAccess::Battle.in_battle?]
    $scene = moment[:scene] == :other ? Object.new : Scene_Map.new
    $game_temp = Game_Temp.new
    $game_temp.in_menu = moment[:in_menu] ? true : false
    PokeAccess.message_leave while PokeAccess.message_depth > 0
    PokeAccess.message_enter if moment[:message]
    moment[:battle] ? PokeAccess::Battle.battle_started : PokeAccess::Battle.battle_ended
    yield
  ensure
    PokeAccess.message_leave while PokeAccess.message_depth > 0
    had[2].times { PokeAccess.message_enter }
    had[3] ? PokeAccess::Battle.battle_started : PokeAccess::Battle.battle_ended
    $scene, $game_temp = had[0], had[1]
  end

  # The block's value with mod's method meth raising, the real one put back after.
  def failing(mod, meth)
    real = mod.method(meth)
    mod.define_singleton_method(meth) { |*_args| raise "a probe fails" }
    yield
  ensure
    mod.define_singleton_method(meth, real)
  end

  # Runs the block as at a session's start, with nothing said yet; the session's count of lines is put back after.
  def in_fresh_session
    was = PokeAccess.instance_variable_get(:@spoken_seq)
    PokeAccess.instance_variable_set(:@spoken_seq, nil)
    yield
  ensure
    PokeAccess.instance_variable_set(:@spoken_seq, was)
  end

  # Runs the block with the log_once entry under key forgotten before and after, so the block's own logging shows.
  def forgetting_log(key)
    PokeAccess.logged.delete(key)
    yield
  ensure
    PokeAccess.logged.delete(key)
  end

  # The block's value with the pause panel's memory of its last opening empty, put back as it was after.
  def with_fresh_pause_panel
    panel = PokeAccess::PausePanel
    was = panel.instance_variable_get(:@last)
    panel.instance_variable_set(:@last, [])
    yield
  ensure
    panel.instance_variable_set(:@last, was)
  end
end
