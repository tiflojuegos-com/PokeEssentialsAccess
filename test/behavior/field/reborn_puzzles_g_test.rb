# Pokemon Reborn's puzzles of part G (games/reborn/puzzles/): the plan of Victory Road's second mine with the assist, and
# Labradorra's foes said as they come into view and reach the chest.
class RebornPuzzlesGTest < PokeAccessTest
  SWITCHES = [1098, 1157, 1159, 1160, 1161, 1163, 1166]
  VARS = [478, 501, 503, 504]

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
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
    $game_self_switches = @selfs
    $game_player.x, $game_player.y = @at
    $game_map.map_id = @map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::RebornLabradorraFoes.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "The second mine's plan starts at the first cart from the trap, and only with the assist" do
    on_map(790, 21, 64)
    $game_switches[1157] = true
    place(28, 62, 46, "Cart1", "minecart9")
    World.next_frame
    plans = PokeAccess::RebornVrCartPlans
    assert_equal [:cart, 28, nil, 0], plans.target
    refute_includes info_key, "rbg_plan_step"
    refute(listed.any? { |t| t[0] == 62 && t[1] == 46 })
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{rbg_plan_step n=1 total=26 what={rbg_plan_cart name={rbc2_cart}} where=41 {dir_right}, 18 {dir_up}}"
    assert_includes listed, [62, 46, "{rbg_plan_cart name={rbc2_cart}}"]
  end

  test "The plan's boulder step says how far the boulder still goes to its plate" do
    on_map(790, 26, 46)
    $game_switches[1157] = true
    $game_variables[501] = 1
    place(31, 24, 51, "Boulder", "text", "rockstrength2")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:boulder, 31, [28, 55], 1], PokeAccess::RebornVrCartPlans.target
    assert_includes listed, [24, 51, "{rbg_plan_boulder where=4 {dir_right}, 4 {dir_down}}"]
    $game_switches[1159] = true
    place(35, 52, 38, "EV035")
    assert_equal [:use, 35, nil, 2], PokeAccess::RebornVrCartPlans.target
    assert_includes listed, [52, 38, "{rbg_plan_lever}"]
  end

  test "Off the plan the lever that brings it back is named, and nothing once the wall has blown" do
    on_map(790, 26, 46)
    $game_switches[1157] = true
    $game_variables[501] = 1
    $game_switches[1160] = true
    place(33, 57, 41, "EV033")
    PokeAccess::Config.puzzle_assist = true
    plans = PokeAccess::RebornVrCartPlans
    assert_nil plans.step
    assert_equal [:back, 33, nil, nil], plans.target
    assert_includes info_key, "{rbg_plan_off what={rbg_plan_back} where=31 {dir_right}, 5 {dir_up}}"
    $game_switches[1166] = true
    assert_nil plans.target
    refute_includes info_key, "rbg_plan"
  end

  test "A plan step names the loose rocks by what to choose there" do
    on_map(790, 36, 31)
    [1157, 1159, 1161, 1163].each { |s| $game_switches[s] = true }
    $game_variables[503] = 1
    $game_variables[504] = 1
    place(44, 36, 30, "EV044")
    PokeAccess::Config.puzzle_assist = true
    assert_equal [:use, 44, nil, 7], PokeAccess::RebornVrCartPlans.target
    assert_includes listed, [36, 30, "{rbg_plan_rocks}"]
  end

  test "Each foe sent off in Labradorra is said once as it comes into view and once as it nears the chest" do
    foes = PokeAccess::RebornLabradorraFoes
    on_map(779, 26, 48)
    $game_variables[478] = 4
    knight = place(88, 30, 45, "4-KnightA", "text", "trchar148")
    blaziken = place(78, 25, 70, "5-Blaziken", "text", "pkmn_blaziken")
    assert_equal ["{rbg_foe_comes name={rbc2_labradorra_knight} where=4 {dir_right}, 3 {dir_up}}"], spoken { foes.tick }
    blaziken.y = 54
    assert_empty spoken { foes.tick }
    $game_variables[478] = 5
    blaziken.y = 70
    assert_empty spoken { foes.tick }
    blaziken.y = 55
    assert_empty spoken { foes.tick }
    blaziken.y = 54
    assert_equal ["{rbg_foe_comes name=Blaziken where=1 {dir_left}, 6 {dir_down}}"], spoken { foes.tick }
    blaziken.y = 50
    assert_empty spoken { foes.tick }
    blaziken.y = 45
    assert_equal ["{rbg_foe_near_chest name=Blaziken}"], spoken { foes.tick }
    blaziken.y = 44
    assert_empty spoken { foes.tick }
    blaziken.y = 46
    assert_empty spoken { foes.tick }
    knight.x = 28
    knight.y = 44
    assert_equal ["{rbg_foe_near_chest name={rbc2_labradorra_knight}}"], spoken { foes.tick }
    $game_player.y = 36
    $game_variables[478] = 6
    ambipom = place(87, 26, 37, "6-AmbipomB", "text", "pkmn_ambipom")
    assert_equal ["{rbg_foe_comes name=Ambipom where=1 {dir_down}}"], spoken { foes.tick }
    ambipom.y = 40
    assert_empty spoken { foes.tick }
    $game_variables[478] = 0
    foes.tick
    $game_variables[478] = 6
    ambipom.y = 37
    assert_equal ["{rbg_foe_comes name=Ambipom where=1 {dir_down}}"], spoken { foes.tick }
    $game_switches[1098] = true
    $game_variables[478] = 7
    ambipom.y = 38
    $game_player.y = 48
    assert_empty spoken { foes.tick }
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbg_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbg_kept_t)
    i18n.send(:remove_method, :rbg_kept_t)
  end

  def on_map(map, x, y)
    PokeAccess::Config.puzzle_assist = false
    World.clear_events
    $game_self_switches = {}
    SWITCHES.each { |s| $game_switches[s] = false }
    VARS.each { |v| $game_variables[v] = 0 }
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

  def spoken
    SpeakCapture.clear
    yield
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }
  end
end
