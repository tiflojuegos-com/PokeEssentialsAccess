# The probe's answers and the regions hang on the map's tiles: one changed is read again at the next frame's search, on
# a new map, or after an event's end, where only a game with plain_passability (Fire Ash) keeps what the engine said.
class MemoFingerprintTest < PokeAccessTest
  # A room with a block in its lower row, the player at its top left.
  ROOM = ["########",
          "#@.....#",
          "#..##..#",
          "########"].freeze
  # A corridor five steps long, the player at its left end.
  CORRIDOR = ["########",
              "#@.....#",
              "########"].freeze

  test "in a plain game, after an event's end the same route comes back without asking the engine again" do
    fingerprinted(ROOM, true) do |asked, tags|
      $game_map.set_terrain(5, 2, 12)
      regions_tiles
      route = walk_route(6, 2, true)
      seen = [asked.length, tags.length]
      assert_operator seen.min, :>, 0, "the first regions and route ask the engine its passability and terrain"
      event_end
      regions_tiles
      assert_equal route, walk_route(6, 2, true), "the same route"
      assert_equal seen, [asked.length, tags.length], "and no question asked of the engine again"
    end
  end

  test "in a plain game, the regions kept past an event's end are the ones the engine gives" do
    fingerprinted(ROOM, true) do
      $game_map.set_terrain(5, 2, 12)
      regions_tiles
      walk_route(6, 2, true)
      event_end
      kept = regions_tiles
      assert_equal live_regions_tiles, kept
    end
  end

  test "in a plain game, a tile changed before an event's end is read again at the search after it" do
    fingerprinted(CORRIDOR, true) do
      assert_equal true, reached?(6, 1), "the corridor open"
      silently_set_row(1, "#@.#...#")
      event_end
      assert_equal false, reached?(6, 1), "closed by the wall put across it"
    end
  end

  test "a terrain changed silently is slid over at the next frame's search" do
    fingerprinted(CORRIDOR, true) do
      assert_equal [6, 6, 6, 6, 6], walk_route(6, 1, true), "the corridor walked"
      $game_map.instance_variable_get(:@terrain)[[3, 1]] = 12
      World.next_frame
      assert_equal [6, 6, 6, 6], walk_route(6, 1, true), "the ice laid on it slid over"
    end
  end

  test "a wall put silently across the corridor closes it at the next frame's search, as the engine says" do
    fingerprinted(CORRIDOR, true) do
      assert_equal true, reached?(6, 1), "the corridor open"
      silently_set_row(1, "#@.#...#")
      World.next_frame
      assert_equal false, reached?(6, 1), "closed"
      assert_equal live_regions_tiles, regions_tiles, "the regions the engine gives"
    end
  end

  test "a tile changed silently after a frame's first search is not read again until the next frame" do
    fingerprinted(CORRIDOR, true) do
      reached?(6, 1)
      World.next_frame
      assert_equal true, reached?(6, 1), "the frame's first search, the tiles compared"
      silently_set_row(1, "#@.#...#")
      assert_equal true, reached?(6, 1), "a later search the same frame"
      World.next_frame
      assert_equal false, reached?(6, 1), "the next frame"
    end
  end

  test "in a plain game, after an event's end the tiles are compared at the next search alone" do
    fingerprinted(CORRIDOR, true) do
      reached?(6, 1)
      event_end
      assert_equal true, reached?(6, 1), "the search after the event's end, the tiles compared"
      silently_set_row(1, "#@.#...#")
      assert_equal true, reached?(6, 1), "a later search before the next frame"
    end
  end

  test "on a map entered anew the tiles are read afresh, whatever was kept on the last one" do
    fingerprinted(CORRIDOR, true) do
      reached?(6, 1)
      silently_set_row(1, "#@.#...#")
      $game_map.map_id = 2
      World.next_frame
      assert_equal false, reached?(6, 1)
    end
  end

  test "a tileset table changed silently is new tiles at the next frame's search" do
    fingerprinted(CORRIDOR, true) do |asked, _tags|
      regions_tiles
      filled = asked.length
      with_passages([0, 15]) do
        World.next_frame
        regions_tiles
        assert_equal 2 * filled, asked.length, "the regions ask the engine all over"
      end
    end
  end

  test "in any other game, an event's end has the regions ask the engine all over" do
    fingerprinted(CORRIDOR, false) do |asked, _tags|
      regions_tiles
      filled = asked.length
      event_end
      regions_tiles
      assert_equal 2 * filled, asked.length
    end
  end

  private

  # Runs the block on a copy of rows loaded as the grid map, the map dumping its rows and terrain as its tile data and
  # answering the tileset readers every engine's Game_Map has, the player's passable? and the map's terrain_tag logged
  # in the arrays yielded ([x, y, d] and the tag's arguments), and the game's passability declared plain or not; all put
  # back after, the route caches dropped.
  def fingerprinted(rows, plain)
    $game_map.load_grid(rows.map { |r| r.dup })
    probe = PokeAccess::World::Probe
    gm = $game_map
    pl = $game_player
    was_plain = probe.plain?
    asked = []
    tags = []
    tag = gm.method(:terrain_tag)
    pass = pl.method(:passable?)
    gm.define_singleton_method(:data) { [@grid, @terrain.to_a.sort] }
    gm.define_singleton_method(:passages) { @passages }
    gm.define_singleton_method(:priorities) { nil }
    gm.define_singleton_method(:terrain_tags) { @terrain_tags }
    gm.define_singleton_method(:terrain_tag) { |*a| tags.push(a); tag.call(*a) }
    pl.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); pass.call(x, y, d) }
    probe.instance_variable_set(:@plain, plain)
    PokeAccess::Pathfinder.invalidate_cache(true)
    yield asked, tags
  ensure
    probe.instance_variable_set(:@plain, was_plain)
    pl.singleton_class.send(:remove_method, :passable?)
    gm.singleton_class.send(:remove_method, :data, :passages, :priorities, :terrain_tags, :terrain_tag)
    PokeAccess::Pathfinder.invalidate_cache(true)
    $game_map.clear_grid
  end

  # An event's end, as refresh_on_event_end runs it.
  def event_end
    PokeAccess::Pathfinder.invalidate_cache
  end

  # Replaces row y of the grid map, telling the world nothing.
  def silently_set_row(y, row)
    $game_map.instance_variable_get(:@grid)[y] = row
  end

  # Runs the block with the map's tileset passage table replaced by table, telling the world nothing; the map's own
  # put back after.
  def with_passages(table)
    had = $game_map.instance_variable_defined?(:@passages)
    was = $game_map.instance_variable_get(:@passages)
    $game_map.instance_variable_set(:@passages, table)
    yield
  ensure
    had ? $game_map.instance_variable_set(:@passages, was) : $game_map.send(:remove_instance_variable, :@passages)
  end

  # The tiles the regions on foot reach, sorted.
  def regions_tiles
    PokeAccess::Routes::Regions.foot.tiles.sort
  end

  # The tiles the regions on foot reach with nothing remembered, as the engine gives them now.
  def live_regions_tiles
    PokeAccess::World::Probe.forget
    PokeAccess::Routes::Regions.forget
    regions_tiles
  end
end
