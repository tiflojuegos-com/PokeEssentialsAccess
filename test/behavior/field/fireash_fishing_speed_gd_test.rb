# Fire Ash (games/fireash/fishing_speed.rb) drops the game speed to normal inside pbFishing and restores it after: the
# speed announcer says neither move, and a real press of the speed key afterwards is still said.

# The game's pbFishing cut down to its speed handling: it lowers the speed, runs a frame, restores it, runs a frame.
def pbFishing(_has_encounter, _rod = 1)
  saved = $GameSpeed
  $GameSpeed = 1
  PokeAccess::Turbo.tick
  $GameSpeed = saved
  PokeAccess::Turbo.tick
  true
end

path = File.join(Harness::ROOT, "games", "fireash", "fishing_speed.rb")
eval(Harness.source(path), TOPLEVEL_BINDING, path)

class FireashFishingSpeedGdTest < PokeAccessTest
  test "a cast of the rod says neither the drop to normal speed nor the restore" do
    on_map_at_speed(3) do
      pbFishing(true)
      PokeAccess::Turbo.tick
    end
    assert_nothing_spoken
  end

  test "a press of the speed key after the cast is still said" do
    on_map_at_speed(3) do
      pbFishing(true)
      $GameSpeed = 1
      PokeAccess::Turbo.tick
    end
    assert_equal [[PokeAccess::I18n.t(:turbo_speed, :n => 1), true]], SpeakCapture.log
  end

  test "the cast answers what the game's fishing answers" do
    assert_equal true, on_map_at_speed(3) { pbFishing(true) }
  end

  private

  # The block's value on the map at Fire Ash's speed index (its script keeps the multiplier itself), the announcer
  # synced to it first; the speed setting, the scene and the speed put back after, the announcer synced to them.
  def on_map_at_speed(speed)
    had = [$scene, $GameSpeed]
    Object.const_set(:SPEED_SETTING_FILE, "Save Files/GameSpeedSetting.dat")
    $scene = Scene_Map.new
    $GameSpeed = speed
    PokeAccess::Turbo.tick
    SpeakCapture.clear
    yield
  ensure
    Object.send(:remove_const, :SPEED_SETTING_FILE) if Object.const_defined?(:SPEED_SETTING_FILE)
    $scene, $GameSpeed = had
    PokeAccess::Turbo.quietly { }
  end
end
