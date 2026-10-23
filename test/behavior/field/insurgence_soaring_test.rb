# Insurgence's soaring maps (games/insurgence/soaring.rb): the place under the player, found in the game's
# getSoarAreas boxes as Scene_Map#update finds it, said as the player flies over it.

# Only the profile's module is evaluated, without the game definition that polls it each frame in Insurgence.
path = File.join(Harness::ROOT, "games", "insurgence", "soaring.rb")
eval(Harness.source(path)[/^module PokeAccess\r?\n.*?^end\r?\n/m], TOPLEVEL_BINDING, path)

class InsurgenceSoaringTest < PokeAccessTest
  # Three of Torren's boxes as getSoarAreas lists them, [map id, x0, y0, x1, y1, landing x, landing y] (maps 2, 43
  # and 80 in 179_ChallengeChampionship.rb, the last two sharing an edge), renumbered to maps the stubbed MapInfos
  # names; and a box of Holon's over the same tiles.
  TORREN = [[35, 145, 111, 150, 118, 146, 112], [40, 135, 87, 144, 95, 143, 92], [999, 125, 93, 135, 98, 0, 0]]
  HOLON = [[1, 140, 105, 150, 120, 0, 0]]
  TORREN_MAP = 676
  HOLON_MAP = 749

  # Each test starts with no place asked of the game nor said, the game's functions answering Torren's and Holon's
  # rows and recording each call in @asked.
  def setup
    super
    soaring.instance_variable_set(:@areas, nil)
    soaring.reset
    @asked = []
    asked = @asked
    Kernel.define_singleton_method(:getSoarAreas) { asked.push(:getSoarAreas); TORREN }
    Kernel.define_singleton_method(:getSoarAreasHolon) { asked.push(:getSoarAreasHolon); HOLON }
  end

  # Takes the game's functions away again.
  def teardown
    Kernel.singleton_class.send(:remove_method, :getSoarAreas)
    Kernel.singleton_class.send(:remove_method, :getSoarAreasHolon)
    super
  end

  test "a place is the box holding the player strictly inside its edges" do
    { [146, 112] => 35, [149, 117] => 35, [145, 114] => 0, [150, 114] => 0, [147, 111] => 0, [147, 118] => 0,
      [136, 94] => 40, [134, 94] => 999, [135, 94] => 0, [10, 10] => 0 }.each do |(x, y), want|
      assert_equal want, soaring.area_at(TORREN, x, y), "at (#{x}, #{y})"
    end
  end

  test "of two boxes holding the player, the first listed names the place" do
    assert_equal 7, soaring.area_at([[7, 0, 0, 10, 10], [8, 0, 0, 20, 20]], 5, 5)
  end

  test "no rows hold no place" do
    assert_equal 0, soaring.area_at(nil, 146, 112), "no rows at all"
    assert_equal 0, soaring.area_at([], 146, 112), "an empty list"
  end

  test "arriving over a place says it queued, after the map's own name" do
    fly(146, 112)
    soaring.poll
    assert_equal [["Mapa 35", false]], SpeakCapture.log
  end

  test "flying within the same place says nothing more" do
    fly(146, 112)
    soaring.poll
    SpeakCapture.clear
    soaring.poll
    fly(149, 117)
    soaring.poll
    assert_nothing_spoken
  end

  test "a new place interrupts, being the player's own movement" do
    fly(146, 112)
    soaring.poll
    SpeakCapture.clear
    fly(140, 90)
    soaring.poll
    assert_equal [["Mapa 40", true]], SpeakCapture.log
  end

  test "open sky says nothing, and flying back into the place says it again" do
    fly(146, 112)
    soaring.poll
    SpeakCapture.clear
    fly(10, 10)
    soaring.poll
    assert_nothing_spoken "the HUD is blank over open sky"
    fly(146, 112)
    soaring.poll
    assert_equal [["Mapa 35", true]], SpeakCapture.log
  end

  test "off the soaring maps it is quiet, and back on one it names the place as on arrival" do
    fly(146, 112)
    soaring.poll
    SpeakCapture.clear
    fly(146, 112, 5)
    soaring.poll
    assert_nothing_spoken "a map with no soaring places"
    fly(146, 112)
    soaring.poll
    assert_equal [["Mapa 35", false]], SpeakCapture.log
  end

  test "Holon's places come from its own function" do
    fly(146, 112, HOLON_MAP)
    soaring.poll
    assert_equal [["Mapa 1", false]], SpeakCapture.log
    assert_equal [:getSoarAreasHolon], @asked
  end

  test "asks the game for a map's places once" do
    fly(146, 112)
    3.times { soaring.poll }
    fly(146, 112, HOLON_MAP)
    soaring.poll
    fly(140, 90)
    soaring.poll
    assert_equal [:getSoarAreas, :getSoarAreasHolon], @asked
  end

  test "a player whose place cannot be read says nothing, and the frame goes on" do
    fly(nil, nil)
    soaring.poll
    assert_nothing_spoken
  end

  test "a game whose function fails says nothing" do
    Kernel.define_singleton_method(:getSoarAreas) { raise NameError, "undefined getSoarAreas" }
    fly(146, 112)
    soaring.poll
    assert_nothing_spoken
  end

  private

  # The module under test.
  def soaring
    PokeAccess::InsurgenceSoaring
  end

  # Puts the player at (x, y) on map, Torren's soaring map by default.
  def fly(x, y, map = TORREN_MAP)
    $game_map.map_id = map
    $game_player.x = x
    $game_player.y = y
  end
end
