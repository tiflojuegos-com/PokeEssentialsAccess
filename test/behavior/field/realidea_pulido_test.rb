# The optional and once unconfirmed puzzles of Realidea (games/realidea/puzzles/*): what each says by itself and, apart,
# with the puzzle assist, on events laid out as the maps of the game lay them.
class RealideaPulidoTest < PokeAccessTest
  Route = Struct.new(:list)
  TEMPLATES = {
    "rea_desert_sand.one" => "sand %{n}", "rea_desert_sand.other" => "sand %{n}", "rea_desert_hint.one" => "next %{n}",
    "rea_desert_hint.other" => "next %{n}", "rea_library_section" => "section %{section}", "rea_library_book" => "book %{title}",
    "rea_mine_cart" => "cart %{where}", "rea_mine_lever" => "lever %{n}", "rea_farm_hint" => "exit %{way}",
    "rea_snow_watcher" => "watcher %{dir}", "rea_farm_flowers_red.other" => "red %{n}",
    "rea_daruma_push.one" => "push %{where} %{dir} %{n}", "rea_daruma_push.other" => "push %{where} %{dir} %{n}"
  }
  SWITCHES = [79, 82, 80, 318, 355, 501, 146, 313, 195, 196, 131, 388, 465, 316, 444]
  # A room two rows deep, the player at its top left: four presses along the top row to (5,1), six round the second.
  ROOM = ["#######",
          "#@....#",
          "#.....#",
          "#######"]
  STRAIGHT = [6, 6, 6, 6]
  ROUND = [2, 6, 6, 6, 6, 8]
  VARIABLES = [37, 38, 41, 44, 117, 120, 173]

  def setup
    super
    Harness.load_puzzles("realidea")
  end

  def teardown
    @floor_methods.each { |m| $game_map.singleton_class.send(:remove_method, m) } if @floor_methods
    @floor_methods = nil
    World.clear_events
    PokeAccess::World::Mechanics.forget
    PokeAccess::Config.puzzle_assist = false
    SWITCHES.each { |i| $game_switches[i] = false }
    VARIABLES.each { |i| $game_variables[i] = 0 }
    $game_self_switches = @was_selfs if @was_selfs
    $game_map.map_id = @was_map if @was_map
    super
  end

  test "the Purrloin's twigs are named, and the assist tells the quiet pile and then the side to speak from" do
    on_map(8)
    $game_switches[82] = true
    quiet = place(13, 28, 6)
    loud = place(2, 35, 14)
    cat = place(1, 42, 14)
    assert_equal t(:rea_purrloin_twigs), name_of(quiet)
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:rea_purrloin_twigs_quiet), name_of(quiet)
    assert_equal t(:rea_purrloin_twigs), name_of(loud)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_purrloin_hint_twigs)
    $game_switches[79] = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_purrloin_from_left)
    cat.x = 32
    cat.y = 7
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_purrloin_hint_catch)
  end

  test "the second floor of Metis Labs says its doors as they open, and the third names its spinning tiles" do
    on_map(133)
    assert_equal t(:rea_metis_button_open), name_of(place(30, 30, 12))
    assert_equal t(:rea_metis_button_shut), name_of(place(37, 22, 12))
    frame
    said = frame { $game_switches[318] = true }
    assert_equal 1, said.length
    assert said[0].start_with?("#{t(:rea_metis_doors)}: #{t(:rea_metis_doors_open)}"), said[0]
    on_map(56)
    assert_equal t(:rea_metis_spin_trap), name_of(place(4, 14, 49))
  end

  test "Lionel's world counts its crystals and says, on the info key, which way each key faces a turned character" do
    on_map(268)
    assert_equal t(:rea_lionel_crystal), name_of(place(12, 41, 11))
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_lionel_turned_left)
    $game_switches[355] = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_lionel_turned_left)
    found = t(:puzzle_progress, :label => t(:rea_lionel_crystals), :n => 0, :of => 4)
    refute_includes PokeAccess::Puzzles.info_line, found, "the game never tells how many crystals there are"
    $game_switches[355] = false
    $game_switches[501] = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_lionel_turned_right)
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_lionel_hint)
    assert_includes PokeAccess::Puzzles.info_line, found
  end

  test "the floor of the Jade gym that gives a status, and the trap floor of the first ruins, are told apart by terrain" do
    lay_tags([[3, 4]] => 29, [[5, 5]] => 25)
    on_map(114)
    assert PokeAccess::RealideaJadeFloor.wrong?(3, 4)
    refute PokeAccess::RealideaJadeFloor.wrong?(5, 5)
    refute PokeAccess::RealideaIsland.trap?(5, 5)
    on_map(150)
    assert PokeAccess::RealideaIsland.trap?(5, 5)
    refute PokeAccess::RealideaIsland.trap?(3, 4)
  end

  test "the Jade gym's floor says its colour and the first ruins' slabs their engraving, and the assist what they do" do
    lay_tags({ [[3, 4]] => 29, [[5, 5]] => 25 },
             [3, 4, 0] => 847, [4, 4, 0] => 854, [5, 5, 1] => 500, [6, 5, 1] => 501, [7, 5, 1] => 494)
    jade = [[3, 4], [4, 4], [5, 5]]
    ruins = [[5, 5], [6, 5], [7, 5], [3, 4]]
    got = labels_alone do |seen|
      [[114, jade], [150, ruins]].map do |map, tiles|
        on_map(map)
        without = seen.call(tiles)
        PokeAccess::Config.puzzle_assist = true
        [without, seen.call(tiles)]
      end.flatten(1)
    end
    assert_equal [[:rea_jade_yellow_tile, :rea_jade_white_tile, nil], [:rea_jade_wrong_tile, :rea_jade_white_tile, nil],
                  [:rea_island_triangle_slab, :rea_island_circle_slab, :rea_island_square_slab, nil],
                  [:rea_island_trap_tile, :rea_island_circle_slab, :rea_island_square_slab, nil]], got
  end

  test "routes cross the Jade gym's wrong floor and the first ruins' arrow tiles as seen, and with the assist go round" do
    got = [[114, 29], [150, 25], [114, 25]].map { |map, tag| routes_over(map, tag) }
    assert_equal [[STRAIGHT, ROUND], [STRAIGHT, ROUND], [STRAIGHT, STRAIGHT]], got
  end

  test "Mesprit's gusts hidden by the sandstorm are unseen by the walks without the assist, and a drawn gust is read" do
    Harness.load_puzzles("realidea")
    on_map(184)
    throw = [TestCmd.new(209, [-1, Route.new([TestCmd.new(14, [0, -6])])]), TestCmd.new(0, [])]
    hidden = gust(2, 23, 77, "", throw)
    drawn = gust(34, 35, 11, "soplito", throw)
    fx = PokeAccess::Routes::Effects
    seen = [false, true].map do |assist|
      PokeAccess::Config.puzzle_assist = assist
      [fx.sourced_effect(hidden), fx.sourced_effect(drawn)]
    end
    assert_equal [[:unseen, nil], [nil, nil]], seen
    walked = [false, true].map do |assist|
      PokeAccess::Config.set(:puzzle_assist, assist)
      World.next_frame
      fx.touch_at(23, 77, 8, true).nil?
    end
    assert_equal [true, false], walked, "the walks meet the hidden gust as plain ground without the assist, and ride it with it"
    PokeAccess::Config.set(:puzzle_assist, false)
    $game_map.map_id = 185
    PokeAccess::Config.puzzle_assist = false
    assert_nil fx.sourced_effect(hidden), "another map's events are their own"
  end

  test "the Amberino gym names the three sands that lead to a Flygon only with the assist" do
    on_map(252)
    sand = place(3, 7, 10)
    refute_equal t(:rea_amberino_flygon_sand), name_of(sand)
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:rea_amberino_flygon_sand), name_of(sand)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_amberino_hint)
    $game_variables[117] = 3
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the library says the section of the shelf faced and names the books, and the assist counts those in place" do
    lay_tags([[11, 42], [12, 42], [22, 42], [7, 37], [8, 37], [13, 32]] => 37)
    on_map(273)
    assert_equal "2C", PokeAccess::RealideaLibrary.section(11, 42)
    assert_equal "2F", PokeAccess::RealideaLibrary.section(22, 42)
    assert_equal "3A", PokeAccess::RealideaLibrary.section(8, 37)
    assert_equal "4D", PokeAccess::RealideaLibrary.section(13, 32)
    assert_nil PokeAccess::RealideaLibrary.section(30, 42)
    book = place(2, 30, 42)
    assert_nil PokeAccess::RealideaLibrary.book(book)
    book.x = 11
    assert_equal t(:rea_library_book, :title => PokeAccess::Data.item_name(:LIBRO1).to_s), name_of(book)
    step(12, 43)
    $game_player.direction = 8
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_library_section, :section => "2C")
    assert_equal 1, PokeAccess::RealideaLibrary.placed
    assert_includes PokeAccess::Camera.tile_lines(11, 42), t(:rea_library_section, :section => "2C")
    $game_map.map_id = 274
    refute_includes PokeAccess::Camera.tile_lines(11, 42), t(:rea_library_section, :section => "2C")
  end

  test "the desert names each quicksand by the rocks around it, and the assist the one to take next" do
    on_map(139)
    assert_equal t(:rea_desert_sand, :n => 3), name_of(place(48, 6, 47))
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_desert_hint, :n => 1)
    $game_variables[120] = 3
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_desert_hint, :n => 4)
    $game_switches[465] = true
    assert_nil PokeAccess::Puzzles.info_line, "once at the oasis the desert says no more"
  end

  test "the spikes of the Temple of Azelf are named up or down, and the info key says the row beside the player" do
    on_map(186)
    spike = place(1, 7, 56)
    assert_equal t(:rea_azelf_spikes_down), name_of(spike)
    $game_switches[195] = true
    assert_equal t(:rea_azelf_spikes_up), name_of(spike)
    step(7, 58)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_azelf_near_up)
    step(20, 60)
    refute_includes PokeAccess::Puzzles.info_line.to_s, t(:rea_azelf_near_up)
  end

  test "the talisman of the Snow Field is said as its picture turns, once a turn" do
    on_map(129)
    SpeakCapture.clear
    PokeAccess::RealideaSnow.forget
    PokeAccess::RealideaSnow.on_picture("/talisman/izquierda/frame_2_delay-0.08s")
    PokeAccess::RealideaSnow.on_picture("/talisman/izquierda/frame_3_delay-0.08s")
    PokeAccess::RealideaSnow.on_picture("amuleto1")
    assert_equal [t(:rea_snow_left), t(:rea_snow_ahead)], SpeakCapture.lines
    assert_equal t(:rea_snow_watcher, :dir => t(:dir_left)), name_of(place(8, 37, 39, :direction => 4))
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_snow_hint)
    $game_switches[316] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the Snow Field's watchers see four tiles ahead through what stands there, said by the free camera" do
    on_map(129)
    page = TestPage.new(:trigger => 2, :sprite => "Shota", :direction => 2, :through => true,
                        :list => [TestCmd.new(122, [69, 69, 1, 0, 1]), TestCmd.new(0, [])])
    watcher = TestGameEvent.new(:id => 8, :x => 10, :y => 5, :name => "Trainer(4)", :pages => [page])
    watcher.through = true
    $game_map.events[8] = watcher
    World.next_frame
    sight = PokeAccess::Routes::Sight
    assert_equal [true, true, false], [sight.seen?(10, 6), sight.seen?(10, 9), sight.seen?(10, 10)]
    assert_includes PokeAccess::Camera.tile_lines(10, 7), t(:sight_in_view, :name => PokeAccess::Locator.target_name(watcher))
    $game_map.map_id = 130
    World.next_frame
    refute sight.seen?(10, 6), "on another map"
  end

  test "the mine names a cart by where its rails lead and a lever by its position" do
    on_map(34)
    cart = place(8, 12, 68)
    where = PokeAccess::Puzzles.offset_phrase(36, 1)
    assert_equal t(:rea_mine_cart, :where => where), name_of(cart)
    $game_variables[38] = 2
    assert_equal t(:rea_mine_cart_still), name_of(cart)
    $game_variables[38] = 0
    $game_variables[37] = 1
    assert_equal t(:rea_mine_cart, :where => PokeAccess::Puzzles.offset_phrase(14, -16)), name_of(cart)
    assert_equal t(:rea_mine_lever, :n => 2), name_of(place(4, 16, 62))
    refute PokeAccess::Puzzles.hidden_event?(cart)
    waiting = place(14, 48, 69)
    waiting.define_singleton_method(:opacity) { 0 }
    assert PokeAccess::Puzzles.hidden_event?(waiting), "a see-through cart is left out of the lists"
  end

  test "the farm maze says its clock's flowers by itself and gives its right exit only with the assist" do
    on_map(37)
    exit_ev = place(4, 2, 11)
    assert_equal t(:rea_farm_flowers_red, :n => 9), PokeAccess::Puzzles.info_line
    refute_includes PokeAccess::Puzzles.info_line, t(:rea_farm_hint, :way => t(:dir_left))
    PokeAccess::Config.puzzle_assist = true
    assert_equal t(:rea_farm_right_exit), name_of(exit_ev)
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_farm_hint, :way => t(:dir_left))
    $game_switches[131] = true
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the island names its inscriptions, says the stair as it shows, and gives the photo only with the assist" do
    on_map(149)
    assert_equal t(:rea_island_inscription), name_of(place(1, 43, 11))
    assert_nil PokeAccess::Puzzles.info_line
    PokeAccess::Config.puzzle_assist = true
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_island_photo_hint)
    frame
    assert_equal [t(:rea_island_stairs)], frame { $game_switches[313] = true }
    assert_nil PokeAccess::Puzzles.info_line
  end

  test "the island's three mossy rocks are listed without the assist and the free camera names each of their tiles" do
    on_map(149)
    rock = t(:rea_island_mossy_rock)
    listed = PokeAccess::Puzzles.category_targets.select { |tg| tg.name == rock }.map { |tg| [tg.x, tg.y] }
    assert_equal [[29, 21], [15, 40], [44, 40]], listed
    seen = [[29, 20], [30, 21], [16, 39], [45, 40], [31, 20], [29, 22]].map do |x, y|
      PokeAccess::Camera.tile_lines(x, y).include?(rock)
    end
    assert_equal [true, true, true, true, false, false], seen
    on_map(150)
    refute_includes PokeAccess::Camera.tile_lines(29, 20), rock
  end

  test "a Daruma room gives with the assist the next push of its plan, or to reset the room off the plan" do
    on_map(322)
    PokeAccess::RealideaDaruma::STARTS[322].each_with_index do |(x, y), i|
      ev = place(i + 1, x, y)
      ev.name = "daruma"
    end
    step(23, 14)
    PokeAccess::Config.puzzle_assist = true
    first = t(:rea_daruma_push, :where => PokeAccess::Puzzles.offset_phrase(-2, 0), :dir => t(:face_east), :n => 1)
    assert_includes PokeAccess::Puzzles.info_line, first
    $game_map.events[4].x = 22
    step(20, 14)
    second = t(:rea_daruma_push, :where => PokeAccess::Puzzles.offset_phrase(-1, 0), :dir => t(:face_east), :n => 1)
    assert_includes PokeAccess::Puzzles.info_line, second
    $game_map.events[1].x = 25
    assert_includes PokeAccess::Puzzles.info_line, t(:rea_daruma_off_plan)
  end

  test "every Daruma plan ends with a Darmanitan on each tile of light" do
    daruma = PokeAccess::RealideaDaruma
    daruma::PLANS.keys.each do |map|
      pushes = daruma.pushes(map, daruma::STARTS[map])
      x, y, way, _left, tiles = pushes[-1]
      dx, dy = daruma::STEP[way]
      last = tiles.reject { |t| t == [x, y] }.push([x + dx, y + dy]).sort
      assert_equal daruma::ROOMS[map][1].sort, last, "map #{map}"
    end
  end

  private

  def t(key, vars = {})
    PokeAccess::I18n.t(key, vars)
  end

  # Puts the player on a map of the game with its self switches clear and the texts of the keys that take values known.
  def on_map(map)
    @was_selfs ||= $game_self_switches
    @was_map ||= $game_map.map_id
    $game_self_switches = {}
    $game_map.map_id = map
    PokeAccess::Config.puzzle_assist = false
    PokeAccess::Caches.reset_all
    World.clear_events
    [PokeAccess::I18n::REFERENCE, PokeAccess::I18n.lang].uniq.each do |code|
      table = PokeAccess::I18n.table(code)
      TEMPLATES.each { |key, text| table[key] = text }
    end
  end

  # Gives the map terrain tags on the tiles listed, as {[[x, y], ...] => tag}, each with a tile of its own, and none
  # elsewhere; ids, as {[x, y, layer] => tile id}, draws given tiles over that.
  def lay_tags(tags, ids = {})
    @floor_methods = [:terrain_tag, :width, :height, :data]
    at = {}
    tags.each { |tiles, tag| tiles.each { |xy| at[xy] = tag } }
    grid = Object.new
    grid.define_singleton_method(:[]) { |x, y, z| ids[[x, y, z]] || (z == 0 ? (at[[x, y]] || 0) : 0) }
    $game_map.define_singleton_method(:terrain_tag) { |x, y, *_rest| at[[x, y]] || 0 }
    $game_map.define_singleton_method(:data) { grid }
    $game_map.define_singleton_method(:width) { 60 }
    $game_map.define_singleton_method(:height) { 60 }
  end

  # A touch event of the map on (x, y) drawn with sprite (none for "") whose page runs list.
  def gust(id, x, y, sprite, list)
    page = TestPage.new(:trigger => 1, :sprite => sprite, :list => list)
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :tile_id => 0, :pages => [page])
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # An event of the map on (x, y) whose page shows a text.
  def place(id, x, y, opts = {})
    page = TestPage.new(:trigger => 0, :sprite => "", :direction => opts.fetch(:direction, 2),
                        :list => [TestCmd.new(101, ["text"]), TestCmd.new(0, [])])
    ev = TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :tile_id => 0, :pages => [page])
    ev.direction = opts[:direction] if opts[:direction]
    $game_map.events[id] = ev
    World.next_frame
    ev
  end

  # The routes onto (5,1) of ROOM on map with terrain tag at (3,1), without the puzzle assist and with it, the rules of
  # Realidea's puzzles alone in force.
  def routes_over(map, tag)
    without_terrain_rules do
      Harness.load_puzzles("realidea")
      on_map(map)
      $game_map.clear_ledges
      $game_map.clear_grid
      $game_map.load_grid(ROOM)
      $game_map.set_terrain(3, 1, tag)
      PokeAccess::Pathfinder.invalidate_cache(true)
      off = walk_route(5, 1, true).to_a
      PokeAccess::Config.set(:puzzle_assist, true)
      [off, walk_route(5, 1, true).to_a]
    end
  ensure
    PokeAccess::Config.set(:puzzle_assist, false)
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Runs the block with Realidea's surface labels alone in force, given a reader of the labels of a list of tiles.
  def labels_alone
    terrain = PokeAccess::World::Terrain
    saved = terrain.instance_variable_get(:@label_rules)
    terrain.instance_variable_set(:@label_rules, [])
    Harness.load_puzzles("realidea")
    yield(lambda { |tiles| tiles.map { |x, y| terrain.label(x, y) } })
  ensure
    terrain.instance_variable_set(:@label_rules, saved) if saved
  end

  def name_of(ev)
    PokeAccess::Puzzles.piece_name(ev)
  end

  def step(x, y)
    $game_player.x = x
    $game_player.y = y
  end

  # What the puzzles say on the next map frame, after the block.
  def frame
    SpeakCapture.clear
    yield if block_given?
    PokeAccess::Puzzles.tick
    SpeakCapture.lines
  end
end
