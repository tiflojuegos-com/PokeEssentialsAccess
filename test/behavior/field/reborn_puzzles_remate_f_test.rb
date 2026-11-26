# Pokemon Reborn's Citae Prisma mirror room (games/reborn/puzzles/citae_prisma.rb): what each light did, the room's
# pieces by what they show and, with the assist, the step of the plan worked out off the game.
class RebornPuzzlesRemateFTest < PokeAccessTest
  SWITCHES = [1882, 1883, 1884, 1885, 1886, 1887, 1888, 1889, 1890, 1891, 1892, 1893, 1895, 1897, 1898, 1899, 1900, 1902]
  VARS = [725, 731, 732, 737, 738]

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
    pr.forget
    PokeAccess::World::Mechanics.forget
    PokeAccess::Caches.reset_all
    unkeyed
    super
  end

  test "every leg's pushes are taken from the side opposite the way, one tile at a time, onto free floor" do
    pr::LEGS.each do |goal, legs|
      legs.each do |start, pushes|
        states = pr.replay(start, pushes)
        pushes.each_with_index do |(id, x, y, way, sx, sy), i|
          dx, dy = pr::STEPS[way]
          assert_equal [x, y], states[i][id], "#{goal} push #{i}"
          assert_equal [x - dx, y - dy], [sx, sy], "#{goal} stand #{i}"
          assert pr.in_room?(x + dx, y + dy), "#{goal} push #{i} leaves the room"
          others = states[i].reject { |k, _p| k == id || k == :facing }.values
          refute_includes others, [x + dx, y + dy], "#{goal} push #{i} runs into another piece"
          refute_includes others, [sx, sy], "#{goal} push #{i} stands on another piece"
        end
      end
    end
  end

  test "the legs end where the lights were found to light their crystals" do
    ends = pr::LEGS.map { |goal, legs| [goal, legs.map { |s, p| pr.replay(s, p).last }] }
    ends = Hash[ends]
    assert_equal [22, 60], ends[:a_blue][0][75]
    ends[:b_save].each { |e| assert_equal [[18, 66], [17, 66]], [e[75], e[74]] }
    ends[:b_purple].each { |e| assert_equal [27, 64], e[75] }
    pr::JUMPS.each do |leg, jump|
      ends[leg].each { |e| assert_equal [[22, 61], jump[:at]], [e[75], e[74]], leg.to_s }
    end
    assert_equal [:b_fire, :b_fire2], pr::JUMPS.keys.sort_by { |k| k.to_s }
    ends[:c_red].each { |e| assert_equal [27, 64], e[73] }
    ends[:c_red_green].each { |e| assert_equal [[17, 64], [18, 61], [27, 64]], [e[74], e[75], e[73]] }
    ends[:d_final].each do |e|
      assert_equal [[22, 60], [18, 64], [27, 64], [19, 63], [25, 61]], [e[75], e[72], e[73], e[95], e[74]]
      assert_equal 2, e[:facing]
    end
  end

  test "the first leg takes the mirror to the top row, then the dark, the prism, the blue crystal and the orb" do
    on_map(896, 22, 69)
    $game_variables[725] = 5
    mirror = place(75, 20, 61, "MirrorB1", 0, "mirrorpanel")
    assert_equal "{rbrf_push_mirror dir={rbrf_way_right} left=3 sx=19 sy=61 x=20 y=61}", pr.hint
    mirror.x = 22
    assert_equal "{rbrf_push_mirror dir={rbrf_way_up} left=1 sx=22 sy=62 x=22 y=61}", pr.hint
    PokeAccess::Config.puzzle_assist = true
    assert_equal [22, 62], pr.stand
    mirror.y = 60
    assert_equal "{rbrf_hint_dark}", pr.hint
    $game_switches[1900] = true
    assert_equal "{rbrf_hint_fire}", pr.hint
    $game_switches[1887] = true
    assert_equal "{rbrf_hint_use_blue}", pr.hint
    $game_switches[1891] = true
    assert_equal "{rbrf_hint_orb_north}", pr.hint
    mirror.x = 24
    $game_switches[1891] = $game_switches[1887] = false
    assert_equal "{rbrf_hint_off_plan}", pr.hint
  end

  test "the green crystal goes through Luna's outlines and the purple crystal used in flight" do
    on_map(896, 22, 69)
    $game_variables[725] = 5
    [1897, 1900].each { |s| $game_switches[s] = true }
    first = place(75, 20, 61, "MirrorB1", 0, "mirrorpanel")
    second = place(74, 25, 61, "MirrorB4", 0, "mirrorpanel")
    assert_equal "{rbrf_push_mirror dir={rbrf_way_down} left=10 sx=20 sy=60 x=20 y=61}", pr.hint
    $game_switches[1890] = true
    assert_equal "{rbrf_push_mirror dir={rbrf_way_down} left=20 sx=20 sy=60 x=20 y=61}", pr.hint
    first.x, first.y = 18, 66
    second.x, second.y = 17, 66
    assert_equal "{rbrf_hint_save}", pr.hint
    $game_variables[731], $game_variables[732], $game_variables[737], $game_variables[738] = 18, 66, 17, 66
    assert_equal "{rbrf_push_mirror dir={rbrf_way_up} left=11 sx=18 sy=67 x=18 y=66}", pr.hint
    first.x, first.y = 22, 61
    second.x, second.y = 19, 66
    assert_equal "{rbrf_hint_fire_jump}", pr.hint
    PokeAccess::Config.puzzle_assist = true
    assert_equal pr::FIRE_SPOT, pr.stand
    $game_switches[1882] = true
    assert_equal "{rbrf_hint_jump_now}", pr.hint
    assert_equal pr::JUMP_SPOT, pr.stand
    $game_switches[1882] = $game_switches[1890] = false
    $game_switches[1888] = true
    assert_equal "{rbrf_hint_use_green}", pr.hint
    $game_switches[1888] = false
    $game_switches[1892] = true
    [80, 96, 97, 98, 107, 108, 109].each { |id| place(id, 30, 30 + id % 20, "Rock", 0) }
    assert_equal "{rbrf_hint_smash list=30, 30; 30, 37; 30, 38; 30, 39}", pr.hint
  end

  test "once the room's rocks break, a second jump lights blue and green in one firing for the east rock's bridge" do
    on_map(896, 22, 69)
    $game_variables[725] = 5
    [1897, 1900].each { |s| $game_switches[s] = true }
    $game_variables[731], $game_variables[732], $game_variables[737], $game_variables[738] = 18, 66, 17, 66
    pr::BOX_ROCKS.each { |id| $game_self_switches[[896, id, "A"]] = true }
    first = place(75, 18, 66, "MirrorB1", 0, "mirrorpanel")
    second = place(74, 17, 66, "MirrorB4", 0, "mirrorpanel")
    east = place(96, 39, 64, "Rock", 0)
    place(97, 40, 65, "Rock", 0)
    place(98, 7, 64, "Rock", 0)
    assert_equal "{rbrf_push_mirror dir={rbrf_way_up} left=13 sx=18 sy=67 x=18 y=66}", pr.hint
    first.x, first.y = 27, 64
    $game_switches[1890] = true
    assert_equal "{rbrf_push_mirror dir={rbrf_way_left} left=11 sx=28 sy=64 x=27 y=64}", pr.hint
    first.x, first.y = 22, 61
    second.x, second.y = 18, 64
    assert_equal "{rbrf_hint_fire_jump_cue}", pr.hint
    PokeAccess::Config.puzzle_assist = true
    assert_equal pr::FIRE_SPOT, pr.stand
    $game_switches[1882] = true
    assert_equal "{rbrf_hint_jump_wait_cue}", pr.hint
    assert_equal pr::JUMP_SPOT, pr.stand
    $game_switches[1882] = $game_switches[1890] = false
    first.x, first.y = 18, 66
    second.x, second.y = 17, 66
    $game_switches[1887] = $game_switches[1888] = true
    assert_equal "{rbrf_hint_use_blue}", pr.hint
    $game_switches[1887] = false
    $game_switches[1891] = true
    assert_equal "{rbrf_hint_use_green}", pr.hint
    $game_switches[1888] = false
    $game_switches[1892] = true
    assert_equal "{rbrf_hint_smash_east}", pr.hint
    east.x, east.y = 49, 84
    assert_equal "{rbrf_hint_orb_east}", pr.hint
  end

  test "the second jump is called by the left light turning up, once a firing, and a missed jump fires again" do
    on_map(896, 22, 69)
    $game_variables[725] = 5
    [1897, 1900, 1890].each { |s| $game_switches[s] = true }
    pr::BOX_ROCKS.each { |id| $game_self_switches[[896, id, "A"]] = true }
    place(75, 22, 61, "MirrorB1", 0, "mirrorpanel")
    place(74, 18, 64, "MirrorB4", 0, "mirrorpanel")
    place(96, 39, 64, "Rock", 0)
    lights = {}
    { 69 => [22, 64, 8], 67 => [22, 64, 4], 66 => [23, 64, 2], 68 => [23, 64, 6] }.each do |id, (x, y, d)|
      lights[id] = place(id, x, y, "li", 0, "light6")
      lights[id].direction = d
    end
    PokeAccess::Config.puzzle_assist = true
    $game_switches[1882] = true
    pr.poll
    lights[67].x = 18
    SpeakCapture.clear
    pr.poll
    refute_includes SpeakCapture.lines.join(" "), "rbrf_hint_jump_cue"
    lights[67].y = 63
    lights[67].direction = 8
    pr.poll
    pr.poll
    assert_equal 1, SpeakCapture.lines.count { |l| l.include?("{rbrf_hint_jump_cue}") }
    lights[67].y = 60
    [1883, 1884, 1885, 1886, 1887].each { |s| $game_switches[s] = true }
    $game_switches[1882] = false
    pr.poll
    refute_equal "{rbrf_hint_fire_jump_cue}", pr.hint, "the jump would take the mirrors back to spots Luna never saw"
    $game_variables[731], $game_variables[732], $game_variables[737], $game_variables[738] = 18, 66, 17, 66
    assert_equal "{rbrf_hint_fire_jump_cue}", pr.hint, "Luna's spots kept from the first jump"
  end

  test "with the red and the green lit for the west, the red goes first, as the west rock is faced past a red rock" do
    on_map(896, 22, 69)
    $game_variables[725] = 5
    [1897, 1898, 1900].each { |s| $game_switches[s] = true }
    pr::BOX_ROCKS.each { |id| $game_self_switches[[896, id, "A"]] = true }
    { 75 => [18, 61], 74 => [17, 64], 73 => [27, 64] }.each { |id, (x, y)| place(id, x, y, "Mirror", 0, "mirrorpanel") }
    place(98, 7, 64, "Rock", 0)
    $game_switches[1889] = $game_switches[1888] = true
    assert_equal "{rbrf_hint_use_red}", pr.hint
    $game_switches[1889] = false
    $game_switches[1893] = true
    assert_equal "{rbrf_hint_use_green}", pr.hint
    $game_switches[1888] = false
    $game_switches[1892] = true
    assert_equal "{rbrf_hint_smash list=7, 64}", pr.hint
  end

  test "Serra's stage asks for the red rocks back, her, and then the last leg with her as a mirror" do
    on_map(896, 22, 69)
    [1897, 1898, 1899, 1893, 1890, 1900].each { |s| $game_switches[s] = true }
    $game_variables[725] = 5
    { 75 => [20, 61], 74 => [25, 61], 73 => [26, 66], 95 => [19, 63] }.each { |id, (x, y)| place(id, x, y, "Mirror", 0, "mirrorpanel") }
    serra = place(72, 19, 64, "EV072", 0, "trchar096")
    assert_equal "{rbrf_hint_leave}", pr.hint
    $game_switches[1893] = false
    assert_equal "{rbrf_hint_serra}", pr.hint
    $game_variables[725] = 6
    assert_equal "{rbrf_hint_fire}. {rbrf_hint_keep_purple}", pr.hint
    $game_variables[725] = 8
    assert_equal "{rbrf_push_mirror dir={rbrf_way_right} left=9 sx=19 sy=61 x=20 y=61}", pr.hint
    assert_equal "{rbrf_serra dir={rbrf_way_down}}", PokeAccess::Puzzles.label_of(pr.serra_label(serra))
    PokeAccess::World::Mechanics.forget
    serra.direction = 8
    assert_equal "{rbrf_serra dir={rbrf_way_up}}", PokeAccess::Puzzles.label_of(pr.serra_label(serra))
  end

  test "each light is told as it dies out, where it turned and what it lit" do
    on_map(896, 22, 69)
    [1897, 1900].each { |s| $game_switches[s] = true }
    place(75, 22, 60, "MirrorB1", 0, "mirrorpanel")
    place(74, 25, 61, "MirrorB4", 0, "mirrorpanel")
    lights = {}
    { 69 => [22, 64, 8], 67 => [22, 64, 4], 66 => [23, 64, 2], 68 => [23, 64, 6] }.each do |id, (x, y, d)|
      lights[id] = place(id, x, y, "li", 0, "light6")
      lights[id].direction = d
    end
    $game_switches[1882] = true
    pr.poll
    lights[69].x, lights[69].y = 21, 60
    lights[69].direction = 4
    pr.poll
    lights[69].x = 18
    $game_switches[1887] = $game_switches[1886] = true
    lights[67].x = 21
    lights[66].y = 65
    lights[68].x = 29
    [1883, 1884, 1885].each { |s| $game_switches[s] = true }
    pr.poll
    SpeakCapture.clear
    $game_switches[1882] = false
    pr.poll
    said = SpeakCapture.lines.join(" ")
    assert_includes said, "{rbrf_beam light={rbrf_light_8} path={rbrf_path end={rbrf_end_lit color={rbrf_color_blue}} " \
                          "turns={rbrf_turn dir={rbrf_way_left} x=22 y=60}}}"
    assert_includes said, "{rbrf_beam light={rbrf_light_4} path={rbrf_end_hit x=21 y=64}}"
    assert_includes said, "{rbrf_beam light={rbrf_light_2} path={rbrf_end_hit x=23 y=65}}"
    assert_includes said, "{rbrf_beam light={rbrf_light_6} path={rbrf_end_out x=29 y=64}}"
    assert_includes said, "{rbrf_lit_list list={rbrf_color_blue}}"
    refute_includes said, "rbrf_push"
  end

  test "the mirrors, the crystals and the broken mirror are named by what they show" do
    on_map(896, 22, 69)
    $game_switches[1897] = true
    mirror = place(75, 20, 61, "MirrorB1", 0, "mirrorpanel")
    stored = place(74, 0, 1, "MirrorB4", 0, "mirrorpanel")
    crystal = place(76, 18, 60, "EV076", 0)
    assert_equal "{rbrf_mirror face={rbrf_face_sw}}", PokeAccess::Puzzles.label_of(pr.mirror_label(mirror))
    assert_nil pr.mirror_label(stored)
    assert_equal "{rbrf_crystal color={rbrf_color_blue} state={rbrf_unlit}}", PokeAccess::Puzzles.label_of(pr.crystal_label(crystal))
    $game_switches[1887] = true
    assert_equal "{rbrf_crystal color={rbrf_color_blue} state={rbrf_lit}}", PokeAccess::Puzzles.label_of(pr.crystal_label(crystal))
    assert_includes info_key, "{rbrf_lit_list list={rbrf_color_blue}}"
    assert_includes info_key, "{rbrf_bright}"
  end

  private

  def pr; PokeAccess::RebornPrisma; end

  # Makes I18n.t answer each key and its values as "{key name=value ...}", so what the puzzle says is compared by its
  # keys and values rather than by the text of a language.
  def keyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :rbrf_kept_t, :t)
    i18n.send(:define_method, :t) do |key, vars = nil|
      parts = [key.to_s] + (vars || {}).map { |k, v| "#{k}=#{v}" }.sort
      "{#{parts.join(' ')}}"
    end
  end

  # Gives I18n.t back its own body.
  def unkeyed
    i18n = PokeAccess::I18n.singleton_class
    i18n.send(:alias_method, :t, :rbrf_kept_t)
    i18n.send(:remove_method, :rbrf_kept_t)
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
    pr.forget
    World.next_frame
  end

  def place(id, x, y, name, trigger = 0, sprite = "")
    page = TestPage.new(:trigger => trigger, :sprite => sprite,
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => name, :pages => [page], :active_page => page)
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  def info_key
    PokeAccess::Info.map_text.to_s
  end
end
