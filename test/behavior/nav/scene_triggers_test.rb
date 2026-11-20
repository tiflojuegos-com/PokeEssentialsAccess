# Scene triggers (core/nav/scene_triggers.rb), off by default: an invisible touch page that from every side says
# something and sets something that stays is located in its own category, never in all, named as a scene trigger,
# with a sound of its own; a row of them running the same page is one target, sounding from its middle tile.
class SceneTriggersTest < PokeAccessTest
  Loc = PokeAccess::Locator
  Scene = PokeAccess::Sound::Scene
  Triggers = PokeAccess::SceneTriggers

  test "off by default, a scene is listed nowhere, adds no category and does not sound" do
    ev = scene
    assert_equal [false, [], false, nil], [Triggers.event?(ev), Loc.candidates(:scenes),
                                          Loc.active_categories.include?(:scenes), Scene.family_of(ev)]
  end

  test "on, a scene started on arrival or by touch is in the scenes category alone, named, sounding as a scene" do
    [1, 2].each do |trigger|
      World.clear_events
      on
      ev = scene(:trigger => trigger)
      assert_equal [[ev], true, PokeAccess::I18n.t(:loc_scene_trigger), :scene],
                   [Loc.candidates(:scenes), Loc.active_categories.include?(:scenes), Loc.target_name(ev),
                    Scene.family_of(ev)], "trigger #{trigger}"
      refute_includes Loc.candidates(:all), ev
    end
  end

  test "a scene started on arrival leads the route onto its tile" do
    on
    ev = scene
    assert_equal [true, [[ev.x, ev.y]]], [Loc.onto?(ev), Loc.goal_of(ev).tiles]
  end

  test "a selected scene stays the target until scene triggers go off" do
    on
    ev = scene
    12.times { Loc.cycle_category(1) unless Loc.category == :scenes }
    assert_equal :scenes, Loc.category
    Loc.step(1)
    assert_equal [ev, true], [Loc.target, Loc.target_valid?]
    PokeAccess::Config.set(:scene_triggers, false)
    refute Loc.target_valid?
  end

  test "a row of triggers running the same page is one target, sounding from its middle tile only" do
    on
    row = (3..7).map { |x| scene(:id => 20 + x, :x => x, :y => 3) }
    other = scene(:id => 40, :x => 4, :y => 9)
    listed = Loc.candidates(:scenes)
    assert_equal [2, true], [listed.length, listed.include?(other)]
    assert_equal [nil, nil, :scene, nil, nil], row.map { |ev| Scene.family_of(ev) }
  end

  test "neighbours running different pages are two scenes" do
    on
    scene(:id => 21, :x => 3, :y => 3)
    scene(:id => 22, :x => 4, :y => 3, :list => [TestCmd.new(101, ["Another scene."]), TestCmd.new(121, [5, 5, 0])])
    assert_equal 2, Loc.candidates(:scenes).length
  end

  test "a page that transfers, says nothing, changes nothing or asks the way the player faces is no scene" do
    on
    lists = [[TestCmd.new(101, ["Off you go."]), TestCmd.new(123, ["A", 0]), TestCmd.new(201, [0, 9, 1, 1])],
             [TestCmd.new(123, ["A", 0])],
             [TestCmd.new(101, ["Just words."])],
             [TestCmd.new(111, [6, -1, 8]), TestCmd.new(101, ["From the south."], 1), TestCmd.new(123, ["A", 0], 1),
              TestCmd.new(412)]]
    lists.each_with_index do |list, i|
      World.clear_events
      refute Triggers.event?(scene(:list => list)), "list #{i}"
    end
  end

  test "an event with a sprite, or a page run by the action key, is no scene" do
    on
    page = TestPage.new(:trigger => 1, :sprite => "NPC_Guide", :list => commands)
    refute Triggers.event?(paged([page], page)), "a sprite"
    World.clear_events
    page = TestPage.new(:trigger => 0, :list => commands)
    refute Triggers.event?(paged([page], page)), "the action key"
  end

  test "a scene whose page is no longer the live one is no longer offered" do
    on
    empty = TestPage.new(:trigger => 1, :list => [TestCmd.new(0)])
    live = TestPage.new(:trigger => 1, :list => commands)
    assert_equal [false, true], [Triggers.event?(paged([empty, live], empty)), Triggers.event?(paged([empty, live], live))]
  end

  test "turning scene triggers on and off reaches the sound without a step" do
    ev = scene
    PokeAccess::Config.audio3d_occlusion = :hear
    with_sound_engine do |_dll|
      scheduler = PokeAccess::Sound::Scheduler
      scheduler.reset_map_state
      heard = [true, false].map do |value|
        PokeAccess::Config.set(:scene_triggers, value)
        scheduler.scan_and_ping($game_player.x, $game_player.y)
        Scene.emitters[:scene] || []
      end
      assert_equal [[[ev.x, ev.y]], []], heard
    end
  end

  private

  # Turns scene triggers on.
  def on
    PokeAccess::Config.set(:scene_triggers, true)
  end

  # What the scenes say and set: a line, then self switch A.
  def commands
    [TestCmd.new(101, ["A journey begins."]), TestCmd.new(123, ["A", 0]), TestCmd.new(0)]
  end

  # An invisible scene trigger the engine runs on arrival, on (4, 3) unless opts say otherwise.
  def scene(opts = {})
    ev = World.touch({ :id => 17, :x => 4, :y => 3, :list => commands }.merge(opts))
    ev.define_singleton_method(:over_trigger?) { true }
    World.next_frame
    ev
  end

  # An event on (4, 3) with those pages, the given one live.
  def paged(pages, active)
    ev = TestGameEvent.new(:id => 17, :x => 4, :y => 3, :pages => pages, :active_page => active)
    ev.define_singleton_method(:over_trigger?) { true }
    $game_map.events[17] = ev
    World.next_frame
    ev
  end
end
