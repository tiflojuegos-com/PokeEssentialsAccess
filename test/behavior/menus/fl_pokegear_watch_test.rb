# FL's Pokegear Watch (plugins/fl_pokegear_watch.rb): the clock it paints over the Pokegear menu, said once as the menu
# opens, queued behind the focused option, and kept on the info key as the minutes change; the seconds are left out.
class FlPokegearWatchTest < PokeAccessTest
  test "the clock is said once on opening, queued, without its seconds" do
    PokeAccess::PokegearWatch.opened(gear("Sunday 10:42:13"))
    assert_equal [["Sunday 10:42", false]], SpeakCapture.log
    assert_equal "Sunday 10:42", PokeAccess::Info.info_text, "and the info key answers it"
  end

  test "a watch without seconds is said as painted" do
    assert_equal "10:42 PM", PokeAccess::PokegearWatch.time_text(gear("10:42 PM"))
  end

  test "a menu whose watch painted nothing says nothing" do
    PokeAccess::PokegearWatch.opened(gear(nil))
    assert_nothing_spoken
  end

  test "each repaint keeps the info key on the clock without speaking" do
    scene = gear("Sunday 10:42:13")
    PokeAccess::PokegearWatch.ticked(scene)
    scene.instance_variable_set(:@date_string, "Sunday 10:43:01")
    PokeAccess::PokegearWatch.ticked(scene)
    assert_nothing_spoken
    assert_equal "Sunday 10:43", PokeAccess::Info.info_text
  end

  private

  # A Pokegear scene whose watch painted date.
  def gear(date)
    World.stub_scene(:@date_string => date)
  end
end
