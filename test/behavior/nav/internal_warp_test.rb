# A warp to another spot of the map the player is on is named a passage toward the side of the map it leads to, and a
# move of the player of more than a tile within the map, not a ledge hop or a move route the game drives, is announced
# at the teleport reading's level (that the player moved, how far each way, and the side it lands on), or by the line a
# profile gives for its cause (Opalo's trap floor), the selection kept and the target list left to be rebuilt when next
# used; a frame with no map or no readable place is skipped.
class InternalWarpTest < PokeAccessTest
  Loc = PokeAccess::Locator

  # On a map 98 tiles wide and 35 tall, whose sides start 12 and 4 tiles out from its centre (49, 17).
  def setup
    super
    $game_map.width = 98
    $game_map.height = 35
  end

  test "names a warp to this map a passage toward the side it leads to" do
    assert_equal t(:loc_passage_dir, :dir => t(:dir_e)), Loc.target_name(warp(11, 21, 5, $game_map.map_id, 89, 14))
  end

  test "names a warp that leads near the map's centre a passage alone" do
    assert_equal t(:loc_passage), Loc.target_name(warp(11, 21, 5, $game_map.map_id, 50, 18))
  end

  test "names a warp to another map an exit to it" do
    assert_equal t(:loc_exit_to, :map => "Mapa 999"), Loc.target_name(warp(7, 69, 3, 999, 70, 10))
  end

  test "tells the side of the map a tile is on, each axis counting from an eighth of the map out" do
    { [49, 17] => nil, [60, 17] => nil, [61, 17] => :dir_e, [38, 17] => nil, [37, 17] => :dir_o,
      [49, 20] => nil, [49, 21] => :dir_s, [49, 14] => nil, [49, 13] => :dir_n, [61, 21] => :dir_se,
      [37, 13] => :dir_no, [61, 13] => :dir_ne, [37, 21] => :dir_so }.each do |(x, y), want|
      assert_answer want, Loc.cardinal_of(x, y), "(#{x}, #{y})"
    end
  end

  test "counts an axis from two tiles out on a small map" do
    $game_map.width = 8
    $game_map.height = 8
    { [5, 4] => nil, [6, 4] => :dir_e, [2, 4] => :dir_o, [4, 6] => :dir_s, [4, 3] => nil }.each do |(x, y), want|
      assert_answer want, Loc.cardinal_of(x, y), "(#{x}, #{y})"
    end
  end

  test "tells no side for a tile with no column or no row" do
    [[nil, 17], [80, nil]].each { |x, y| assert_nil Loc.cardinal_of(x, y), "(#{x.inspect}, #{y.inspect})" }
  end

  test "tells no side on a map of no size, or whose size cannot be read" do
    [[:width, 0], [:height, 0], [:width, nil], [:height, nil]].each do |axis, n|
      with_size(axis, n) { assert_nil Loc.cardinal_of(80, 17), "#{axis} #{n.inspect}" }
    end
  end

  test "tells a side on a map one tile wide or one tile tall" do
    { [:width, 0, 30] => :dir_s, [:height, 80, 0] => :dir_e }.each do |(axis, x, y), want|
      with_size(axis, 1) { assert_equal want, Loc.cardinal_of(x, y), "one tile of #{axis}" }
    end
  end

  test "announces a move of more than a tile within the map, queued, with how far it went and the side it lands on" do
    stand(21, 5)
    SpeakCapture.clear
    stand(89, 14)
    assert_equal [[full_line(68, 9, :dir_e), false]], SpeakCapture.log
  end

  test "Brief says only that the player moved, Medium how far each way, Full the part of the map it lands in too" do
    said = vb_levels do
      stand(66, 18)
      SpeakCapture.clear
      stand(63, 13)
      SpeakCapture.lines
    end
    moved = t(:loc_moved, :dirs => t(:list_and, :rest => t(:moved_up, :n => 5), :last => t(:moved_left, :n => 3)))
    assert_equal [[t(:loc_teleported_plain)], [moved], ["#{moved}; #{t(:loc_teleport_zone, :zone => t(:dir_ne))}"]], said
  end

  test "takes a move of two tiles either way for a move within the map, and a step of one for none" do
    { [22, 5] => [], [21, 6] => [], [23, 5] => [[full_line(2, 0, :dir_no), false]],
      [21, 7] => [[full_line(0, 2, :dir_no), false]] }.each do |(x, y), want|
      stand(21, 5)
      SpeakCapture.clear
      stand(x, y)
      assert_equal want, SpeakCapture.log, "to (#{x}, #{y})"
    end
  end

  test "skips a frame with no map or no readable place, telling the next move from the last place seen" do
    [:map, :x, :y].each do |what|
      stand(21, 5)
      SpeakCapture.clear
      blank_frame(what)
      stand(89, 14)
      assert_equal [[full_line(68, 9, :dir_e), false]], SpeakCapture.log, what.to_s
    end
  end

  test "Full leaves the part of the map out for a move that lands near the map's centre" do
    stand(21, 5)
    SpeakCapture.clear
    stand(49, 17)
    assert_equal [[full_line(28, 12, nil), false]], SpeakCapture.log
    assert_equal false, SpeakCapture.last.include?(";"), "no zone clause"
  end

  test "says nothing for the first place it sees, nor for a move that comes with a map change" do
    stand(21, 5)
    assert_nothing_spoken "the first place"
    $game_map.map_id = 2
    stand(89, 14)
    assert_nothing_spoken "onto another map"
  end

  test "says nothing for a ledge hop, and keeps the selection" do
    focus = selected
    stand(89, 12)
    $game_player.jumping = true
    stand(89, 14)
    assert_nothing_spoken
    assert_same focus, Loc.target
  ensure
    $game_player.jumping = false
  end

  test "says nothing for a move route the game drives" do
    stand(21, 5)
    forced { stand(89, 14) }
    assert_nothing_spoken
  end

  test "leaves the list to be rebuilt when next used after a move within the map, keeping the selection" do
    focus = selected
    stand(21, 5)
    stand(89, 14)
    assert_equal 1, rebuilds { Loc.ensure_target }, "rebuilt once on its next use"
    assert_same focus, Loc.target, "with the selection kept"
  end

  test "leaves the list as it is after a ledge hop" do
    selected
    stand(89, 12)
    $game_player.jumping = true
    stand(89, 14)
    assert_equal 0, rebuilds { Loc.ensure_target }
  ensure
    $game_player.jumping = false
  end

  test "says nothing, and raises nothing, before there is a player" do
    was = $game_player
    $game_player = nil
    Loc.announce_internal_teleport
    assert_nothing_spoken
  ensure
    $game_player = was
  end

  test "a walk of several tiles in one update, as up a waterfall, or a diagonal step is no teleport" do
    drawn_at(10, 10) do
      [[10, 14], [11, 11]].each do |x, y|
        stand(10, 10)
        SpeakCapture.clear
        stand(x, y)
        assert_nothing_spoken "to (#{x}, #{y}), drawn still on (10, 10)"
      end
    end
  end

  test "a move the drawn player makes too, as a transfer's, is a teleport" do
    drawn_at(21, 5) do
      stand(21, 5)
      SpeakCapture.clear
      @drawn = [89 * 128, 14 * 128]
      stand(89, 14)
      assert_equal [[full_line(68, 9, :dir_e), false]], SpeakCapture.log
    end
  end

  test "a teleport whose cause a profile knows is said by the profile's line in its place, at every level" do
    map = $game_map.map_id
    known = lambda { |from, to| [from, to] == [[21, 5, map], [89, 14, map]] ? "sent back" : nil }
    said = with_cause(known) do
      vb_levels do
        stand(21, 5)
        SpeakCapture.clear
        stand(89, 14)
        SpeakCapture.log
      end
    end
    assert_equal [[["sent back", false]]] * 3, said
  end

  test "a teleport whose cause no profile knows, or whose cause fails, keeps the teleport line" do
    causes = { "unknown" => lambda { |_from, _to| nil }, "failing" => lambda { |_from, _to| raise "unreadable" } }
    causes.each do |what, cause|
      with_cause(cause) do
        stand(21, 5)
        SpeakCapture.clear
        stand(89, 14)
        assert_equal [[full_line(68, 9, :dir_e), false]], SpeakCapture.log, what
      end
    end
  end

  test "Opalo's trap floor sending the player back to the gym's entrance is said as the trap's doing" do
    with_opalo_traps do
      $game_map.set_terrain(4, 29, 4)
      stand(4, 29)
      SpeakCapture.clear
      stand(21, 69)
      assert_equal [[t(:op_trap_back), false]], SpeakCapture.log, "from a trap tile"
      stand(5, 29)
      SpeakCapture.clear
      stand(21, 69)
      assert_equal [[full_line(16, 40, Loc.cardinal_of(21, 69)), false]], SpeakCapture.log, "from floor that is no trap"
    end
  end

  test "turning the mod back on after walking with it off is no teleport" do
    stand(21, 5)
    PokeAccess::Keys.instance_variable_set(:@enabled, false)
    PokeAccess::Frame.run
    $game_player.x = 89
    PokeAccess::Keys.instance_variable_set(:@enabled, true)
    SpeakCapture.clear
    Loc.announce_internal_teleport
    assert_nothing_spoken
  ensure
    PokeAccess::Keys.instance_variable_set(:@enabled, true)
  end

  private

  def t(key, opts = {}); PokeAccess::I18n.t(key, opts); end

  # The Full line for a move of (dx, dy) tiles that lands in zone, a dir_ key (nil near the centre: no zone clause).
  def full_line(dx, dy, zone)
    moved = PokeAccess::Routes::Text.moved(dx, dy)
    zone ? "#{moved}; #{t(:loc_teleport_zone, :zone => t(zone))}" : moved
  end

  # Runs the block with the player drawn on the tile (x, y), in the engine's 128ths of a tile, or where @drawn is set
  # to meanwhile; real_x and real_y taken off after.
  def drawn_at(x, y)
    @drawn = [x * 128, y * 128]
    test = self
    $game_player.define_singleton_method(:real_x) { test.instance_variable_get(:@drawn)[0] }
    $game_player.define_singleton_method(:real_y) { test.instance_variable_get(:@drawn)[1] }
    yield
  ensure
    [:real_x, :real_y].each { |m| ($game_player.singleton_class.send(:remove_method, m) rescue nil) }
  end

  # Passes when got is want, nil included.
  def assert_answer(want, got, msg = nil)
    want.nil? ? assert_nil(got, msg) : assert_equal(want, got, msg)
  end

  # A sprite-less touch warp at (x, y) to (dx, dy) of map dmap.
  def warp(id, x, y, dmap, dx, dy)
    pg = TestPage.new(:trigger => 1, :sprite => "", :list => [TestCmd.new(201, [0, dmap, dx, dy])])
    TestGameEvent.new(:id => id, :x => x, :y => y, :name => "EV#{id}", :pages => [pg], :active_page => pg)
  end

  # Puts the player on (x, y) and runs the frame's check for a move within the map.
  def stand(x, y)
    $game_player.x = x
    $game_player.y = y
    Loc.announce_internal_teleport
  end

  # The block's value with cause registered as a profile's teleport cause, the causes put back after.
  def with_cause(cause)
    causes = Loc.instance_variable_get(:@teleport_causes)
    kept = causes.dup
    Loc.teleport_cause(:internal_warp_test, &cause)
    yield
  ensure
    causes.replace(kept)
  end

  # Runs the block on map 36 with Opalo's trap floor (games/opalo/floor_traps.rb) evaluated as the loader does; what
  # it registers (its arrival rule, surface label, teleport cause and profile name) and the map are put back after.
  def with_opalo_traps
    lists = [PokeAccess::Routes::Moves.instance_variable_get(:@arrival_rules),
             PokeAccess::World::Terrain.instance_variable_get(:@label_rules),
             Loc.instance_variable_get(:@teleport_causes), PokeAccess::Game.profiles]
    kept = lists.map { |l| l.dup }
    map = $game_map.map_id
    path = File.join(Harness::ROOT, "games", "opalo", "floor_traps.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    $game_map.map_id = 36
    yield
  ensure
    lists.each_with_index { |l, i| l.replace(kept[i]) } if kept
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
    PokeAccess::Routes::Moves.forget_map
    $game_map.map_id = map if map
  end

  # Runs the block with a move route the game drives on the player, taken off after.
  def forced
    $game_player.define_singleton_method(:move_route_forcing) { true }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :move_route_forcing)
  end

  # Runs the frame's check once with the map gone (:map) or the player's x or y unreadable, all put back after.
  def blank_frame(what)
    map = $game_map
    if what == :map
      $game_map = nil
    else
      $game_player.define_singleton_method(what) { raise "unreadable" }
    end
    Loc.announce_internal_teleport
  ensure
    $game_map = map
    $game_player.singleton_class.send(:remove_method, what) if $game_player.singleton_methods.include?(what)
  end

  # Runs the block with the map's width or height (axis) set to n, or unreadable for nil, put back after.
  def with_size(axis, n)
    was = $game_map.send(axis)
    if n
      $game_map.send("#{axis}=", n)
    else
      $game_map.define_singleton_method(axis) { raise "unreadable" }
    end
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, axis) if $game_map.singleton_methods.include?(axis)
    $game_map.send("#{axis}=", was)
  end

  # A person on the map, built into the target list and selected.
  def selected
    focus = World.event(:kind => :npc, :id => 3, :x => 80, :y => 14)
    Loc.rebuild_targets
    Loc.instance_variable_set(:@target, focus)
    focus
  end

  # How many times the target list is rebuilt while the block runs, the locator's own rebuild put back after.
  def rebuilds
    n = 0
    real = Loc.method(:rebuild_targets)
    Loc.define_singleton_method(:rebuild_targets) { n += 1; real.call }
    yield
    n
  ensure
    Loc.define_singleton_method(:rebuild_targets, real)
  end
end
