# The modern message path (v19+, core/dialogue/dialogue.rb): the bare top-level pbMessageDisplay is wrapped to say
# each shown line once, and no Kernel singleton the game never had is made up.
class SayDialogueGdTest < PokeAccessTest
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

  test "the bare pbMessageDisplay says the shown line, queued, and keeps it for the repeat key" do
    pbMessageDisplay(nil, "Bienvenido a Pueblo Añil")
    assert_equal [["Bienvenido a Pueblo Añil", false]], SpeakCapture.log
    assert_equal "Bienvenido a Pueblo Añil", PokeAccess.last_dialogue
  end

  test "hands back what the engine's own function returns" do
    assert_equal "Bienvenido a Pueblo Añil", pbMessageDisplay(nil, "Bienvenido a Pueblo Añil")
  end

  test "the engine showing the same line again within half a second is not said twice" do
    with_clock do |at|
      pbMessageDisplay(nil, "Bienvenido a Pueblo Añil")
      at.call(100.49)
      pbMessageDisplay(nil, "Bienvenido a Pueblo Añil")
    end
    assert_equal [["Bienvenido a Pueblo Añil", false]], SpeakCapture.log
  end

  test "a message counts one level deeper while the game's window shows it, and none after, even when it fails" do
    depths = []
    showing(lambda { depths.push(PokeAccess.message_depth) }) { pbMessageDisplay(nil, "Primero") }
    showing(lambda { raise ArgumentError, "the window failed" }) do
      assert_raises(ArgumentError) { pbMessageDisplay(nil, "Segundo") }
    end
    assert_equal [1], depths, "one level deep while the window shows it"
    assert_equal 0, PokeAccess.message_depth, "none after either"
  end

  test "with dialogue pages on, a message whose window pages is left to the page reader, said as the window closes" do
    PokeAccess::Config.dialogue_pages = true
    during = nil
    showing(lambda { during = SpeakCapture.log.dup }) { pbMessageDisplay(PagedWindow.new, "Hola.") }
    assert_equal [], during, "nothing while the window shows it"
    assert_equal [["Hola.", false]], SpeakCapture.log
  end

  test "counts each line through the bare function for the diag" do
    before = PokeAccess.dialogue_seen
    pbMessageDisplay(nil, "Una línea")
    assert_equal before + 1, PokeAccess.dialogue_seen
  end

  test "the bare function, the form the game defines, is the one wrapped, and stays private" do
    assert_equal [:bare], PokeAccess.dialogue_wraps
    assert_equal [:bare], PokeAccess::Keys.dialogue_forms
    assert_equal true, Object.private_method_defined?(:pbMessageDisplay), "the wrapper keeps the function private"
    assert_equal false, Kernel.respond_to?(:pbMessageDisplay), "so no Kernel singleton shows up"
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

  # Runs the block with the game's own message window, which the wrap calls, standing in as show; the stub's own is
  # put back after.
  def showing(show)
    Object.send(:alias_method, :pa_spec_inst, :pbMessageDisplay__pa_inst)
    Object.send(:define_method, :pbMessageDisplay__pa_inst) { |*_args| show.call }
    Object.send(:private, :pbMessageDisplay__pa_inst)
    yield
  ensure
    Object.send(:alias_method, :pbMessageDisplay__pa_inst, :pa_spec_inst)
    Object.send(:private, :pbMessageDisplay__pa_inst)
    Object.send(:remove_method, :pa_spec_inst)
  end
end
