# Reborn's own reader through rv_common's relay (OwnVoiceRV, set up by games/reborn/own_voice.rb): muted once the mod
# speaks, and what it hands tts on the screens the mod has no reader for, or anywhere for its own lines, said by the mod.
Harness.load_common("rv_common")

# The game's reader as Messages.rb defines it, which the relay follows.
def tts(text, _interrupt = false); text; end

# The intro's character pick, said through tts as the choice moves ($game_variables[358] holds it).
def rebornIntroTTS(start = false)
  tts("Select your player character:") if start
  tts(["Vero", "Alice", "Kuro", "Lucia", "Ari", "Decibel"][$game_variables[358] - 1])
end

# The PULSE Dex entry, said through tts as it is shown.
class Scene_PulseDex_Info
  def main
    tts("PULSE Dex")
    tts("PULSE 01: Magnezone.")
    :closed
  end
end

# The PULSE Dex's battle page.
class Scene_PulseDex_Battle
  def pbStartScene; tts("Battle data: Magnezone."); end
end

# The keyboard and gamepad control lists.
class DefaultKeyboardControlsScene
  def pbRender; tts("Confirm: C"); end
end

class DefaultGamepadControlsScene
  def pbRender; tts("Confirm: A button"); end
end

# The online trade: the Pokemon under the selector, then the offer.
class Scene_Trade
  def main
    tts("Pikachu")
    tts("Pokémon Offered:")
    tts("Level 12 Eevee")
    :traded
  end
end

