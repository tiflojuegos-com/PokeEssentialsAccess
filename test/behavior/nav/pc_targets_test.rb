# PC terminals can be drawn into map tiles rather than their interactive event's sprite.
# Discovery and the existing object emitter are separate assertions; no new sound family is needed.
class PcTargetsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Scene = PokeAccess::Sound::Scene

  test "active graphicless PC calls are objects in the locator and use the existing object family" do
    %w[pbPokeCenterPC pbPokemonPC pbTrainerPC PokemonPC].each do |call|
      World.clear_events
      event = terminal([TestCmd.new(355, [call])])
      assert Loc.pc_event?(event), call
      assert_equal PokeAccess::I18n.t(:loc_pc), Loc.target_name(event)
      assert_includes Loc.candidates(:all), event
      assert_includes Loc.candidates(:objects), event
      refute_includes Loc.candidates(:extras), event
      assert_equal :object, Scene.family_of(event)
    end
  end

  test "a future inactive PC page does not classify the current empty page" do
    current = TestPage.new(:list => [TestCmd.new(0, [])])
    future = TestPage.new(:list => [TestCmd.new(355, ["pbPokeCenterPC"])])
    event = paged([current, future], current)
    refute Loc.pc_event?(event)
    refute_includes Loc.candidates(:objects), event
    assert_nil Scene.family_of(event)
  end

  test "an autorun page mentioning a PC is not an interactive terminal" do
    event = terminal([TestCmd.new(355, ["pbPokeCenterPC"])], 3)
    refute Loc.pc_event?(event)
    refute_includes Loc.candidates(:objects), event
    assert_nil Scene.family_of(event)
  end

  test "ordinary invisible scripts and a similarly named unrelated function do not become PC objects" do
    ["pbPokeCenterPCPreview", "pbMessage('A computer is nearby.')"].each do |script|
      World.clear_events
      event = terminal([TestCmd.new(355, [script])])
      refute Loc.pc_event?(event)
      refute_includes Loc.candidates(:objects), event
      assert_nil Scene.family_of(event)
    end
  end

  test "the cached sound scan includes the graphicless terminal as an object" do
    event = terminal([TestCmd.new(355, ["pbPokeCenterPC"])])
    PokeAccess::Config.audio3d_occlusion = :hear
    with_sound_engine do |_dll|
      scheduler = PokeAccess::Sound::Scheduler
      scheduler.reset_map_state
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_includes Scene.emitters[:object] || [], [event.x, event.y]
    end
  end

  private

  # The original IF6.8.2 Center20 PC has no event graphic, action trigger0, and this script call.
  def terminal(commands, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => commands)
    paged([page], page)
  end

  # Pick a live page explicitly, leaving future pages available as a negative control.
  def paged(pages, active)
    event = TestGameEvent.new(:id => 8, :x => 15, :y => 5, :pages => pages, :active_page => active)
    $game_map.events[event.id] = event
    World.next_frame
    event
  end
end
