# Sevii's Distortion World and the Altering Cave's lower floor on the shipped profile: the floating rock and the sideways
# waterfall of the first map, the floating island of the second, and the boulders that came down. What a sighted player
# sees goes without the assist; the answer, with it.
class SeviiPuzzles2Test < PokeAccessTest
  def dw
    PokeAccess::SeviiDistortion
  end

  test "the first map's hint gives the rock's tile while it walls the landing, then the waterfall" do
    on_map(274)
    rock = place(10, 53, 38, 549)
    $game_player.x = 56
    $game_player.y = 38
    assert_equal :sevii_dw_rock_hint, dw.first_hint
    rock.through = true
    assert_equal :sevii_dw_fall_hint, dw.first_hint
    rock.through = false
    $game_player.x = 52
    assert_equal :sevii_dw_fall_hint, dw.first_hint
  end

  test "the free camera names the sideways waterfall and its crest on the first map alone" do
    on_map(274)
    $game_map.set_terrain(3, 2, dw::FALL)
    $game_map.set_terrain(4, 2, dw::CREST)
    said = lambda { |x, y| PokeAccess::CameraText.parts(x, y) }
    fall = [PokeAccess::I18n.t(:sevii_dw_fall)]
    assert_equal [fall, fall, []], [said[3, 2], said[4, 2], said[5, 2]]
    on_map(587)
    assert_equal [], said[3, 2], "the second map"
  ensure
    $game_map.clear_grid
  end

  test "the waterfall is climbed facing right to the first tile past it, and slid down leftwards from its crest" do
    on_map(274)
    $game_map.load_grid(["##########", "##########", "#........#", "##########"])
    (3..5).each { |x| $game_map.set_terrain(x, 2, dw::FALL) }
    $game_map.set_terrain(6, 2, dw::CREST)
    up = dw.climb(2, 2, [1, 0, 6], 0)
    assert_equal [7, 2, 1], [up.x, up.y, up.presses]
    assert_equal({ :kind => :act, :face => 6, :x => 2, :y => 2 }, up.gate)
    assert_nil dw.climb(2, 2, [0, -1, 8], 0), "facing up"
    assert_equal [2, 2], dw.descent(6, 2, 4)
    assert_nil dw.descent(6, 2, 8), "arriving from below"
  ensure
    $game_map.clear_grid
  end

  test "the waterfall's climb counts on the first map alone" do
    on_map(274)
    moves = PokeAccess::Routes::Moves
    climb = moves.instance_variable_get(:@assist_sources).find { |r| r.owner && r.owner[:maps] == [dw::FIRST] }
    refute_nil climb
    assert moves.on_map?(climb.owner)
    on_map(275)
    refute moves.on_map?(climb.owner)
  end

  test "the island is named while it shows, and its phase says whether it rose or fell" do
    on_map(587)
    island = dw::ISLAND.map { |id| place(id, 8 + id, 3, 1160, 0) }
    refute dw.island_up?
    refute_includes listed, "{sevii_dw_island}"
    assert_equal :sevii_dw_island_down, phase_title
    island.each { |ev| ev.opacity = 255 }
    World.next_frame
    assert dw.island_up?
    assert_equal :sevii_dw_island_up, phase_title
    assert_includes listed, "{sevii_dw_island}"
    island.each { |ev| ev.through = true }
    assert_equal :sevii_dw_island_down, phase_title
  end

  test "the island's raising tile is listed with the assist alone, and only while the island is down" do
    on_map(587)
    island = dw::ISLAND.map { |id| place(id, 8 + id, 3, 1160, 0) }
    refute_includes listed, "{sevii_dw_island_tile}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes listed, "{sevii_dw_island_tile}"
    island.each { |ev| ev.opacity = 255 }
    refute_includes listed, "{sevii_dw_island_tile}"
  end

  test "the Altering Cave's lower hint waits for each boulder to come down, and reads EV11 by the southern hole as EV12 does" do
    on_map(256)
    cave = PokeAccess::SeviiAlteringCave
    $game_variables[53] = 0
    first = place(10, 22, 30, 0)
    second = place(11, 22, 30, 0)
    first.x = 5
    assert_equal :sevii_altering_none, cave.lower_hint
    $game_variables[53] = 2
    assert_equal [8, [23, 30], :left], cave.ready_press
    first.x = 21
    first.y = 25
    assert_nil cave.ready_press
    $game_variables[53] = 1
    second.x = 5
    first.x = 22
    first.y = 29
    assert_equal :sevii_altering_push, cave.lower_hint[0]
    $game_self_switches[[256, 8, "A"]] = true
    $game_self_switches[[256, 10, "A"]] = true
    assert_equal :sevii_altering_second, cave.lower_hint
  end

  def on_map(map)
    Harness.load_puzzles("sevii")
    PokeAccess::Config.puzzle_assist = false
    $game_map.map_id = map
    $game_switches[dw::DONE] = false
    $game_variables[53] = 0
    $game_self_switches = {}
    $game_player.x = 12
    $game_player.y = 6
    World.next_frame
  end

  def place(id, x, y, tile, opacity = 255)
    page = TestPage.new(:trigger => 0, :sprite => "", :list => [TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :pages => [page], :active_page => page)
    ev.tile_id = tile
    ev.instance_variable_set(:@opacity, opacity)
    def ev.opacity; @opacity; end
    def ev.opacity=(v); @opacity = v; end
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def phase_title
    spec = PokeAccess::World::Mechanics.instances.map { |inst| inst.spec }.find { |s| s[:phases] }
    live = spec[:phases].find { |s| PokeAccess::World::Mechanics.truth(s[:when]) }
    live && live[:title]
  end

  # The names in the puzzles category, each as "{key}" (I18n.t answering keys for the while), so they compare by key.
  def listed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :sevii_kept_t, :t)
    i18n.send(:define_method, :t) { |key, _vars = nil| "{#{key}}" }
    PokeAccess::Puzzles.category_targets.map { |tg| tg.name }
  ensure
    i18n.send(:alias_method, :t, :sevii_kept_t)
    i18n.send(:remove_method, :sevii_kept_t)
  end
end
