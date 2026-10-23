# The info key on the map (Info.map_owner, Info.map_text): its owners are asked in the order they registered, else
# where the last forced move left the player and then where each press leaves them on terrain that moves them, else
# the trainer; a name registered again replaces its owner in its place, an owner that fails or answers nothing passes,
# and a screen's own line holds the key until the map's frame.
class InfoOwnerTest < PokeAccessTest
  Info = PokeAccess::Info
  # The gen-6 ice terrain tag.
  ICE = 12

  test "owners are asked in the order they registered, the first that answers giving the line" do
    said = []
    got = only_owners do
      Info.map_owner(:spec_a) { said.first }
      Info.map_owner(:spec_b) { "B" }
      first = map_line
      said.push("A")
      [first, map_line]
    end
    assert_equal ["B", "A"], got
  end

  test "a name registered again replaces its owner in its place" do
    got = only_owners do
      Info.map_owner(:spec_a) { "A" }
      Info.map_owner(:spec_b) { "B" }
      Info.map_owner(:spec_a) { "A otra vez" }
      map_line
    end
    assert_equal "A otra vez", got
  end

  test "an owner that raises or answers nothing passes to the next" do
    owners = { "raises" => lambda { raise "boom" }, "answers nil" => lambda { nil },
               "answers an empty line" => lambda { "" } }
    owners.each do |what, fn|
      got = only_owners do
        Info.map_owner(:spec_a, &fn)
        Info.map_owner(:spec_b) { "B" }
        map_line
      end
      assert_equal "B", got, "an owner that #{what}"
    end
  end

  test "with no owner answering, the line where the last forced move left the player" do
    left = "Te has deslizado 4 hacia arriba"
    assert_equal left, only_owners { forced_line(left) { map_line } }
  end

  test "on terrain that moves the player by itself, the last forced move's line and then where each press leaves them" do
    $game_map.load_grid(["#######", "#.....#", "#.....#", "#.....#", "#######"])
    (2..4).each { |x| $game_map.set_terrain(x, 2, ICE) }
    $game_player.x = 1
    $game_player.y = 2
    ways = [way(:dir_up, leg(1, :dir_up)), way(:dir_right, leg(4, :dir_right)), way(:dir_down, leg(1, :dir_down)),
            way(:dir_left, t(:loc_way_still))]
    left = "Te has deslizado 4 hacia la izquierda"
    assert_equal ([left] + ways).join("; "), only_owners { forced_line(left) { map_line } }, "where the move left them"
    assert_equal ways.join("; "), only_owners { map_line }, "once they move, only the ways"
  end

  test "on terrain that moves the player by itself, a press off the map by an edge that leads on says the exit" do
    (1..3).each { |x| $game_map.set_terrain(x, 5, ICE) }
    $game_player.x = 0
    $game_player.y = 5
    ways = [way(:dir_up, leg(1, :dir_up)), way(:dir_right, leg(4, :dir_right)), way(:dir_down, leg(1, :dir_down))]
    with_edges(3 => [[0, 5, 4]]) do
      assert_equal (ways + [way(:dir_left, t(:loc_exit))]).join("; "), only_owners { map_line }, "open"
      $game_map.block_step(0, 5, 4)
      assert_equal (ways + [way(:dir_left, t(:loc_way_still))]).join("; "), only_owners { map_line }, "shut"
    end
  end

  test "on terrain that moves the player by itself, a press into a doorway out of the map says the exit" do
    $game_map.load_grid(["#######", "#.....#", "#.....#", "#.....#", "#######"])
    (2..4).each { |x| $game_map.set_terrain(x, 2, ICE) }
    World.event(:kind => :door, :id => 8, :x => 1, :y => 1)
    World.event(:kind => :door, :id => 9, :x => 0, :y => 2)
    $game_player.x = 1
    $game_player.y = 2
    want = [way(:dir_up, t(:loc_exit)), way(:dir_right, leg(4, :dir_right)), way(:dir_down, leg(1, :dir_down)),
            way(:dir_left, t(:loc_exit))].join("; ")
    assert_equal want, only_owners { map_line }
  end

  test "with no owner answering and no forced move, the trainer's line" do
    assert_equal Info.trainer_info, only_owners { map_line }
  end

  test "at rest on the map, the mod's own owners pass and the trainer's line is said" do
    assert_equal Info.trainer_info, map_line
  end

  test "a screen's own line holds the key until the map's next frame takes it back" do
    got = only_owners do
      Info.map_owner(:spec_b) { "B" }
      Info.set_info(:text, "Una pantalla")
      [Info.info_text, map_line]
    end
    assert_equal ["Una pantalla", "B"], got
  end

  private

  # What the info key reads once the map's frame has handed it the key.
  def map_line
    PokeAccess::Locator.refresh_info
    Info.info_text
  end

  # The text of an i18n key.
  def t(key, args = {}); PokeAccess::I18n.t(key, args); end

  # A press's leg of n tiles toward dir, as the info key says it.
  def leg(n, dir); t(:loc_leg, :n => n, :dir => t(dir)); end

  # Where a press toward dir leaves the player, as the info key says it.
  def way(dir, to); t(:loc_way, :dir => t(dir), :to => to); end

  # The block's value with the map's owners only those it registers, the real ones put back after.
  def only_owners
    was = Info.instance_variable_get(:@map_owners)
    Info.instance_variable_set(:@map_owners, [])
    yield
  ensure
    Info.instance_variable_set(:@map_owners, was)
  end

  # Runs the block with the map's border leading off as edges says ({ destination => [[x, y, way out], ...] }).
  def with_edges(edges)
    loc = PokeAccess::Locator
    saved = [:@conn_edges, :@conn_targets_mid].map { |k| loc.instance_variable_get(k) }
    loc.instance_variable_set(:@conn_targets_mid, $game_map.map_id)
    loc.instance_variable_set(:@conn_edges, edges)
    yield
  ensure
    loc.instance_variable_set(:@conn_edges, saved[0])
    loc.instance_variable_set(:@conn_targets_mid, saved[1])
  end

  # The block's value with the last forced move's line answering line, the real one put back after.
  def forced_line(line)
    sc = PokeAccess::ForcedMove.singleton_class
    sc.send(:alias_method, :info_owner_test_line, :line)
    PokeAccess::ForcedMove.define_singleton_method(:line) { line }
    yield
  ensure
    if sc && sc.method_defined?(:info_owner_test_line)
      sc.send(:alias_method, :line, :info_owner_test_line)
      sc.send(:remove_method, :info_owner_test_line)
    end
  end
end
