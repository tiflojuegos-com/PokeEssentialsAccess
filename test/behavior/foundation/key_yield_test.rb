# The frame's key poll (Keys.global_poll) driven through the keyboard: the action each mod key and gesture runs, the
# history category of its answer, and when a key does nothing (claimed, a text field, a menu, the window behind).
class KeyYieldTest < PokeAccessTest
  SHIFT = 0x10
  CTRL = 0x11
  ALT = 0x12
  F8 = 0x77
  INFO = 0x54
  HP = 0x48
  FIELD = 0x47
  COORDS = 0x4D
  CONFIG = 0x4F
  HOME = 0x24
  END_KEY = 0x23
  PLACE = "Datos del lugar"
  ROW = "Poción, 3 en la bolsa"
  # The actions a key can run, recorded instead of run (the info key's speech is asserted as spoken).
  ACTIONS = { PokeAccess::Battle => [:announce_hp, :announce_field],
              PokeAccess::Locator => [:mark_here, :toggle_hide_unreachable, :rename_map, :announce_coords],
              PokeAccess::History => [:step, :to_end, :switch_category],
              PokeAccess::Verbosity => [:rotate_scheme], PokeAccess::ConfigMenu => [:open] }.freeze

  test "leaves a key a screen claims to it until four polls pass without the claim" do
    with_keyboard do
      refute keys.yielded?(:info), "unclaimed, the key is the mod's"
      keys.yield_key!(:info)
      3.times { frame }
      assert keys.yielded?(:info), "three polls on, the claim holds"
      frame
      refute keys.yielded?(:info), "the fourth lets it go"
    end
  end

  test "never lets go of a claim the screen renews every frame" do
    with_keyboard do
      10.times do
        keys.yield_key!(:info)
        frame
      end
      assert keys.yielded?(:info)
    end
  end

  test "says nothing for a press of a claimed key, and reads the info for the same press once the claim lapses" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      keys.yield_key!(:info)
      frame(INFO)
      assert_nothing_spoken "the press lands on the game's screen"
      3.times { frame }
      frame(INFO)
      assert_equal [[PLACE, true]], SpeakCapture.log
    end
  end

  test "keeps the other keys working while a screen claims one" do
    with_keyboard do
      keys.yield_key!(:info)
      refute keys.yielded?(:hp), "the claim covers its own key only"
      assert_equal [[:announce_hp, false]], actions { press(HP) }
    end
  end

  test "runs the action of each mod key and its gestures" do
    { [HP] => [[:announce_hp, false]], [SHIFT, HP] => [[:announce_hp, true]],
      [FIELD] => [[:announce_field]], [CTRL, FIELD] => [[:mark_here]],
      [COORDS] => [[:announce_coords]], [CTRL, COORDS] => [[:toggle_hide_unreachable]],
      [SHIFT, COORDS] => [[:rename_map]],
      [HOME] => [[:step, -1]], [END_KEY] => [[:step, 1]], [CTRL, HOME] => [[:to_end, -1]],
      [SHIFT, END_KEY] => [[:switch_category, 1]], [CONFIG] => [[:open]] }.each do |gesture, want|
      with_keyboard { assert_equal want, actions { press(*gesture) }, "for #{gesture.inspect}" }
    end
  end

  test "says the last dialogue for Shift with the info key, or that there was none" do
    { "Bienvenido a Ciudad Luz." => "Bienvenido a Ciudad Luz.", "" => PokeAccess::I18n.t(:no_recent_dialogue),
      nil => PokeAccess::I18n.t(:no_recent_dialogue) }.each do |line, want|
      SpeakCapture.clear
      with_last_dialogue(line) do
        with_keyboard do
          press(SHIFT, INFO)
          assert_equal [[want, true]], SpeakCapture.log, "after #{line.inspect}"
        end
      end
    end
  end

  test "says the focused row whole for Ctrl with the info key, and what the screen published otherwise" do
    { [[CTRL, INFO], ROW] => ROW, [[INFO], ROW] => PLACE, [[CTRL, INFO], nil] => PLACE }.each do |(gesture, row), want|
      SpeakCapture.clear
      with_keyboard do
        PokeAccess::Info.set_info(:text, PLACE, row)
        press(*gesture)
        assert_equal [[want, true]], SpeakCapture.log, "for #{gesture.inspect} with the row #{row.inspect}"
      end
    end
  end

  test "files each key's answer under its category in the history" do
    { [INFO] => :info, [SHIFT, INFO] => :info, [FIELD] => :info, [COORDS] => :nav }.each do |gesture, want|
      PokeAccess::History.clear
      with_keyboard do
        PokeAccess::Info.set_info(:text, PLACE)
        press(*gesture)
      end
      filed = PokeAccess::History.lines_of(PokeAccess::History::ALL).map { |m| m.category }
      assert_equal [want], filed, "for #{gesture.inspect}"
    end
  end

  test "answers the info key with Shift and Ctrl unbound, taking them for never held" do
    PokeAccess::Config.keys[:shift] = nil
    PokeAccess::Config.keys[:ctrl] = nil
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      press(INFO)
      assert_equal [[PLACE, true]], SpeakCapture.log
    end
  end

  test "notes each key it answers for the session recorder, and nothing on a frame without one" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      notes = []
      stubbing_with(PokeAccess::Recorder, :note_key => lambda { |name| notes.push(name) }) do
        actions { press(INFO); press(HP) }
      end
      assert_equal [:info, :hp], notes
    end
  end

  test "steps the verbosity scheme with its key once the player binds one" do
    PokeAccess::Config.keys[:verbosity] = 0x56
    with_keyboard { assert_equal [[:rotate_scheme]], actions { press(0x56) } }
  end

  test "leaves the coordinates key alone while a screen holds control, and the other keys answer" do
    with_keyboard do
      gestures = [[COORDS], [CTRL, COORDS], [SHIFT, COORDS], [HP]]
      calls = actions { PokeAccess::Control.hold(:battle) { gestures.each { |g| press(*g) } } }
      assert_equal [[:announce_hp, false]], calls
    end
  end

  test "under a message, which leaves the locator keys free, the coordinates key and its gestures answer" do
    with_keyboard do
      gestures = [[COORDS], [CTRL, COORDS], [SHIFT, COORDS]]
      calls = nil
      begin
        $game_temp.message_window_showing = true
        calls = actions { gestures.each { |g| press(*g) } }
      ensure
        $game_temp.message_window_showing = nil
      end
      assert_equal [[:announce_coords], [:toggle_hide_unreachable], [:rename_map]], calls
    end
  end

  test "in a battle, Ctrl with the field key opens no marker and says markers go on the map" do
    with_keyboard do
      battle = PokeAccess::Battle
      battle.battle_started
      begin
        calls = actions { press(CTRL, FIELD) }
      ensure
        battle.instance_variable_set(:@in_battle, false)
      end
      assert_equal [[], [[PokeAccess::I18n.t(:mark_map_only), true]]], [calls, SpeakCapture.log]
    end
  end

  test "under a game menu that locks the locator keys, Ctrl with the field key opens no marker either" do
    with_keyboard do
      calls = actions { PokeAccess::Control.hold(:menu, :keys) { press(CTRL, FIELD) } }
      assert_equal [[], [[PokeAccess::I18n.t(:mark_map_only), true]]], [calls, SpeakCapture.log]
    end
  end

  test "keeps the config key from opening the mod's menu for four polls after a game menu locks it" do
    { 3 => [], 4 => [[:open]] }.each do |polls, want|
      with_keyboard do
        keys.menu_lock!
        assert_equal want, actions { polls.times { frame }; frame(CONFIG) }, "after #{polls} polls"
      end
    end
  end

  test "reads the info while a game menu locks the config key" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      keys.menu_lock!
      press(INFO)
      assert_equal [[PLACE, true]], SpeakCapture.log
    end
  end

  test "leaves every key to a text field for four polls" do
    { 3 => [], 4 => [[PLACE, true]] }.each do |polls, want|
      SpeakCapture.clear
      with_keyboard do
        PokeAccess::Info.set_info(:text, PLACE)
        keys.typing!
        polls.times { frame }
        frame(INFO)
        assert_equal want, SpeakCapture.log, "after #{polls} polls"
      end
    end
  end

  test "leaves every key to the mod's own menu while it is open" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      calls = stubbing(PokeAccess::ConfigMenu, :active? => true) { actions { press(INFO); press(HP) } }
      assert_equal [[], []], [calls, SpeakCapture.log]
    end
  end

  test "does nothing while the game window is in the background" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      calls = stubbing(PokeAccess::Focus, :focused? => false) { actions { press(INFO); press(HP) } }
      assert_equal [[], []], [calls, SpeakCapture.log]
    end
  end

  test "switches the mod off with Ctrl+Alt+F8, and its keys with it, and back on" do
    with_keyboard do
      PokeAccess::Info.set_info(:text, PLACE)
      press(CTRL, ALT, F8)
      off = keys.enabled
      press(INFO)
      press(CTRL, ALT, F8)
      press(INFO)
      assert_equal false, off, "switched off"
      assert_equal true, keys.enabled, "and back on"
      assert_equal [[PokeAccess::I18n.t(:mod_off), true], [PokeAccess::I18n.t(:mod_on), true], [PLACE, true]],
                   SpeakCapture.log
    end
  ensure
    keys.instance_variable_set(:@enabled, true)
  end

  test "retries starting speech when the mod is switched back on, and only then" do
    with_keyboard do
      tries = []
      mod_keys = keys
      stub = lambda { tries.push(mod_keys.enabled) }
      stubbing_with(PokeAccess, :retry_init! => stub) do
        press(CTRL, ALT, F8)
        press(CTRL, ALT, F8)
      end
      assert_equal [true], tries
    end
  ensure
    keys.instance_variable_set(:@enabled, true)
  end

  private

  def keys
    PokeAccess::Keys
  end

  # Runs the block with the raw keyboard answering from the keys a frame holds down (a code that is not a number is
  # no key, and asking for one fails), from a blank picture; the keyboard and its picture are put back afterwards.
  def with_keyboard
    kb = PokeAccess::Keyboard
    held = @held = {}
    real = kb.method(:raw_down?)
    picture = [:@now, :@prev, :@used].map { |v| kb.instance_variable_get(v) }
    [:@now, :@prev, :@used].each { |v| kb.instance_variable_set(v, {}) }
    kb.define_singleton_method(:raw_down?) do |vk|
      raise ArgumentError, "no key code: #{vk.inspect}" unless vk.is_a?(Integer)
      held[vk] ? true : false
    end
    yield
  ensure
    kb.define_singleton_method(:raw_down?, real)
    [:@now, :@prev, :@used].each_with_index { |v, i| kb.instance_variable_set(v, picture[i]) }
  end

  # One frame: the keys down in it, the keyboard's picture of them, then the mod's poll.
  def frame(*vks)
    @held.clear
    vks.each { |vk| @held[vk] = true }
    PokeAccess::Keyboard.snapshot
    keys.global_poll
  end

  # A press of the keys: a frame with none down, then one with them down.
  def press(*vks)
    frame
    frame(*vks)
  end

  # The actions the block's key presses ran, as [method, args...] in order, none of them run.
  def actions
    calls = []
    saved = []
    ACTIONS.each do |mod, meths|
      meths.each do |m|
        saved.push([mod, m, mod.method(m)])
        mod.define_singleton_method(m) { |*args| calls.push([m] + args); nil }
      end
    end
    yield
    calls
  ensure
    saved.each { |mod, m, real| mod.define_singleton_method(m, real) }
  end

  # Runs the block with each named singleton method of mod answering its value, put back afterwards.
  def stubbing(mod, answers, &blk)
    stubbing_with(mod, answers.map { |m, v| [m, lambda { |*_a| v }] }, &blk)
  end

  # Runs the block with each named singleton method of mod replaced by its lambda, put back afterwards.
  def stubbing_with(mod, bodies)
    saved = []
    bodies.each do |m, body|
      saved.push([m, mod.method(m)])
      mod.define_singleton_method(m, &body)
    end
    yield
  ensure
    saved.each { |m, real| mod.define_singleton_method(m, real) }
  end

  # Runs the block with the last dialogue the mod heard set to line (none for nil), put back afterwards.
  def with_last_dialogue(line)
    was = PokeAccess.last_dialogue
    PokeAccess.instance_variable_set(:@last_dialogue, line)
    yield
  ensure
    PokeAccess.instance_variable_set(:@last_dialogue, was)
  end
end
