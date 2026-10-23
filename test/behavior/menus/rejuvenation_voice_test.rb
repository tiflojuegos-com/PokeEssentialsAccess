# Rejuvenation's own reader through rv_common's relay (games/rejuvenation/own_voice.rb): muted once the mod's voice is
# up, with the mod saying its lines, as the game wrote them, on the screens the mod has no reader for.
Harness.load_common("rv_common")

# The game's reader as TextToSpeech.rb defines it, which the relay follows.
def tts(text, _interrupt = false); text; end

# The controls list, said through tts as it is drawn.
class DefaultControlsScene
  def pbRender; tts("Controls Screen: Use Ctrl + Up or Down keys to navigate between lines."); end
end

# The Rift Dex entry, said through tts as it is shown.
class Scene_RiftDex_Info
  def main
    tts("Rift Dex Screen: Use Up or Down keys to switch entries.")
    tts("Rift 1 of 2: Gyarados.")
    :closed
  end
end

# The Rift Dex's battle page.
class Scene_BossDex_Battle
  def pbStartScene; tts("Battle data: Gyarados."); end
end

# The text log, which says the line under its cursor as it opens.
class TextLogScene
  attr_reader :held

  def initialize(held)
    @held = held
    tts("Rival: Hello there.")
  end
end

# The Advanced Dex.
class AdvancedPokedex
  def pbStartScreen; tts("Advanced Dex: Gyarados."); end
end

# The battle's default Poke Ball button: taking it up and changing the ball, each said through tts.
class DefaultBallDisplay
  def pbToggle
    tts("Default Poké Ball selected.")
    tts("Great Ball, In Bag: 5")
  end
  def pbChange(_num); tts("Ultra Ball, In Bag: 2"); end
end

# The field notes list, whose sort keys say the order they set through tts.
class Scene_FieldNotes
  def sortMenu(_sorttype); tts("Sorted by type"); end
end

