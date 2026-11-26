# Pokemon Reborn's puzzles of the remate A (games/reborn/puzzles/): the Sapphire Room's way across the ice with the
# assist, told by the crystals lit and the ground the player last came into.
class RebornPuzzlesRemateATest < PokeAccessTest
  SWITCHES = [1218, 1219, 1220, 1221, 1222, 1223, 1224, 1225]

  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
  end

  def teardown
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::RebornVrSapphirePlan.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "The Sapphire Room's plan starts at the first wall from the arrival, and only with the assist" do
    on_map(804, 63, 69)
    place(6, 65, 63, "RockClimb")
    plan = PokeAccess::RebornVrSapphirePlan
    assert_equal [6, 1], plan.target
    refute_includes info_key, "rbg_plan_step"
    refute(listed.any? { |t| t[0] == 65 && t[1] == 63 })
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbg_plan_step n=1 total=34 what={rbra_ice_climb} where=2 {dir_right}, 6 {dir_up}}"
    assert_includes listed, [65, 63, "{rbra_ice_climb}"]
  end

  test "A crystal lit moves the plan on from where it was used, and the ground stays as the player walks it" do
    on_map(804, 62, 59)
    plan = PokeAccess::RebornVrSapphirePlan
    assert_equal [27, 3], plan.target
    walk_to(44, 62)
    assert_equal [27, 3], plan.target
    $game_switches[1218] = true
    place(8, 53, 64, "RockClimb")
    assert_equal [8, 4], plan.target
    walk_to(50, 61)
    assert_equal [8, 4], plan.target
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbg_plan_step n=4 total=34 what={rbra_ice_climb} where=3 {dir_right}, 3 {dir_down}}"
  end

  test "Off the plan the way back is named with no step, and an unknown ground names the crystal to light next" do
    on_map(804, 52, 64)
    plan = PokeAccess::RebornVrSapphirePlan
    place(8, 53, 64, "RockClimb")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [8, nil], plan.target
    assert_includes info_key, "{rbg_plan_off what={rbra_ice_climb} where=1 {dir_right}}"
    on_map(804, 30, 40)
    $game_switches[1218] = true
    $game_switches[1219] = true
    place(32, 21, 58, "EV032")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [32, nil], plan.target
    assert_includes info_key, "{rbg_plan_off what={rbra_ice_crystal}"
    on_map(804, 64, 69)
    [1218, 1219, 1220].each { |s| $game_switches[s] = true }
    assert_equal [6, nil], plan.target
  end

  test "Crystals lit out of their only order leave the plan silent, and so does another map" do
    on_map(804, 63, 69)
    $game_switches[1219] = true
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::RebornVrSapphirePlan.target
    refute_includes info_key, "rbg_plan"
    on_map(803, 63, 69)
    assert_nil PokeAccess::RebornVrSapphirePlan.target
  end

  test "The plan's data holds every step once, the crystals in their order and the way out last" do
    plan = PokeAccess::RebornVrSapphirePlan
    steps = {}
    plan::GROUNDS.each_with_index do |grounds, phase|
      grounds.each do |ev, n, tiles|
        assert_equal 0, tiles.length % 2
        next unless n
        assert_nil steps[n], "step #{n} twice"
        steps[n] = [phase, ev]
      end
    end
    assert_equal (1..plan::STEPS).to_a, steps.keys.sort
    phases = steps.keys.sort.map { |n| steps[n][0] }
    assert_equal phases.sort, phases
    lit = steps.keys.sort.map { |n| steps[n] }.select { |ph, ev| plan::CRYSTALS.include?(ev) }
    assert_equal plan::CRYSTALS, lit.map { |_ph, ev| ev }
    assert_equal (0...plan::CHAIN.length).to_a, lit.map { |ph, _ev| ph }
    assert_equal [plan::CHAIN.length, plan::EXIT], steps[plan::STEPS]
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbra_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbra_kept_t)
    i18n.send(:remove_method, :rbra_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    SWITCHES.each { |s| $game_switches[s] = false }
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::RebornVrSapphirePlan.forget
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
    info_key
  end

  def walk_to(x, y)
    $game_player.x = x
    $game_player.y = y
    World.next_frame
  end

  def place(id, x, y, name, sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
