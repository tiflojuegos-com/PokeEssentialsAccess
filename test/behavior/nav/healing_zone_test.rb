# Healing floors remain original game events. A directional floor has a reachable approach and a manual final step.
class HealingZoneTest < PokeAccessTest
  Loc = PokeAccess::Locator
  PATH = File.join(Harness::ROOT, "games", "infinitefusion", "healing_zones.rb")

  def self.load_zone_name
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH) if File.file?(PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles) if profiles
  end
  load_zone_name

  test "only the actual IF Tower map uses its purified-zone name" do
    $game_map.map_id = 467
    floor(11, 7, 9, [TestCmd.new(314, [0])])
    assert_equal [t(:if_purified_zone)], targets.map { |target| Loc.target_name(target) }
    $game_map.map_id = 466
    World.next_frame
    assert_equal [t(:loc_healing_zone)], targets.map { |target| Loc.target_name(target) }
  end

  test "a plain active party-healing floor has a named exact-floor target and an independent object emitter" do
    event = floor(11, 7, 9, [TestCmd.new(314, [0])])
    assert_equal 1, targets.length
    target = targets.first
    assert_equal t(:loc_healing_zone), Loc.target_name(target)
    assert_equal [[7, 9]], Loc.goal_of(target).tiles
    assert_includes Loc.candidates(:objects), target
    assert_equal :object, PokeAccess::Sound::Scene.family_of(event)
  end

  test "original Tower directional floors lead to the correct entry side rather than an arbitrary arrival" do
    floor(11, 7, 9, directional(6))
    floor(12, 8, 8, directional(4))
    floor(15, 8, 9, directional(4))
    assert_equal [[6, 9], [9, 8], [9, 9]], targets.map { |target| [target.x, target.y] }.sort
    targets.each do |target|
      assert_equal [[target.x, target.y]], Loc.goal_of(target).tiles
      assert_equal :walk, Loc.route_plan(target).kind
    end
    left = targets.find { |target| target.x == 6 }
    assert_equal t(:loc_healing_approach, :name => t(:loc_healing_zone), :direction => t(:healing_west)), Loc.target_name(left)
    assert_includes Loc.name_marks(left), t(:healing_enter, :direction => t(:dir_right))
    PokeAccess::Config.read_help = false
    assert_empty Loc.name_marks(left)
    assert_equal t(:loc_healing_approach, :name => t(:loc_healing_zone), :direction => t(:healing_west)), Loc.target_name(left)
  end

  test "only the live healing branch is described and cached meaning follows its switch" do
    $game_switches[10] = false
    event = floor(11, 7, 9, [TestCmd.new(111, [0, 10, 0]), TestCmd.new(314, [0], 1), TestCmd.new(412)])
    assert_empty targets
    assert_nil PokeAccess::Sound::Scene.family_of(event)
    $game_switches[10] = true
    World.next_frame
    assert_equal 1, targets.length
    assert_equal :object, PokeAccess::Sound::Scene.family_of(event)
  end

  test "a healing common event is read without running or changing its original commands" do
    previous = $data_common_events
    commands = [TestCmd.new(314, [0])]
    common = Struct.new(:list).new(commands)
    $data_common_events = { 1 => common }
    event = floor(11, 7, 9, [TestCmd.new(117, [1])])
    before = Marshal.dump(commands)
    assert_equal 1, targets.length
    assert_equal :object, PokeAccess::Sound::Scene.family_of(event)
    assert_equal before, Marshal.dump(commands)
  ensure
    $data_common_events = previous
  end

  test "the cached object scan follows a healing branch turning on and off without a player step" do
    original_clock = PokeAccess.method(:clock)
    now = original_clock.call
    PokeAccess.define_singleton_method(:clock) { now }
    $game_switches[10] = false
    event = floor(11, 7, 9, [TestCmd.new(111, [0, 10, 0]), TestCmd.new(314, [0], 1), TestCmd.new(412)])
    PokeAccess::Config.audio3d_occlusion = :hear
    with_sound_engine do |_dll|
      scheduler = PokeAccess::Sound::Scheduler
      scheduler.reset_map_state
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_empty PokeAccess::Sound::Scene.emitters[:object] || []
      $game_switches[10] = true
      World.next_frame
      now += 1.0
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_includes PokeAccess::Sound::Scene.emitters[:object] || [], [event.x, event.y]
      $game_switches[10] = false
      World.next_frame
      now += 1.0
      scheduler.scan_and_ping($game_player.x, $game_player.y)
      assert_empty PokeAccess::Sound::Scene.emitters[:object] || []
    end
  ensure
    PokeAccess.define_singleton_method(:clock, original_clock) if original_clock
  end

  test "inactive future healing autoruns and actor-specific recovery are not healing-floor targets" do
    empty = TestPage.new(:trigger => 1, :list => [TestCmd.new(0, [])])
    future = TestPage.new(:trigger => 1, :list => [TestCmd.new(314, [0])])
    $game_map.events[11] = TestGameEvent.new(:id => 11, :x => 7, :y => 9, :pages => [empty, future], :active_page => empty)
    floor(12, 8, 8, [TestCmd.new(314, [0])], 3)
    floor(15, 8, 9, [TestCmd.new(314, [1])])
    World.next_frame
    assert_empty targets
    [11, 12, 15].each { |id| assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[id]) }
  end

  test "a known healing call in a floor uses the shared recognition" do
    %w[pbHealAll $Trainer.heal_party $player.heal_party].each do |call|
      World.clear_events
      event = floor(11, 7, 9, [TestCmd.new(355, [call])])
      assert_equal 1, targets.length, call
      assert_equal :object, PokeAccess::Sound::Scene.family_of(event), call
    end
  end

  test "an unreadable branch and an unrelated invisible message do not invent a healing zone" do
    floor(11, 7, 9, [TestCmd.new(111, [12, "an_unknown_game_condition"]), TestCmd.new(314, [0], 1), TestCmd.new(412)])
    floor(12, 8, 8, [TestCmd.new(101, ["A peaceful place."])])
    assert_empty targets
    [11, 12].each { |id| assert_nil PokeAccess::Sound::Scene.family_of($game_map.events[id]) }
    ["pbMessage('pbHealAll')", "pbHealAllPreview", "pbNurseHeal", "if unknown_condition\n  pbHealAll\nend",
     "if unknown_condition\n  $Trainer.heal_party\nend"].each do |script|
      World.clear_events
      event = floor(11, 7, 9, [TestCmd.new(355, [script])])
      assert_empty targets
      assert_nil PokeAccess::Sound::Scene.family_of(event)
    end
  end

  private

  def t(key, params = {}); PokeAccess::I18n.t(key, params); end

  # Public locator output, separated from whether an event is eligible to emit sound.
  def targets
    Loc.candidates(:all).select { |target| target.is_a?(Loc::SurfaceTarget) && target.key == :healing_zone }
  end

  # Actual IF Purified Zone pages branch on the player's facing, show text and Recover All[0].
  def directional(direction)
    [TestCmd.new(111, [6, -1, direction]), TestCmd.new(101, ["Entered purified, protected zone!"], 1),
     TestCmd.new(314, [0], 1), TestCmd.new(412)]
  end

  # An invisible active floor, retaining the engine's normal arrival rule.
  def floor(id, x, y, commands, trigger = 1)
    page = TestPage.new(:trigger => trigger, :list => commands)
    event = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page])
    $game_map.events[id] = event
    World.next_frame
    event
  end
end
