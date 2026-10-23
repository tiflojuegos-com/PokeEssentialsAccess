# FL's Wall Clock (plugins/fl_wall_clock.rb, WallClockScene): an analog clock with no text; the time its hands show is
# said once as it opens and kept on the info key at each update of the hands.
class FlWallClockTest < PokeAccessTest
  test "the time is said once, queued, and the info key follows the later updates" do
    scene = World.stub_scene({})
    PokeAccess::WallClock.updated(scene, Time.local(2026, 10, 4, 9, 5))
    PokeAccess::WallClock.updated(scene, Time.local(2026, 10, 4, 9, 6))
    assert_equal [["09:05", false]], SpeakCapture.log
    assert_equal "09:06", PokeAccess::Info.info_text
  end

  test "an update without a time says nothing" do
    PokeAccess::WallClock.updated(World.stub_scene({}), nil)
    assert_nothing_spoken
  end
end
