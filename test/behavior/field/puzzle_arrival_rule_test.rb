# A puzzle room's rule (arrival_hint, such as the trap tiles of Opalo's psychic gym) is a description: said on entering
# only in full, and closing the info key's line at every level, so brief and medium still reach it.

class PuzzleArrivalRuleTest < PokeAccessTest
  ROOM = 36
  LIGHT_SWITCH = 313

  test "says the room's rule on entering in full, queued" do
    entering_room(:full) do
      assert_equal [[PokeAccess::I18n.t(:op_traps_hint), false]], SpeakCapture.log
    end
  end

  test "keeps the rule quiet on entering in brief and medium" do
    [:brief, :medium].each do |level|
      entering_room(level) { assert_equal [], SpeakCapture.log, "at #{level}" }
    end
  end

  test "closes the info key's line with the rule at every level" do
    t = PokeAccess::I18n
    expected = "#{t.t(:op_lights)}: #{t.t(:op_lights_off)}. #{t.t(:op_traps_hint)}"
    vb_levels do
      entering_room(PokeAccess::Config.verbosity) do
        PokeAccess::Locator.refresh_info
        SpeakCapture.clear
        PokeAccess::Keys.info_key
        assert_equal [expected], SpeakCapture.lines, "at #{PokeAccess::Config.verbosity}"
      end
    end
  end

  private

  def entering_room(level)
    was_map = $game_map.map_id
    PokeAccess::Config.verbosity = level
    PokeAccess::World::Mechanics.define(:state, ROOM) do
      watch :switch => 313, :label => :op_lights, :on => :op_lights_on, :off => :op_lights_off
      arrival_hint :op_traps_hint
    end
    $game_switches[LIGHT_SWITCH] = false
    $game_map.map_id = ROOM
    PokeAccess::Caches.reset_all
    SpeakCapture.clear
    PokeAccess::Puzzles.tick
    yield
  ensure
    PokeAccess::Config.verbosity = :full
    $game_map.map_id = was_map
    PokeAccess::Caches.reset_all
  end
end
