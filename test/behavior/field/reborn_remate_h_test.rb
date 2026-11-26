# Pokemon Reborn's remate H (games/reborn/puzzles/victory_road_mine1_*.rb): the plan of Victory Road's first mine
# across the atrium and B1F with the assist, pushes included, and what brings a player off it back.
class RebornRemateHTest < PokeAccessTest
  def setup
    super
    keyed
    Harness.load_puzzles("reborn")
    @at = [$game_player.x, $game_player.y]
    @map = $game_map.map_id
    @selfs = $game_self_switches
  end

  def teardown
    World.clear_events
    clear_state
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "The plan starts with the door plate's boulder, pushed right from behind it, and only with the assist" do
    on_map(784, 15, 68)
    rock = place(68, 40, 37, "Boulder", "text", "rockstrength3")
    route = PokeAccess::RebornVrMineRoute
    assert_equal [:push, 68, 0], route.target
    assert_equal [39, 37], route.next_at
    refute_includes info_key, "rbg_plan_step"
    refute(listed.any? { |t| t[0] == 39 && t[1] == 37 })
    PokeAccess::Config.puzzle_assist = true
    total = PokeAccess::RebornVrMineData::PLAN[:steps].length
    assert_includes info_key, "{rbg_plan_step n=1 total=#{total} what={rbrh_push_n dir={rbrh_dir_right} n=4} " \
                              "where=24 {dir_right}, 31 {dir_up}}"
    assert_includes listed, [39, 37, "{rbrh_push_n dir={rbrh_dir_right} n=4}"]
    rock.x = 42
    assert_equal [41, 37], route.next_at
    assert_equal "{rbrh_push_n dir={rbrh_dir_right} n=2}", route.next_label
    rock.x = 43
    assert_equal "{rbrh_push dir={rbrh_dir_right}}", route.next_label
  end

  test "A boulder pushed off the plan's line asks to leave the room so the boulders go back" do
    on_map(784, 15, 68)
    place(68, 41, 38, "Boulder", "text", "rockstrength3")
    PokeAccess::Config.puzzle_assist = true
    assert_nil PokeAccess::RebornVrMineRoute.step
    assert_includes info_key, "{rbrh_reset}"
  end

  test "The story's variable below the atrium's own value still finds the first step" do
    on_map(784, 15, 68)
    $game_variables[475] = 100
    place(68, 40, 37, "Boulder", "text", "rockstrength3")
    assert_equal [:push, 68, 0], PokeAccess::RebornVrMineRoute.target
  end

  test "Off the plan in B1F the lever that brings it back is named" do
    on_map(786, 28, 39)
    [1101, 1102, 1103, 1107, 1114].each { |s| $game_switches[s] = true }
    { 475 => 112, 484 => 3, 486 => 1, 487 => 1 }.each { |v, n| $game_variables[v] = n }
    place(35, 27, 60, "EV035")
    PokeAccess::Config.puzzle_assist = true
    route = PokeAccess::RebornVrMineRoute
    assert_nil route.step
    assert_equal [:back, 35, nil], route.target
    assert_includes info_key, "{rbg_plan_off what={rbg_plan_back} where=1 {dir_left}, 21 {dir_down}}"
    $game_switches[1114] = false
    place(22, 28, 40, "EV022")
    assert_equal [:lever, 22], route.target[0, 2]
    assert_includes listed, [28, 40, "{rbg_plan_lever}"]
  end

  test "Once the story is past the plan's end the mine says nothing" do
    on_map(786, 28, 39)
    $game_variables[475] = PokeAccess::RebornVrMineData::PLAN[:done_at]
    PokeAccess::Config.puzzle_assist = true
    refute PokeAccess::RebornVrMineRoute.live?
    refute_includes info_key, "rbrh_"
    refute_includes info_key, "rbg_plan"
  end

  test "Past the third explosive cart the atrium's plate boulder goes left first, from behind it" do
    i = step_index { |s| s[0] == 784 && s[1] == 75 }
    on_map(784, 95, 65)
    apply_sig(PokeAccess::RebornVrMineData::PLAN[:steps][i][3])
    place(75, 111, 61, "Boulder", "text", "rockstrength3")
    route = PokeAccess::RebornVrMineRoute
    assert_equal [:push, 75, i], route.target
    assert_equal [112, 61], route.next_at
    assert_equal "{rbrh_push_n dir={rbrh_dir_left} n=2}", route.next_label
  end

  test "With the gate open the lever comes first, and with it on the fourth cart drops to B1F's south" do
    i = step_index { |s| s[0] == 784 && s[1] == 130 }
    on_map(784, 99, 51)
    apply_sig(PokeAccess::RebornVrMineData::PLAN[:steps][i][3])
    place(75, 103, 54, "Boulder", "text", "rockstrength3")
    place(130, 98, 51, "EV130")
    place(132, 95, 61, "Cart4")
    route = PokeAccess::RebornVrMineRoute
    assert_equal [:lever, 130, i], route.target
    assert_equal [98, 51], route.next_at
    $game_switches[1122] = true
    assert_equal [:cart, 132, i + 1], route.target
    assert_equal [95, 61], route.next_at
  end

  test "The south cart is pushed once every lever of its zone is off again, the last one inside its pen" do
    i = step_index { |s| s[0] == 786 && s[1] == 47 }
    on_map(786, 115, 64)
    apply_sig(PokeAccess::RebornVrMineData::PLAN[:steps][i][3])
    place(63, 105, 50, "Boulder", "text", "rockstrength2")
    route = PokeAccess::RebornVrMineRoute
    assert_equal [:cart, 47, i], route.target
    $game_switches[1127] = true
    assert_equal [:lever, 48, i - 1], route.target
  end

  test "After the pillar the plan ends at the atrium's way out, and says its number" do
    plan = PokeAccess::RebornVrMineData::PLAN
    last = plan[:steps].length - 1
    assert_equal [812, 15, :exit], plan[:steps][last][0, 3]
    on_map(812, 127, 32)
    apply_sig(plan[:steps][last][3])
    place(15, 129, 33, "EV015")
    PokeAccess::Config.puzzle_assist = true
    route = PokeAccess::RebornVrMineRoute
    assert_equal [:exit, 15, last], route.target
    assert_includes info_key, "{rbg_plan_step n=#{last + 1} total=#{last + 1} what={rbrh_exit}"
    $game_variables[475] = plan[:done_at]
    refute route.live?
  end

  test "The plan's data is well formed: known kinds, pushes as tile, way and count, states of its own flags" do
    plan = PokeAccess::RebornVrMineData::PLAN
    flags = plan[:switches].map { |s| "S#{s}" }
    kinds = [:cart, :lever, :use, :climb, :smash, :push, :exit, :touch]
    plan[:steps].each_with_index do |s, i|
      assert_includes plan[:maps], s[0], "step #{i + 1}"
      assert_includes kinds, s[2], "step #{i + 1}"
      s[3].split(",").each do |f|
        ok = flags.include?(f) || (f =~ /\AV(\d+)=\d+\z/ && plan[:vars].include?($1.to_i))
        assert ok, "step #{i + 1}: #{f}"
      end
      next unless s[2] == :push
      assert_equal 4, s[4].length, "step #{i + 1}"
      assert_includes [2, 4, 6, 8], s[4][2], "step #{i + 1}"
      assert_includes plan[:homes][s[0]].keys, s[1], "step #{i + 1}"
    end
    assert_equal [:push, [40, 37, 6, 4]], [plan[:steps][0][2], plan[:steps][0][4]]
  end

  private

  def clear_state
    plan = PokeAccess::RebornVrMineData::PLAN
    plan[:switches].each { |s| $game_switches[s] = false }
    plan[:vars].each { |v| $game_variables[v] = 0 }
  end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the plan says is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrh_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrh_kept_t)
    i18n.send(:remove_method, :rbrh_kept_t)
  end

  # The index of the plan's first step that the block accepts.
  def step_index(&block)
    PokeAccess::RebornVrMineData::PLAN[:steps].index(&block)
  end

  # Sets the switches and variables a step's state names.
  def apply_sig(sig)
    sig.split(",").each do |f|
      if f =~ /\AS(\d+)\z/ then $game_switches[$1.to_i] = true
      elsif f =~ /\AV(\d+)=(\d+)\z/ then $game_variables[$1.to_i] = $2.to_i
      end
    end
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    clear_state
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
    PokeAccess::Caches.reset_all
    PokeAccess::World::Mechanics.forget
    World.next_frame
  end

  def place(id, x, y, name, text = "text", sprite = "")
    page = TestPage.new(:trigger => 0, :sprite => sprite, :list => [TestCmd.new(101, [text]), TestCmd.new(0, [])])
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