class RebornVoiceTest < PokeAccessTest
  V = PokeAccess::OwnVoiceRV
  PROFILE = File.join(Harness::ROOT, "games", "reborn", "own_voice.rb")
  STATE = [:@live, :@last_frame, :@always, :@always_frame, :@active]
  PLAIN_NEST = PokeAccess::DexEntry.method(:gen6_area)
  RELAY = {}

  test "leaves the game's reader on while the mod has no voice of its own" do
    with_voice(false) do
      reader = $tts
      V.mute
      assert_same reader, $tts
    end
  end

  test "mutes the game's reader once the mod's voice is up" do
    with_voice(true) do
      V.mute
      assert_nil $tts
    end
  end

  test "setting the relay up mutes the game's reader" do
    with_voice(true) do
      keeping_relay_state { V.install([], []) }
      assert_nil $tts
    end
  end

  test "setting the relay up turns it on" do
    with_voice(true) do
      keeping_relay_state do
        V.install([], [])
        V.relayed { tts("PULSE 06: Snorlax.") }
      end
    end
    assert_equal [["PULSE 06: Snorlax.", false]], SpeakCapture.log
  end

  test "a screen whose method the game lacks is left unhooked without being reported missing" do
    with_voice(true) do
      keeping_relay_state { V.install([["Scene_Trade", :pbOfferList]], []) }
    end
    refute_includes PokeAccess::Hooks.missing, "Scene_Trade#pbOfferList"
  end

  test "Reborn has no relay of its own beside the engine's to talk over it" do
    assert_nil defined?(PokeAccess::RebornVoice)
  end

  test "leaves a line the game says off its relayed screens to the mod's own readers" do
    with_relay { tts("Save File: 1") }
    assert_nothing_spoken
  end

  test "says what a relayed screen hands the game's reader, as written and queued within a frame" do
    with_relay { Scene_PulseDex_Info.new.main }
    assert_equal [["PULSE Dex", false], ["PULSE 01: Magnezone.", false]], SpeakCapture.log
  end

  test "a relayed screen keeps its own result" do
    with_relay do
      assert_equal :closed, Scene_PulseDex_Info.new.main
      assert_equal :traded, Scene_Trade.new.main
    end
  end

  test "says the lines of every screen the profile relays" do
    { lambda { Scene_PulseDex_Battle.new.pbStartScene } => ["Battle data: Magnezone."],
      lambda { DefaultKeyboardControlsScene.new.pbRender } => ["Confirm: C"],
      lambda { DefaultGamepadControlsScene.new.pbRender } => ["Confirm: A button"],
      lambda { Scene_Trade.new.main } => ["Pikachu", "Pokémon Offered:", "Level 12 Eevee"] }.each do |screen, lines|
      with_relay { screen.call }
      assert_equal lines, SpeakCapture.lines
      SpeakCapture.clear
    end
  end

  test "the first line of a later frame cuts in, as a cursor move does" do
    with_relay do
      V.relayed do
        at_frame(1) { tts("PULSE 01: Magnezone.") }
        at_frame(2) { tts("PULSE 02: Avalugg.") }
      end
    end
    assert_equal [["PULSE 01: Magnezone.", false], ["PULSE 02: Avalugg.", true]], SpeakCapture.log
  end

  test "a screen relayed after another starts queued, whatever frame it comes up on" do
    with_relay do
      at_frame(1) { V.relayed { tts("PULSE 01: Magnezone.") } }
      at_frame(5) { V.relayed { tts("Battle data: Magnezone.") } }
    end
    assert_equal [["PULSE 01: Magnezone.", false], ["Battle data: Magnezone.", false]], SpeakCapture.log
  end

  test "a line the game says with its interrupt flag cuts in from the first" do
    { true => true, false => false, nil => false, { :lowercase => true } => false }.each do |flag, cut|
      with_relay { V.relayed { tts("PULSE 03: Lapras.", flag) } }
      assert_equal [["PULSE 03: Lapras.", cut]], SpeakCapture.log, "with #{flag.inspect}"
      SpeakCapture.clear
    end
  end

  test "a blank line on a relayed screen says nothing" do
    with_relay { V.relayed { tts("   ") } }
    assert_nothing_spoken
  end

  test "a message shown over a relayed screen is left to the dialogue reader" do
    with_relay do
      V.relayed do
        PokeAccess.message_enter
        begin
          tts("A message shown over the dex")
        ensure
          PokeAccess.message_leave
        end
      end
    end
    assert_nothing_spoken
  end

  test "once a relayed screen has closed, its lines are the mod's readers' again" do
    with_relay do
      Scene_PulseDex_Info.new.main
      SpeakCapture.clear
      tts("PULSE 04: Gyarados.")
    end
    assert_nothing_spoken
  end

  test "says on any screen the lines only the game's reader gives, each cutting in" do
    ["X 12, Y 7, map 29, Opal Ward",
     "2 yellow crystals lit up, and 1 white crystals lit up. The slots are filled left to right with ruby, blank.",
     "Seat: 8R750"].each do |line|
      with_relay { tts(line) }
      assert_equal [[line, true]], SpeakCapture.log, "for #{line.inspect}"
      SpeakCapture.clear
    end
  end

  test "of the lines said on any screen, the first of a frame cuts in and the rest of that frame queue behind it" do
    with_relay do
      at_frame(7) do
        tts("X 1, Y 2, map 3, Opal Ward")
        tts("Seat: 8R750")
      end
      at_frame(8) { tts("X 1, Y 3, map 3, Opal Ward") }
    end
    assert_equal [["X 1, Y 2, map 3, Opal Ward", true], ["Seat: 8R750", false], ["X 1, Y 3, map 3, Opal Ward", true]],
                 SpeakCapture.log
  end

  test "a message the game shows after saying it on a relayed screen is not read again" do
    with_relay do
      V.relayed { Kernel.pbMessage("The entry in full.", { :tts => false }) }
      PokeAccess.say_dialogue("The entry in full.")
    end
    assert_nothing_spoken
  end

  test "a message the game has not said itself is read" do
    { ["Un mensaje sin opciones."] => true, ["Un mensaje que el juego no dice.", { :tts => true }] => true,
      ["Un mensaje fuera de la pantalla.", { :tts => false }] => false }.each do |args, relayed|
      with_relay do
        relayed ? V.relayed { V.said_already(args) } : V.said_already(args)
        PokeAccess.say_dialogue(args[0])
      end
      assert_equal [[args[0], false]], SpeakCapture.log, "for #{args.inspect}"
      SpeakCapture.clear
    end
  end

  test "with no profile's relay, a relayed block runs as it is and leaves messages to the dialogue reader" do
    keeping_relay_state do
      V.instance_variable_set(:@active, false)
      assert_equal :shown, V.relayed { V.said_already(["Sin relevo, se lee.", { :tts => false }]); :shown }
      PokeAccess.say_dialogue("Sin relevo, se lee.")
    end
    assert_equal [["Sin relevo, se lee.", false]], SpeakCapture.log
  end

  test "follows the game's reader once, however often it is set up" do
    with_relay do
      V.follow_tts
      V.relayed { tts("PULSE 05: Eevee.") }
    end
    assert_equal [["PULSE 05: Eevee.", false]], SpeakCapture.log
  end

  test "leaves the nest page's places to the game's own reader" do
    with_relay { PokeAccess::DexEntry.gen6_area(Object.new, ["Ruta 1"]) }
    assert_nothing_spoken
  end

  test "says the intro's character pick as it moves" do
    $game_variables[358] = 2
    with_relay { rebornIntroTTS(true) }
    assert_equal [["Select your player character:", false], ["Alice", false]], SpeakCapture.log
  end

  private

  # Runs the block with Reborn's relay on as its profile installs it (its screens hooked, its always-said lines, the
  # nest page left to the game); the relay's state and the nest page's reader are put back after.
  def with_relay
    always, nest = reborn_relay
    keeping_relay_state do
      V.instance_variable_set(:@active, true)
      V.instance_variable_set(:@always, always)
      V.instance_variable_set(:@live, [])
      V.instance_variable_set(:@always_frame, nil)
      PokeAccess::DexEntry.define_singleton_method(:gen6_area, nest)
      yield
    end
  ensure
    PokeAccess::DexEntry.define_singleton_method(:gen6_area, PLAIN_NEST)
  end

  # Reborn's profile evaluated once per process, as boot does (a second evaluation would hook its screens again), and
  # what it leaves taken back at once: [its always-said patterns, the nest page's reader as it leaves it].
  def reborn_relay
    RELAY[:installed] ||= begin
      had_tts = $tts
      overrides = PokeAccess::Hooks.overrides.length
      profiles = PokeAccess::Game.profiles.dup
      keeping_relay_state do
        eval(Harness.source(PROFILE), TOPLEVEL_BINDING, PROFILE)
        [V.instance_variable_get(:@always), PokeAccess::DexEntry.method(:gen6_area)]
      end
    ensure
      PokeAccess::DexEntry.define_singleton_method(:gen6_area, PLAIN_NEST)
      PokeAccess::Hooks.overrides.slice!(overrides..-1)
      PokeAccess::Game.profiles.replace(profiles)
      $tts = had_tts
    end
  end

  # The block's value, the relay's state put back after it.
  def keeping_relay_state
    saved = STATE.map { |iv| [iv, V.instance_variable_get(iv)] }
    yield
  ensure
    saved.each { |iv, value| V.instance_variable_set(iv, value) }
  end

  # Runs the block with the mod's voice up or not, as init_speech! answers, and a reader of the game's in $tts; both
  # put back after.
  def with_voice(up)
    had_tts = $tts
    init = PokeAccess.method(:init_speech!)
    PokeAccess.define_singleton_method(:init_speech!) { up }
    $tts = lambda { |_text, _interrupt| nil }
    yield
  ensure
    PokeAccess.define_singleton_method(:init_speech!, init)
    $tts = had_tts
  end

  # Runs the block on frame n of the game's clock, the clock put back after.
  def at_frame(n)
    had = Graphics.respond_to?(:frame_count) ? Graphics.method(:frame_count) : nil
    Graphics.define_singleton_method(:frame_count) { n }
    yield
  ensure
    had ? Graphics.define_singleton_method(:frame_count, had) : Graphics.singleton_class.send(:remove_method, :frame_count)
  end
end
