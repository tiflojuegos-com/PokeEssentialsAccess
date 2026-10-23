# The mod's reading of a one-way ledge as the world stub places it (place_ledge): World::Terrain.ledge? finds it, and
# Routes::Moves.ledge_jump hops it from its high side alone, two tiles on, in each of the four directions.
class LedgeStubTest < PokeAccessTest
  Moves = PokeAccess::Routes::Moves
  # The ledge each direction test places, on the open default map.
  AT = [8, 8]

  test "a placed ledge reads as a ledge, the tiles beside it as none" do
    $game_map.place_ledge(5, 7, 2)
    ter = PokeAccess::World::Terrain
    assert_equal [true, false, false, false], [ter.ledge?(5, 7), ter.ledge?(5, 6), ter.ledge?(5, 8), ter.ledge?(4, 7)]
  end

  test "a ledge is hopped from its high side, landing two tiles on, in each direction" do
    PokeAccess::Routes::DIRS.each do |dx, dy, d|
      ledge_at(d)
      assert_equal [AT[0] + dx, AT[1] + dy], Moves.ledge_jump(AT[0] - dx, AT[1] - dy, dx, dy, d), "a ledge hopped #{d}"
    end
  end

  test "a ledge is no hop from its low side" do
    PokeAccess::Routes::DIRS.each do |dx, dy, d|
      ledge_at(d)
      assert_nil Moves.ledge_jump(AT[0] + dx, AT[1] + dy, -dx, -dy, 10 - d), "a ledge hopped #{d}, pressed against it"
    end
  end

  test "a ledge is no hop from beside it" do
    PokeAccess::Routes::DIRS.each do |dx, dy, d|
      ledge_at(d)
      across = PokeAccess::Routes::DIRS.find { |sx, sy, _s| sx == dy.abs && sy == dx.abs }
      assert_nil Moves.ledge_jump(AT[0] - across[0], AT[1] - across[1], across[0], across[1], across[2]),
                 "a ledge hopped #{d}, pressed #{across[2]} from beside"
    end
  end

  test "a hop whose landing the engine refuses goes nowhere, false where a press at no ledge is nil" do
    $game_map.place_ledge(5, 7, 2)
    World.event(:kind => :npc, :id => 4, :x => 5, :y => 8).blocking = true
    PokeAccess::Pathfinder.invalidate_cache(true)
    assert_equal false, Moves.ledge_jump(5, 6, 0, 1, 2), "the ledge's landing is taken"
    assert_nil Moves.ledge_jump(4, 6, 0, 1, 2), "no ledge that way"
  end

  private

  # Places the one ledge of a direction test at AT, hopped in direction d, on a map with no other.
  def ledge_at(d)
    $game_map.clear_ledges
    $game_map.place_ledge(AT[0], AT[1], d)
  end
end
