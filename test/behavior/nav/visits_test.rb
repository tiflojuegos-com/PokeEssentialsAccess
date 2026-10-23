# The memos of the maps left (World::Visits): back where the tiles stand, the engine is asked only about its events'
# tiles; changed tiles, a passability not plain and a reset keep nothing; the last eight maps are kept, oldest first.
class VisitsTest < PokeAccessTest
  Visits = PokeAccess::World::Visits
  Epoch = PokeAccess::World::Epoch
  NPC = 61

  test "a map come back to asks the engine only about the tiles its events stood on, then and now" do
    { "settled anew" => false, "with every cache dropped, as a map change does" => true }.each do |how, caches|
      visited_grid(true) do |asked|
        walk_on_foot
        assert_operator asked.length, :>, 20, "#{how}: the first walk asks the engine"
        away_and_back(caches) { $game_map.events[NPC].x = 6 }
        asked.clear
        walk_on_foot
        assert_equal [], asked - (around(asked, 5, 2) | around(asked, 6, 2)), "#{how}: only about the NPC's tiles"
        refute_empty around(asked, 5, 2), "#{how}: where it stood when the map was left"
        refute_empty around(asked, 6, 2), "#{how}: where it stands now"
      end
    end
  end

  test "a map come back to is no longer among those kept" do
    visited_grid(true) do
      home = $game_map.map_id
      away_and_back(false)
      assert_equal [home + 1], Visits.maps
    end
  end

  test "tiles changed while away keep nothing: the walk asks as much as one afresh" do
    visited_grid(true) do |asked|
      walk_on_foot
      away_and_back(false) { $game_map.set_terrain(3, 1, 7) }
      asked.clear
      walk_on_foot
      back = asked.length
      PokeAccess::World.reset!
      asked.clear
      walk_on_foot
      fresh = asked.length
      assert_equal fresh, back, "as many questions back there as a walk afresh on the changed tiles"
    end
  end

  test "keeps nothing of a map left where the passability is not plain" do
    visited_grid(false) do |asked|
      walk_on_foot
      full = asked.length
      home = $game_map.map_id
      settle_on(home + 1)
      assert_equal [], Visits.maps, "nothing kept as the map is left"
      settle_on(home)
      asked.clear
      walk_on_foot
      assert_equal full, asked.length, "and the walk back there asks everything again"
    end
  end

  test "a forced reset keeps nothing: the walk asks everything again" do
    visited_grid(true) do |asked|
      walk_on_foot
      full = asked.length
      PokeAccess::World.reset!
      asked.clear
      walk_on_foot
      assert_equal full, asked.length
    end
  end

  test "keeps the eight maps left last, oldest first" do
    visited_grid(true) do
      home = $game_map.map_id
      (1..9).each { |i| settle_on(home + i) }
      assert_equal (home + 1..home + 8).to_a, Visits.maps
    end
  end

  test "keeps a map left twice once" do
    visited_grid(true) do
      tiles = Epoch.fingerprint
      2.times { Visits.leave(7, tiles) }
      assert_equal [7], Visits.maps
    end
  end

  test "keeps nothing of a map left with no id or with tiles it could not read" do
    visited_grid(true) do
      { "no map id" => [nil, Epoch.fingerprint], "no fingerprint of its tiles" => [7, nil] }.each do |how, (id, tiles)|
        Visits.leave(id, tiles)
        assert_equal [], Visits.maps, how
      end
    end
  end

  test "forgets every map kept" do
    visited_grid(true) do
      Visits.leave(7, Epoch.fingerprint)
      Visits.forget
      assert_equal [], Visits.maps
    end
  end

  private

  # Runs the block on a walled room with a blocking NPC at (5, 2), the world settled there, the game's passability
  # declared plain or not, every question the engine's passable? gets recorded in the array the block is given; all
  # put back after.
  def visited_grid(plain)
    probe = PokeAccess::World::Probe
    was_plain = probe.instance_variable_get(:@plain)
    asked = []
    $game_map.load_grid(["########",
                         "#@.....#",
                         "#......#",
                         "########"])
    World.event(:kind => :npc, :id => NPC, :x => 5, :y => 2).blocking = true
    class << $game_player; alias_method :visits_test_passable?, :passable?; end
    $game_player.define_singleton_method(:passable?) { |x, y, d| asked.push([x, y, d]); visits_test_passable?(x, y, d) }
    probe.instance_variable_set(:@plain, plain)
    Visits.forget
    PokeAccess::Pathfinder.invalidate_cache(true)
    settle_on($game_map.map_id)
    yield asked
  ensure
    probe.instance_variable_set(:@plain, was_plain)
    class << $game_player; remove_method :passable?, :visits_test_passable?; end
    Visits.forget
    World.clear_events
    $game_map.clear_grid
    PokeAccess::Pathfinder.invalidate_cache(true)
  end

  # Walks the regions on foot afresh, as a route does.
  def walk_on_foot
    PokeAccess::Routes::Regions.forget
    PokeAccess::Routes::Regions.foot.tiles
  end

  # Puts the player on map id and settles the world there, as Epoch sees a new map, with every cache dropped first
  # when caches (what a map change runs).
  def settle_on(id, caches = false)
    $game_map.map_id = id
    PokeAccess::Caches.reset_all if caches
    Epoch.dirty!
    Epoch.settle
  end

  # Leaves the map for the next id and comes back, settling on each as settle_on does; the block, if any, runs while
  # away.
  def away_and_back(caches)
    home = $game_map.map_id
    [home + 1, home].each do |id|
      settle_on(id, caches)
      yield if block_given? && id != home
    end
  end

  # The questions asked about steps into or out of (x, y).
  def around(asked, x, y)
    asked.select do |ax, ay, d|
      dx = d == 6 ? 1 : (d == 4 ? -1 : 0)
      dy = d == 2 ? 1 : (d == 8 ? -1 : 0)
      [ax, ay] == [x, y] || [ax + dx, ay + dy] == [x, y]
    end
  end
end
