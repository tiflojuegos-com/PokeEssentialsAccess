# Invisible active scenes become optional locator targets and existing control cues without executing their pages.
require "tmpdir"

class SceneGuidanceTest < PokeAccessTest
  test "both touch triggers enter the scene list and everything, with an exact floor goal and control cue" do
    [1, 2].each do |trigger|
      World.clear_events
      ev = scene(:trigger => trigger)
      assert_equal [ev], PokeAccess::Locator.candidates(:scenes)
      assert_includes PokeAccess::Locator.candidates(:all), ev
      assert_includes PokeAccess::Locator.active_categories, :scenes
      assert_equal PokeAccess::I18n.t(:loc_scene_trigger), PokeAccess::Locator.target_name(ev)
      assert_equal [[ev.x, ev.y]], PokeAccess::Locator.goal_of(ev).tiles
      assert_equal :control, PokeAccess::Sound::Scene.family_of(ev)
    end
  end

  test "turning guidance off removes automatic targets and cues and turning it on restores them" do
    ev = scene
    PokeAccess::Config.set(:scene_guidance, false)
    refute_includes PokeAccess::Locator.candidates(:all), ev
    assert_empty PokeAccess::Locator.candidates(:scenes)
    refute_includes PokeAccess::Locator.active_categories, :scenes
    assert_nil PokeAccess::Sound::Scene.family_of(ev)
    PokeAccess::Config.set(:scene_guidance, true)
    assert_equal [ev], PokeAccess::Locator.candidates(:scenes)
    assert_equal :control, PokeAccess::Sound::Scene.family_of(ev)
  end

  test "inactive future pages are not exposed and completion removes an active marker" do
    empty = TestPage.new(:trigger => 1, :list => [TestCmd.new(0)])
    active = TestPage.new(:trigger => 1, :list => commands)
    ev = paged_scene([empty, active], empty)
    refute PokeAccess::SceneTriggers.event?(ev)
    ev = paged_scene([empty, active], active)
    assert PokeAccess::SceneTriggers.event?(ev)
    ev = paged_scene([active, empty], empty)
    refute PokeAccess::SceneTriggers.event?(ev)
    assert_empty PokeAccess::Locator.candidates(:scenes)
    assert_nil PokeAccess::Sound::Scene.family_of(ev)
  end

  test "direction-gated scenes are not offered with an unrestricted floor goal" do
    list = [TestCmd.new(111, [6, -1, 8]), TestCmd.new(101, ["Approach from the south."], 1),
            TestCmd.new(123, ["A", 0], 1), TestCmd.new(412)]
    ev = scene(:list => list)
    refute PokeAccess::SceneTriggers.event?(ev)
    assert_empty PokeAccess::Locator.candidates(:scenes)
    assert_nil PokeAccess::Sound::Scene.family_of(ev)
  end

  test "a saved guidance change refreshes cached emitters without requiring a player step" do
    ev = scene
    PokeAccess::Config.audio3d_occlusion = :hear
    with_sound_engine do |_dll|
      scheduler = PokeAccess::Sound::Scheduler
      scheduler.reset_map_state
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_equal [[ev.x, ev.y]], PokeAccess::Sound::Scene.emitters[:control]
      PokeAccess::Config.set(:scene_guidance, false)
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_empty PokeAccess::Sound::Scene.emitters[:control] || []
      PokeAccess::Config.set(:scene_guidance, true)
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_equal [[ev.x, ev.y]], PokeAccess::Sound::Scene.emitters[:control]
    end
  end

  test "a disabled selected scene becomes invalid and the normal locator refresh drops it" do
    ev = scene
    PokeAccess::Locator.step(1)
    assert_equal ev, PokeAccess::Locator.target
    assert PokeAccess::Locator.target_valid?
    PokeAccess::Config.set(:scene_guidance, false)
    refute PokeAccess::Locator.target_valid?
    PokeAccess::Locator.ensure_target
    assert_nil PokeAccess::Locator.target
  end

  test "live branch flags invalidate the cached scene meaning without replacing the event" do
    list = [TestCmd.new(111, [0, 77, 0]), TestCmd.new(101, ["A journey begins."], 1),
            TestCmd.new(123, ["A", 0], 1), TestCmd.new(412)]
    ev = scene(:list => list)
    $game_switches[77] = false
    World.next_frame
    refute PokeAccess::SceneTriggers.event?(ev)
    $game_switches[77] = true
    World.next_frame
    assert PokeAccess::SceneTriggers.event?(ev)
    $game_switches[77] = false
    World.next_frame
    refute PokeAccess::SceneTriggers.event?(ev)
  end

  test "common events are read without running arbitrary script text or changing player state" do
    previous = $data_common_events
    $data_common_events = []
    $data_common_events[4] = Struct.new(:list).new(commands)
    ev = scene(:list => [TestCmd.new(117, [4])])
    before = Marshal.dump([$game_switches, $game_variables, $game_self_switches, $game_player.x, $game_player.y])
    assert PokeAccess::SceneTriggers.event?(ev)
    PokeAccess::Config.hide_noninteractive = true
    assert_equal [ev], PokeAccess::Locator.filtered(PokeAccess::Locator.candidates(:scenes), :scenes)
    script = "$scene_guidance_executed = true; pbMessage('Scene'); pbSetSelfSwitch('A', true)"
    ev = scene(:list => [TestCmd.new(355, [script])])
    3.times do
      assert PokeAccess::SceneTriggers.event?(ev)
      PokeAccess::Locator.candidates(:scenes)
      PokeAccess::Sound::Scene.family_of(ev)
    end
    assert_nil $scene_guidance_executed
    assert_equal before, Marshal.dump([$game_switches, $game_variables, $game_self_switches, $game_player.x, $game_player.y])
  ensure
    $data_common_events = previous
  end

  test "unknown outcomes and ordinary text or switches alone do not promise a story scene" do
    [[TestCmd.new(101, ["Wind."])], [TestCmd.new(123, ["A", 0])],
     commands + [TestCmd.new(117, [99999])],
     [TestCmd.new(111, [12, "unsupported_scene_condition?"])] + commands].each do |list|
      World.clear_events
      refute PokeAccess::SceneTriggers.event?(scene(:list => list))
    end
    [0, 3, 4].each do |trigger|
      World.clear_events
      refute PokeAccess::SceneTriggers.event?(scene(:trigger => trigger))
    end
  end

  test "visible people, tile graphics, transfers and declared pieces keep their existing roles" do
    person = scene(:sprite => "NPC")
    refute PokeAccess::SceneTriggers.event?(person)
    tile = scene
    tile.tile_id = 414
    World.next_frame
    refute PokeAccess::SceneTriggers.event?(tile)
    door = scene(:list => commands + [TestCmd.new(201, [0, 5, 1, 1])])
    refute PokeAccess::SceneTriggers.event?(door)
    assert_equal :door, PokeAccess::Sound::Scene.family_of(door)
    World.clear_events
    PokeAccess::World::Mechanics.define(:state, $game_map.map_id) do
      watch :switch => 128, :quiet => true
      controls
    end
    ev = scene(:id => 3, :list => [TestCmd.new(101, ["A control."]), TestCmd.new(121, [128, 128, 0])])
    PokeAccess::World::Mechanics.forget
    assert PokeAccess::World::Mechanics.piece_of(ev)
    refute PokeAccess::SceneTriggers.event?(ev)
    assert_equal :control, PokeAccess::Sound::Scene.family_of(ev)
  end

  test "a bump-triggered scene keeps an adjacent goal while a scene moving the player is not simulated" do
    ev = scene
    ev.define_singleton_method(:over_trigger?) { false }
    PokeAccess::World::Events.forget
    refute PokeAccess::Locator.onto?(ev)
    assert_equal PokeAccess::Routes::Goal.near(ev.x, ev.y).tiles, PokeAccess::Locator.goal_of(ev).tiles
    assert_operator PokeAccess::Locator.goal_of(ev).tiles.length, :>, 1
    ev = scene(:list => commands + [World.move_player([1])])
    assert PokeAccess::Locator.onto?(ev)
    before = [$game_player.x, $game_player.y]
    assert_equal [[ev.x, ev.y]], PokeAccess::Locator.goal_of(ev).tiles
    assert_equal before, [$game_player.x, $game_player.y]
  end

  test "a floor scene uses an ordinary route around obstacles and stays unreachable behind a closed barrier" do
    dimensions = [$game_map.width, $game_map.height]
    planner = PokeAccess::Routes::Planner
    walls(["#########", "#@.#....#", "#..#....#", "#.......#", "#########"])
    ev = scene(:x => 6, :y => 1, :list => commands + [World.move_player([1])])
    before = Marshal.dump([$game_switches, $game_variables, $game_self_switches,
                           $game_player.x, $game_player.y, $game_player.instance_variable_get(:@through)])
    plan = planner.plan(ev.x, ev.y, PokeAccess::Locator.onto?(ev))
    assert_equal :walk, plan.kind
    assert_equal 9, plan.route.length
    finish = plan.route.inject([$game_player.x, $game_player.y]) do |at, direction|
      delta = PokeAccess::DIR_DELTA[direction]
      [at[0] + delta[0], at[1] + delta[1]]
    end
    assert_equal [ev.x, ev.y], finish
    assert_equal before, Marshal.dump([$game_switches, $game_variables, $game_self_switches,
                                      $game_player.x, $game_player.y, $game_player.instance_variable_get(:@through)])
    walls(["#########", "#@.#....#", "#..#....#", "#..#....#", "#########"])
    ev = scene(:x => 6, :y => 1)
    assert_equal :none, planner.plan(ev.x, ev.y, PokeAccess::Locator.onto?(ev)).kind
  ensure
    $game_map.width, $game_map.height = dimensions if dimensions
    World.next_frame
  end

  test "optional advice can be hidden while the essential name remains and hidden targets stay hidden" do
    ev = scene
    assert_equal [PokeAccess::I18n.t(:scene_step_onto)], PokeAccess::Locator.name_marks(ev)
    PokeAccess::Config.read_help = false
    assert_empty PokeAccess::Locator.name_marks(ev)
    assert_equal PokeAccess::I18n.t(:loc_scene_trigger), PokeAccess::Locator.target_name(ev)
    rule = lambda { |target| target.equal?(ev) }
    PokeAccess::Locator.register_rule(:hidden, &rule)
    begin
      assert_empty PokeAccess::Locator.candidates(:scenes)
      refute PokeAccess::SceneTriggers.any?
      assert_nil PokeAccess::Sound::Scene.family_of(ev)
    ensure
      PokeAccess::Locator.instance_variable_get(:@rules)[:hidden].delete_if { |_value, block| block.equal?(rule) }
    end
  end

  test "both guidance choices persist through the real settings writer and parser" do
    Dir.mktmpdir do |folder|
      previous = PokeAccess::Settings::FILE
      PokeAccess::Settings.send(:remove_const, :FILE)
      path = File.join(folder, "settings.ini")
      PokeAccess::Settings.const_set(:FILE, path)
      begin
        [false, true].each do |value|
          PokeAccess::Config.scene_guidance = value
          assert_equal true, PokeAccess::Settings.write
          assert_includes File.read(path), "scene_guidance=#{value}\n"
          PokeAccess::Config.scene_guidance = !value
          PokeAccess::Settings.apply
          assert_equal value, PokeAccess::Config.scene_guidance
        end
      ensure
        PokeAccess::Settings.send(:remove_const, :FILE)
        PokeAccess::Settings.const_set(:FILE, previous)
      end
    end
  end

  private

  # Both engine fixtures honor static blocking events; only the gen6 fixture implements load_grid.
  def walls(rows)
    World.clear_events
    $game_map.width = rows.first.length
    $game_map.height = rows.length
    $game_player.x = 1
    $game_player.y = 1
    id = 100
    rows.each_with_index do |row, y|
      row.length.times do |x|
        next unless row[x, 1] == "#"
        ev = World.event(:id => id, :x => x, :y => y, :sprite => "")
        ev.blocking = true
        id += 1
      end
    end
    World.next_frame
  end

  def commands
    [TestCmd.new(101, ["A journey begins."]), TestCmd.new(123, ["A", 0]), TestCmd.new(0)]
  end

  def scene(opts = {})
    ev = World.touch({ :id => 17, :x => 4, :y => 3, :list => commands }.merge(opts))
    ev.define_singleton_method(:over_trigger?) { true }
    ev
  end

  def paged_scene(pages, active)
    ev = TestGameEvent.new(:id => 17, :x => 4, :y => 3, :pages => pages, :active_page => active)
    ev.define_singleton_method(:over_trigger?) { true }
    $game_map.events[17] = ev
    World.next_frame
    ev
  end
end
