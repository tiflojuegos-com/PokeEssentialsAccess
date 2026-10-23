# A game whose Game_Map#passable? answers from where the player stands declares it, and the world's probe then asks
# each step with the player placed on the step's origin, facing its way (World::Probe.place_player_when), and puts the
# player back, as it puts back the player's own through, lent off while it asks. Insurgence afloat
# (games/insurgence/water.rb) is the case: its passable? lets a surfing player onto water only on its own tile and the
# one it faces, so asked plainly no route is found across a lake.
class InsurgenceWaterTest < PokeAccessTest
  Probe = PokeAccess::World::Probe
  DELTA = { 2 => [0, 1], 4 => [-1, 0], 6 => [1, 0], 8 => [0, -1] }
  # Water steps away from the player's tile and the one it faces: walls to the game unless asked from where they start.
  FAR = [[3, 2, 6], [4, 3, 8], [2, 3, 4], [5, 1, 2], [1, 1, 6]]
  # The profile's declaration: the player placed on each step's origin while afloat.
  AFLOAT = lambda { ($PokemonGlobal.surfing rescue false) ? true : false }

  # A player of the Reborn engine's kind, with readers and no writers, who notes where it stands when asked.
  class ReaderOnlyPlayer
    attr_reader :x, :y, :direction, :seen
    def initialize(x, y, d); @x = x; @y = y; @direction = d; @seen = []; end
    def passable?(_x, _y, _d); @seen.push([@x, @y, @direction]); true; end
  end

  test "asked plainly, a water step away from the player is a wall to the game" do
    on_lake do
      assert_equal [false] * FAR.length, FAR.map { |x, y, d| Probe.step?(x, y, d) }
    end
  end

  test "declared, every water step across the lake is asked from where it starts and is open" do
    on_lake do
      declared { assert_equal [true] * FAR.length, FAR.map { |x, y, d| Probe.step?(x, y, d) } }
    end
  end

  test "declared, a step from the player's own tile toward the one it faces is open, and a wall is still a wall" do
    on_lake do
      declared { assert_equal [true, false], [Probe.step?(1, 1, 2), Probe.step?(5, 1, 6)] }
    end
  end

  test "puts the player back where it stood, facing the way it faced" do
    on_lake do
      $game_player.x = 3
      $game_player.direction = 4
      declared { Probe.step?(3, 2, 6) }
      assert_equal [3, 1, 4], [$game_player.x, $game_player.y, $game_player.direction]
    end
  end

  test "a declaration that cannot answer leaves the step asked plainly" do
    on_lake do
      declared(lambda { raise "unreadable" }) { assert_equal false, Probe.step?(3, 2, 6) }
    end
  end

  test "asks with the player's own through lent off and the probe marked asking, both put back after" do
    seen = []
    with_through do
      $game_player.define_singleton_method(:passable?) { |_x, _y, _d| seen.push([through, Probe.quiet?]); true }
      Probe.step?(9, 9, 4)
      assert_equal [[[false, true]], true, false], [seen, $game_player.through, Probe.quiet?]
    end
  end

  test "a step the game raises on is closed to a route and open to the sonar, the player put back all the same" do
    on_lake do
      declared do
        failing_passable do
          assert_equal [false, true], [Probe.step?(4, 3, 8), Probe.step?(4, 3, 8, true)], "route, sonar"
          assert_equal [1, 1, 2], [$game_player.x, $game_player.y, $game_player.direction], "where it stood"
        end
      end
    end
  end

  test "on foot the game is asked with the player where it stands, whatever the question" do
    $game_player.x = 5
    $game_player.y = 5
    $game_player.direction = 2
    seen = []
    $game_player.define_singleton_method(:passable?) do |x, y, d|
      seen.push([self.x, self.y, direction])
      Game_Player.instance_method(:passable?).bind(self).call(x, y, d)
    end
    declared { Probe.step?(9, 9, 4) }
    assert_equal [[5, 5, 2]], seen
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?) if $game_player.singleton_methods.include?(:passable?)
  end

  test "places a player that has no writers through its fields, and puts it back" do
    on_lake do
      was = $game_player
      begin
        $game_player = ReaderOnlyPlayer.new(1, 1, 2)
        declared { Probe.step?(3, 2, 6) }
        assert_equal [[[3, 2, 6]], [1, 1, 2]],
                     [$game_player.seen, [$game_player.x, $game_player.y, $game_player.direction]]
      ensure
        $game_player = was
      end
    end
  end

  private

  # Runs the block on a lake whose map answers water as Insurgence's passable? does (009_Game_Map_.rb): a water tile
  # counts only while surfing and only as the player's own tile or the one in front of it; the player afloat at (1, 1)
  # facing down. The stub map's own answer is put back after.
  def on_lake
    $game_map.load_grid(["#######",
                         "#~~~~~#",
                         "#~~~~~#",
                         "#~~~~~#",
                         "#######"])
    delta = DELTA
    $game_map.define_singleton_method(:passable?) do |x, y, dir|
      dx, dy = delta[dir]
      nx = x + dx
      ny = y + dy
      return false if cell(nx, ny) == "#"
      return true unless cell(nx, ny) == "~" || cell(x, y) == "~"
      return false unless ($PokemonGlobal.surfing rescue false)
      p = $game_player
      fx, fy = delta[p.direction]
      ok = lambda { |tx, ty| cell(tx, ty) != "~" || [tx, ty] == [p.x, p.y] || [tx, ty] == [p.x + fx, p.y + fy] }
      ok.call(x, y) && ok.call(nx, ny)
    end
    $PokemonGlobal.surfing = true
    $game_player.x = 1
    $game_player.y = 1
    $game_player.direction = 2
    yield
  ensure
    $game_map.singleton_class.send(:remove_method, :passable?) if $game_map.singleton_methods.include?(:passable?)
    $game_player.direction = 2
  end

  # Runs the block with a game's declaration in force, the profile's own unless cond is given: the player placed on each
  # step's origin while it says so. The probe's declarations and answers are put back after.
  def declared(cond = AFLOAT)
    saved = Probe.instance_variable_get(:@placers).dup
    Probe.place_player_when(&cond)
    PokeAccess::World.reset!
    yield
  ensure
    Probe.instance_variable_set(:@placers, saved)
    PokeAccess::World.reset!
  end

  # Runs the block with the player given a through flag, as the engine's player has, set on; the flag and any passable?
  # the block gives the player are taken away after.
  def with_through
    p = $game_player
    p.define_singleton_method(:through) { @pa_through }
    p.define_singleton_method(:through=) { |v| @pa_through = v }
    p.through = true
    yield
  ensure
    [:through, :through=, :passable?].each do |m|
      p.singleton_class.send(:remove_method, m) if p.singleton_methods.include?(m)
    end
    p.send(:remove_instance_variable, :@pa_through) if p.instance_variable_defined?(:@pa_through)
  end

  # Runs the block with the player's passable? raising, the stub's own put back after.
  def failing_passable
    $game_player.define_singleton_method(:passable?) { |*_a| raise "boom" }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?) if $game_player.singleton_methods.include?(:passable?)
  end
end
