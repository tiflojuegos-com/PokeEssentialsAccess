# A PC the map's tiles draw (an event with no sprite, used with the action key, one of whose pages opens the PC before
# saying anything) is an object, named PC, with the object's sound; a person who opens the PC, the counter of one who
# talks first, and an event that only picks a Pokemon from the boxes keep their own reading.
class PcTargetsTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Scene = PokeAccess::Sound::Scene

  test "a PC drawn on the map is an object named PC, with the object's sound, whatever call opens it" do
    %w[pbPokeCenterPC pbPokemonPC pbTrainerPC PokemonPC].each do |call|
      World.clear_events
      event = terminal([TestCmd.new(355, [call])])
      assert_equal [true, PokeAccess::I18n.t(:loc_pc), :object], [Loc.pc_terminal?(event), Loc.target_name(event),
                                                                  Scene.family_of(event)], call
      assert_includes Loc.candidates(:all), event
      assert_includes Loc.candidates(:objects), event
      refute_includes Loc.candidates(:extras), event
    end
  end

  test "a PC whose page turns on an automatic page that opens it, as Infinite Fusion's do, is drawn on the map" do
    use = TestPage.new(:trigger => 0, :list => [TestCmd.new(123, ["A", 0])])
    open = TestPage.new(:trigger => 3, :condition => { :self_switch_valid => true, :self_switch_ch => "A" },
                        :list => [TestCmd.new(355, ["pbPokeCenterPC"]), TestCmd.new(123, ["A", 1])])
    event = paged([use, open], use)
    assert_equal [true, :object], [Loc.pc_terminal?(event), Scene.family_of(event)]
    assert_includes Loc.candidates(:objects), event
  end

  test "a PC that only opens facing it, or once a switch is on, is drawn on the map; its refusal comes after" do
    branch = [TestCmd.new(111, [6, -1, 8]), TestCmd.new(355, ["pbPokeCenterPC"], 1), TestCmd.new(0, [], 1),
              TestCmd.new(411), TestCmd.new(101, ["No puedes interactuar de lado."], 1), TestCmd.new(412)]
    event = terminal(branch)
    assert_equal [true, false], [Loc.pc_terminal?(event), Loc.sign_event?(event)]
    assert_includes Loc.candidates(:objects), event
    refute_includes Loc.candidates(:signs), event
  end

  test "a counter that talks before it opens the PC stays among the signs" do
    talk = [TestCmd.new(101, ["F3: ¿Necesitas algo?"]), TestCmd.new(102, [["Curar", "Rancho"], 2]),
            TestCmd.new(402, [1, "Rancho"]), TestCmd.new(355, ["pbPokeCenterPC"], 1)]
    event = terminal(talk)
    refute Loc.pc_terminal?(event)
    assert_includes Loc.candidates(:signs), event
    refute_includes Loc.candidates(:objects), event
  end

  test "a person who opens the PC stays a person" do
    page = TestPage.new(:trigger => 0, :sprite => "trainer_SCIENTIST_M",
                        :list => [TestCmd.new(101, ["¿Quieres usar el PC?"]), TestCmd.new(355, ["pbPokeCenterPC"])])
    event = paged([page], page)
    refute Loc.pc_terminal?(event)
    assert_includes Loc.candidates(:people), event
    refute_includes Loc.candidates(:objects), event
  end

  test "a PC with nothing to do on its page yet, or used by touch or on its own, is not drawn on the map" do
    current = TestPage.new(:list => [TestCmd.new(0, [])])
    later = TestPage.new(:list => [TestCmd.new(355, ["pbPokeCenterPC"])])
    [paged([current, later], current), terminal([TestCmd.new(355, ["pbPokeCenterPC"])], 1),
     terminal([TestCmd.new(355, ["pbPokeCenterPC"])], 3)].each do |event|
      refute Loc.pc_terminal?(event)
      refute_includes Loc.candidates(:objects), event
      assert_nil Scene.family_of(event)
      World.clear_events
    end
  end

  test "a script that only mentions a PC, or a call with a longer name, opens none" do
    ["pbPokeCenterPCPreview", "pbMessage('A computer is nearby.')"].each do |script|
      World.clear_events
      event = terminal([TestCmd.new(355, [script])])
      assert_equal [false, false], [Loc.pc_event?(event), Loc.pc_terminal?(event)], script
    end
  end

  test "a person who picks a Pokemon from the boxes is not named PC" do
    page = TestPage.new(:trigger => 0, :sprite => "NPC_Hoenn_RichBoy",
                        :list => [TestCmd.new(355, ["pbChoosePokemonPC(1,2,"])])
    event = paged([page], page)
    refute Loc.pc_event?(event)
    refute_equal PokeAccess::I18n.t(:loc_pc), Loc.target_name(event)
  end

  test "the sound scan sounds a PC drawn on the map as an object" do
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

  # An event with no sprite whose one page, run by trigger, holds the commands.
  def terminal(commands, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => commands)
    paged([page], page)
  end

  # An event with those pages, the given one active, placed on the map.
  def paged(pages, active)
    event = TestGameEvent.new(:id => 8, :x => 15, :y => 5, :pages => pages, :active_page => active)
    $game_map.events[event.id] = event
    World.next_frame
    event
  end
end