class RejuvenationVoiceTest < PokeAccessTest
  V = PokeAccess::OwnVoiceRV
  # The relay's state, kept from the profile's install and put back around each test.
  STATE = [:@live, :@last_frame, :@always, :@always_frame, :@active]
  # The private-use character that starts shaking text in the game's messages.
  SHAKE = [0xE003].pack("U")
  # The game's TextPlaceholders, which strips the private-use characters its messages carry.
  STRIPPING = Module.new { def self.removeFrom(text); text.gsub(RejuvenationVoiceTest::SHAKE, ""); end }
  # A TextPlaceholders with no removeFrom, and one whose removeFrom fails.
  BARE = Module.new
  FAILING = Module.new { def self.removeFrom(_text); raise ArgumentError, "bad text"; end }

  class << self
    # The game's reader as the profile left it, evaluated with the mod's voice up.
    attr_reader :reader_after
    # The relay's state as the profile left it, [ivar, value] for each of STATE.
    attr_reader :installed
  end

  # Evaluates the profile once, as boot does, with the mod's voice up and a reader of the game's in $tts (a second
  # evaluation would hook the screens again); the relay's state, the reader and the voice are put back at once.
  def self.load_profile
    saved = STATE.map { |iv| [iv, V.instance_variable_get(iv)] }
    had_tts = $tts
    init = PokeAccess.method(:init_speech!)
    PokeAccess.define_singleton_method(:init_speech!) { true }
    $tts = Object.new
    path = File.join(Harness::ROOT, "games", "rejuvenation", "own_voice.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    @reader_after = $tts
    @installed = STATE.map { |iv| [iv, V.instance_variable_get(iv).dup] }
  ensure
    PokeAccess.define_singleton_method(:init_speech!, init)
    $tts = had_tts
    saved.each { |iv, value| V.instance_variable_set(iv, value) }
  end
  load_profile

  test "evaluated with the mod's voice up, the profile mutes the game's reader" do
    assert_nil self.class.reader_after
  end

  test "says what each of its screens hands the game's reader" do
    { lambda { DefaultControlsScene.new.pbRender } => ["Controls Screen: Use Ctrl + Up or Down keys to navigate between lines."],
      lambda { Scene_RiftDex_Info.new.main } => ["Rift Dex Screen: Use Up or Down keys to switch entries.", "Rift 1 of 2: Gyarados."],
      lambda { Scene_BossDex_Battle.new.pbStartScene } => ["Battle data: Gyarados."],
      lambda { TextLogScene.new(true) } => ["Rival: Hello there."],
      lambda { AdvancedPokedex.new.pbStartScreen } => ["Advanced Dex: Gyarados."],
      lambda { DefaultBallDisplay.new.pbToggle } => ["Default Poké Ball selected.", "Great Ball, In Bag: 5"],
      lambda { DefaultBallDisplay.new.pbChange(1) } => ["Ultra Ball, In Bag: 2"],
      lambda { Scene_FieldNotes.new.sortMenu(:type) } => ["Sorted by type"] }.each do |screen, lines|
      SpeakCapture.clear
      with_relay { screen.call }
      assert_equal lines, SpeakCapture.lines
    end
  end

  test "the lines a screen says in one frame queue behind each other" do
    with_relay { Scene_RiftDex_Info.new.main }
    assert_equal [["Rift Dex Screen: Use Up or Down keys to switch entries.", false], ["Rift 1 of 2: Gyarados.", false]],
                 SpeakCapture.log
  end

  test "each change of the default ball cuts in, so a held arrow never queues the balls it passes" do
    with_relay { 2.times { DefaultBallDisplay.new.pbChange(1) } }
    assert_equal [["Ultra Ball, In Bag: 2", true], ["Ultra Ball, In Bag: 2", true]], SpeakCapture.log
  end

  test "the ball display's toggle queues its lines behind what was said" do
    with_relay { DefaultBallDisplay.new.pbToggle }
    assert_equal [false, false], SpeakCapture.log.map { |_t, cut| cut }
  end

  test "a relayed screen runs as it would, its result and its arguments kept" do
    with_relay do
      assert_equal :closed, Scene_RiftDex_Info.new.main
      assert_equal :line_three, TextLogScene.new(:line_three).held
    end
  end

  test "a screen opened on a later frame starts its lines queued" do
    with_relay do
      at_frame(1) { Scene_RiftDex_Info.new.main }
      SpeakCapture.clear
      at_frame(2) { Scene_BossDex_Battle.new.pbStartScene }
    end
    assert_equal [["Battle data: Gyarados.", false]], SpeakCapture.log
  end

  test "a line the game says off the relayed screens is left to the mod's readers" do
    with_relay { tts("Save File: 1") }
    assert_nothing_spoken
  end

  test "once a relayed screen has closed, the game's lines are the mod's readers' again" do
    with_relay do
      Scene_RiftDex_Info.new.main
      SpeakCapture.clear
      tts("Save File: 1")
    end
    assert_nothing_spoken
  end

  test "the lowercase keyword is not taken for the interrupt flag, which cuts in" do
    { { :lowercase => false } => false, true => true }.each do |arg, cut|
      SpeakCapture.clear
      with_relay { V.relayed { tts("Sorted by name", arg) } }
      assert_equal [["Sorted by name", cut]], SpeakCapture.log, "with #{arg.inspect}"
    end
  end

  test "the game's placeholders are stripped as its own reader strips them, a line kept whole where it cannot" do
    { STRIPPING => "Shaking ground", BARE => "Shaking#{SHAKE} ground", FAILING => "Shaking#{SHAKE} ground" }.each do |mod, line|
      SpeakCapture.clear
      with_placeholders(mod) { with_relay { V.relayed { tts("Shaking#{SHAKE} ground") } } }
      assert_equal [line], SpeakCapture.lines
    end
  end

  test "a message shown over a relayed screen is left to the dialogue reader" do
    with_relay do
      V.relayed do
        PokeAccess.message_enter
        begin
          tts("A message shown over the log")
        ensure
          PokeAccess.message_leave
        end
      end
    end
    assert_nothing_spoken
  end

  test "a message a relayed screen read aloud before showing it is not read again" do
    with_relay do
      V.relayed { Kernel.pbMessage("The note in full.", { :tts => false }) }
      PokeAccess.say_dialogue("The note in full.")
    end
    assert_nothing_spoken
  end

  test "off the relayed screens, a message the muted reader was handed is read" do
    with_relay do
      Kernel.pbMessage("Una nota fuera de las pantallas.", { :tts => false })
      PokeAccess.say_dialogue("Una nota fuera de las pantallas.")
    end
    assert_equal [["Una nota fuera de las pantallas.", false]], SpeakCapture.log
  end

  test "the nest page stays the mod's to read, the region map being the game's nest" do
    with_relay { PokeAccess::DexEntry.gen6_area(Object.new, ["Route 2"]) }
    assert_equal [["Route 2", true]], SpeakCapture.log
  end

  test "with no profile's relay, a screen runs untouched and the game's lines are not said" do
    keeping_relay_state do
      V.instance_variable_set(:@active, false)
      inside = V.relayed { V.relaying? }
      V.relay("Rift 1 of 2: Gyarados.")
      assert_equal false, inside, "nothing is taken for a relayed screen"
    end
    assert_nothing_spoken
  end

  private

  # Runs the block with Rejuvenation's relay as its profile installed it, its state put back after.
  def with_relay
    keeping_relay_state do
      self.class.installed.each { |iv, value| V.instance_variable_set(iv, value.dup) }
      yield
    end
  end

  # The block's value, the relay's state put back after it.
  def keeping_relay_state
    saved = STATE.map { |iv| [iv, V.instance_variable_get(iv)] }
    yield
  ensure
    saved.each { |iv, value| V.instance_variable_set(iv, value) }
  end

  # Runs the block on frame n of the game's clock, the clock put back after.
  def at_frame(n)
    had = Graphics.respond_to?(:frame_count) ? Graphics.method(:frame_count) : nil
    Graphics.define_singleton_method(:frame_count) { n }
    yield
  ensure
    had ? Graphics.define_singleton_method(:frame_count, had) : Graphics.singleton_class.send(:remove_method, :frame_count)
  end

  # Runs the block with the game's TextPlaceholders being mod, putting back whatever was there.
  def with_placeholders(mod)
    had = Object.const_defined?(:TextPlaceholders) ? Object.send(:remove_const, :TextPlaceholders) : nil
    Object.const_set(:TextPlaceholders, mod)
    yield
  ensure
    Object.send(:remove_const, :TextPlaceholders) if Object.const_defined?(:TextPlaceholders)
    Object.const_set(:TextPlaceholders, had) if had
  end
end
