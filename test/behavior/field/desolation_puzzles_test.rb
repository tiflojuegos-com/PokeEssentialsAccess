# Pokemon Desolation's puzzles (games/desolation/puzzles/): Aderyn's totems, the levers and clues of Keneph, the pillars
# of Vejyr, the crystals of Silver Rise, the Black Fox Base, the Power Plant, the candy store, the Weeping Depths and the
# slabs of Redcliff's cave. Without the assist, what the screen shows; with it, the way.
class DesolationPuzzlesTest < PokeAccessTest
  SWITCHES = (235..253).to_a + [112, 113, 133, 151, 165, 172, 231, 233, 299, 303, 304, 384, 385, 388, 389, 396, 585, 781]
  VARS = [32, 33, 35, 45, 46, 78, 109, 125, 203, 210]

  def setup
    super
    keyed
    Harness.load_puzzles("desolation")
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
    PokeAccess::World::Mechanics.forget
    PokeAccess::DesolationCelesteGym.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "Aderyn's gym names its totems and, with the assist alone, says the next one of the nine touches" do
    on_map(24, 11, 51)
    $game_switches[248] = true
    totem = place(78, 4, 46, "EV078")
    frame
    assert_equal "{deso_celeste_totem_west_low}", PokeAccess::Puzzles.piece_name(totem)
    refute(frame.any? { |l| l.include?("deso_celeste_next") }, "no plan without the assist")
    PokeAccess::Config.puzzle_assist = true
    assert_includes frame, "{deso_celeste_next n=9 name={deso_celeste_totem_west_low}}"
    $game_switches[235] = true
    $game_switches[249] = true
    $game_self_switches[[24, 78, "A"]] = true
    $game_player.x = 4
    $game_player.y = 47
    assert_includes frame, "{deso_celeste_next n=8 name={deso_celeste_totem_west_mid}}"
  end

  test "the gym's plan follows the walls the player has set, and stops once Aderyn's room is open or the badge is won" do
    gym = PokeAccess::DesolationCelesteGym
    m = 1 << (248 - 235)
    room = 12
    [78, 79, 80, 80, 86, 86, 83, 85, 80].each_with_index do |id, i|
      gym.forget
      assert_equal [id, 9 - i], gym.plan(m, room)
      m = gym.touch(m, id)
      room = (gym::TOTEMS[id] || gym::SPECIAL[id])[0]
    end
    gym.forget
    assert_equal [nil, 0], gym.plan(m, room)
    assert_nil gym.touch(m, 85), "a special totem answers once"
    on_map(24, 14, 50)
    assert_equal 12, gym.room, "the tile east of the entry is the entry's room"
    assert_equal [78, 9], gym.plan(1 << (248 - 235), gym.room)
    on_map(24, 11, 51)
    $game_switches[253] = true
    PokeAccess::Config.puzzle_assist = true
    assert_nil gym.next_step
  end

  test "Keneph counts the clues about Kuiki with the assist alone" do
    on_map(91, 30, 18)
    $game_variables[32] = 2
    refute_includes info_key, "{deso_keneph_clues}"
    PokeAccess::Config.puzzle_assist = true
    assert_includes info_key, "{deso_keneph_clues}"
    assert_includes info_key, "2"
  end

  test "the pillars of Vejyr go by one name per pair" do
    on_map(118, 14, 27)
    left = place(3, 13, 26, "Pillar")
    place(4, 12, 26, "Pillar")
    frame
    assert_equal "{deso_vejyr_pillar}", PokeAccess::Puzzles.piece_name(left)
    assert_equal 1, listed.length
  end

  test "the hidden path of the Weeping Depths lists, with the assist alone, the tile that counts next" do
    on_map(20, 18, 23)
    (2..8).each { |id| place(id, *[[19, 24], [20, 24], [21, 24], [22, 24], [22, 23], [23, 23], [24, 23]][id - 2], "EV", 1) }
    frame
    assert_empty listed
    PokeAccess::Config.puzzle_assist = true
    $game_variables[45] = 5
    assert_equal [[23, 23, "{deso_depths_path_next}"]], listed
  end

  test "the slabs of Redcliff's cave say what their parchment shows, and the assist the next slab by the count" do
    on_map(101, 17, 18)
    cave = PokeAccess::DesolationRedcliffCave
    slab = place(4, 21, 14, "EV004")
    assert_equal "{deso_cave_parchment dir={deso_cave_dir_south_west}}", PokeAccess::Puzzles.label_of(cave.parchment(slab))
    $game_variables[35] = 8
    nw = place(7, 13, 14, "EV007")
    assert_equal "{deso_cave_parchment dir={deso_cave_dir_origin}}", PokeAccess::Puzzles.label_of(cave.parchment(nw))
    $game_variables[35] = 2
    assert_equal "{deso_cave_next name={deso_cave_slab_south_west}}", PokeAccess::Puzzles.label_of(cave.hint)
    $game_variables[35] = 9
    assert_equal "{deso_cave_next name={deso_cave_slab_middle}}", PokeAccess::Puzzles.label_of(cave.hint)
    middle = place(3, 17, 17, "EV003")
    assert_nil cave.parchment(middle), "the middle one opening the ways shows no parchment"
  end

  test "the Power Plant's next step follows the terminal, the plates' switch and where the player stands" do
    bv = PokeAccess::DesolationBlackview
    on_map(205, 30, 26)
    assert_equal :deso_plant_step_south_east, bv.plant_hint
    $game_player.x = 24
    $game_player.y = 28
    assert_equal :deso_plant_step_terminal, bv.plant_hint
    $game_switches[389] = true
    assert_equal :deso_plant_step_south_west_back, (($game_switches[388] = true) && bv.plant_hint)
    $game_switches[388] = false
    assert_equal :deso_plant_step_south_west_up, bv.plant_hint
    $game_player.y = 24
    assert_equal :deso_plant_step_north_bottom, bv.plant_hint
    $game_player.x = 26
    $game_player.y = 19
    assert_equal :deso_plant_step_north_west, bv.plant_hint
    $game_player.x = 22
    $game_switches[388] = true
    assert_equal :deso_plant_step_north_east, bv.plant_hint, "with 388 on, the east plate leads to the niche"
    $game_player.x = 10
    $game_player.y = 17
    assert_equal :deso_plant_step_north_east, bv.plant_hint, "the north round is not the niche"
    $game_player.x = 24
    $game_player.y = 17
    assert_equal :deso_plant_door, bv.plant_hint
  end

  test "the lever of Keneph says from the north that it does not move, and nothing from the south" do
    on_map(87, 15, 24)
    lever = place(45, 15, 25, "EV045")
    $game_player.direction = 2
    lines = frame { fire(lever) }
    assert_includes lines, "{deso_keneph_lever_stuck}"
    $game_player.direction = 8
    refute_includes frame { fire(lever) }, "{deso_keneph_lever_stuck}"
  end

  test "the runaway Skitty's next tile is listed with the assist alone, by the chase's count" do
    on_map(470, 20, 60)
    [[42, 16, 66], [45, 27, 47], [48, 54, 31], [51, 56, 45]].each { |id, x, y| place(id, x, y, "Runaway Babie", 1) }
    $game_variables[210] = 4
    frame
    scares = lambda { listed.select { |r| r[2] == "{deso_skitty_step}" } }
    assert_empty scares.call
    PokeAccess::Config.puzzle_assist = true
    assert_equal [[27, 47, "{deso_skitty_step}"]], scares.call
    $game_variables[210] = 6
    assert_equal [[56, 45, "{deso_skitty_step}"]], scares.call
  end

  test "Silver Rise's hint follows the bridges formed, and the Black Fox chair holds until the stairway is there" do
    rise = PokeAccess::DesolationSilverRise
    on_map(31, 40, 40)
    $game_switches[303] = true
    assert_equal :deso_silver_hint_peak, rise.hint
    $game_switches[304] = true
    assert_equal :deso_silver_hint_room, rise.hint
    $game_switches[299] = true
    assert_nil rise.hint
    on_map(287, 13, 6)
    $game_variables[125] = 9
    assert PokeAccess::Puzzles.active?
    $game_variables[125] = 10
    refute PokeAccess::Puzzles.active?
  end

  test "Silver Rise marks with the assist both crystals of the peak, in any order, and then the one of the way out" do
    rise = PokeAccess::DesolationSilverRise
    on_map(31, 40, 40)
    marked = lambda { [303, 304, 299].select { |s| rise.label(s) == :deso_silver_crystal_next } }
    assert_empty marked.call, "no mark without the assist"
    PokeAccess::Config.puzzle_assist = true
    assert_equal [303, 304], marked.call
    $game_switches[304] = true
    assert_equal [303], marked.call
    $game_switches[303] = true
    assert_equal [299], marked.call
    $game_switches[299] = true
    assert_empty marked.call
  end

  test "the Pyrulean Lab's hint follows the diaries, the chip and the terminal" do
    lab = PokeAccess::DesolationPyrulean
    on_map(355, 20, 20)
    [[3, :deso_lab_diaries_hint], [5, :deso_lab_chip_hint], [6, :deso_lab_terminal_hint],
     [7, :deso_lab_cabinet_hint]].each do |v, key|
      $game_variables[109] = v
      assert_equal key, lab.hint
    end
  end

  test "Insight names a shine for anyone and what it is with the assist, and the drawn diary only with the assist" do
    on_map(326, 9, 29)
    ins = PokeAccess::DesolationInsight
    diary = place(1, 9, 28, "EV001")
    assert_nil ins.label(diary)
    page = TestPage.new(:trigger => 0, :sprite => "sparkle", :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    shine = TestGameEvent.new(:id => 2, :x => 6, :y => 16, :name => "EV002", :pages => [page], :active_page => page)
    assert_equal :deso_insight_shine, ins.label(shine)
    PokeAccess::Config.puzzle_assist = true
    assert_equal :deso_insight_point, ins.label(diary)
    $game_self_switches[[326, 1, "A"]] = true
    refute ins.open?(326, diary)
  end

  test "a crystal of Visinite turns into a glowing fragment only once the quest shatters it, until it is taken" do
    arc = PokeAccess::DesolationArcanius
    on_map(470, 80, 34)
    $game_variables[203] = 7
    assert_equal :deso_visinite_crystal, arc.crystal(781)
    $game_variables[203] = 8
    assert_equal :deso_visinite_fragment, arc.crystal(781)
    $game_switches[781] = true
    assert_equal :deso_visinite_crystal, arc.crystal(781)
  end

  private

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzles say is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :deso_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :deso_kept_t)
    i18n.send(:remove_method, :deso_kept_t)
  end

  def fire(ev)
    PokeAccess::Puzzles::Auto.fired($game_system.map_interpreter, PokeAccess.ivar(ev, :@list), ev.id)
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
    PokeAccess::DesolationCelesteGym.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0)
    page = TestPage.new(:trigger => trigger, :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def frame
    SpeakCapture.clear
    yield if block_given?
    World.next_frame
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end

  def listed
    PokeAccess::Puzzles.category_targets.select { |tg| tg.is_a?(PokeAccess::Locator::SurfaceTarget) }
                       .map { |tg| [tg.x, tg.y, tg.name] }.sort_by { |r| [r[0], r[1]] }
  end
end
