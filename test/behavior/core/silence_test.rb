# The silence watch (Silence): a screen that says nothing for two seconds after it comes up is listed for the
# diagnostic with its map, once each and twenty at most; one that speaks in time is not.
class SilenceTest < PokeAccessTest
  Silence = PokeAccess::Silence
  WINDOW = PokeAccess::Silence::WINDOW

  test "lists a screen that says nothing for its whole window, with its map" do
    watching("QuietScene") do
      $game_map.map_id = 7
      ticks(WINDOW + 1)
      assert_equal ["QuietScene@7"], Silence.quiet
    end
  end

  test "gives a new screen the frame it comes up on and two seconds at 60 frames a second more" do
    watching("SlowScene") do
      ticks(120)
      assert_equal [], Silence.quiet, "one frame short of the window"
      Silence.tick
      assert_equal ["SlowScene@1"], Silence.quiet, "on the window's last frame"
    end
  end

  test "does not list a screen that speaks inside its window" do
    watching("TalkingScene") do
      Silence.tick
      PokeAccess.speak("algo", true)
      ticks(WINDOW + 1)
      assert_equal [], Silence.quiet
    end
  end

  test "does not list a screen that speaks on the last frame of its window" do
    watching("LateScene") do
      ticks(WINDOW)
      PokeAccess.speak("por fin", true)
      ticks(WINDOW + 1)
      assert_equal [], Silence.quiet
    end
  end

  test "takes a blank line for silence" do
    watching("BlankScene") do
      Silence.tick
      PokeAccess.speak("   ", true)
      ticks(WINDOW)
      assert_equal ["BlankScene@1"], Silence.quiet
    end
  end

  test "starts the window afresh when another screen comes up" do
    watching("FirstScene") do
      ticks(WINDOW)
      PokeAccess::Hooks.note_screen("SecondScene")
      ticks(WINDOW)
      assert_equal [], Silence.quiet, "neither had a whole window"
      Silence.tick
      assert_equal ["SecondScene@1"], Silence.quiet, "the second's window, counted from its own start"
    end
  end

  test "lists a screen once, however often it comes back silent" do
    watching("SameScene") do
      ticks(WINDOW + 1)
      PokeAccess::Hooks.note_screen("OtherScene")
      Silence.tick
      PokeAccess.speak("otra", true)
      PokeAccess::Hooks.note_screen("SameScene")
      ticks(WINDOW + 1)
      assert_equal ["SameScene@1"], Silence.quiet
    end
  end

  test "keeps the first twenty screens listed and drops the rest" do
    watching("Scene1") do
      (1..25).each do |n|
        PokeAccess::Hooks.note_screen("Scene#{n}")
        ticks(WINDOW + 1)
      end
      assert_equal (1..20).map { |n| "Scene#{n}@1" }, Silence.quiet
    end
  end

  test "watches $scene's class while no hooked method has named the screen" do
    [nil, ""].each do |hooked|
      watching(hooked) do
        with_scene(Scene_Map.new) do
          ticks(WINDOW + 1)
          assert_equal ["Scene_Map@1"], Silence.quiet, "with the hooked screen #{hooked.inspect}"
        end
      end
    end
  end

  test "names the map as unknown where there is none" do
    watching("MaplessScene") do
      with_map(nil) do
        ticks(WINDOW + 1)
        assert_equal ["MaplessScene@?"], Silence.quiet
      end
    end
  end

  test "reset forgets the screens listed, so a silent one is listed again" do
    watching("AgainScene") do
      ticks(WINDOW + 1)
      Silence.reset
      assert_equal [], Silence.quiet, "forgotten"
      ticks(WINDOW + 1)
      assert_equal ["AgainScene@1"], Silence.quiet, "watched afresh"
    end
  end

  test "the diagnostic lists the silent screens, or says there are none" do
    watching("DiagScene") do
      assert_equal "silent: none", diag_line
      ticks(WINDOW + 1)
      PokeAccess::Hooks.note_screen("NextScene")
      ticks(WINDOW + 1)
      assert_equal "silent: DiagScene@1, NextScene@1", diag_line
    end
  end

  test "each Input.update is one frame of the watch, no more" do
    watching("PulsedScene") do
      only_silence_pollers do
        WINDOW.times { Input.update }
        assert_equal [], Silence.quiet, "#{WINDOW} pulses: one short of the window"
        Input.update
        assert_equal ["PulsedScene@1"], Silence.quiet, "the window's last pulse"
      end
    end
  end

  private

  # Runs the block with the watch fresh and screen as the hooked screen, both put back after.
  def watching(screen)
    was = PokeAccess::Hooks.screen
    Silence.reset
    PokeAccess::Hooks.note_screen(screen)
    yield
  ensure
    PokeAccess::Hooks.note_screen(was)
    Silence.reset
  end

  # Runs n frames of the watch.
  def ticks(n)
    n.times { Silence.tick }
  end

  # Runs the block with the frame's pulse running only the pollers silence.rb registers, so no other reader's
  # leftover speech reaches the watch; the full list is put back after.
  def only_silence_pollers
    pollers = PokeAccess::Frame.instance_variable_get(:@pollers)
    saved = pollers.dup
    pollers.select! { |b| b.source_location && b.source_location[0].tr("\\", "/").end_with?("core/util/silence.rb") }
    yield
  ensure
    pollers.replace(saved)
  end

  # Runs the block with $scene set to scene, put back after.
  def with_scene(scene)
    was = $scene
    $scene = scene
    yield
  ensure
    $scene = was
  end

  # Runs the block with $game_map set to map, put back after.
  def with_map(map)
    was = $game_map
    $game_map = map
    yield
  ensure
    $game_map = was
  end

  # The silence section's line of the diagnostic.
  def diag_line
    PokeAccess::Keys.diag_build([:diag_silence]).split("\n")[1]
  end
end
