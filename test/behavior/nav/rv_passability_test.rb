# The player passability of the engine Reborn, Rejuvenation and Desolation share (games/rv_common/passability_rv.rb):
# the lava surf and Blindstep join the probe's mode, an event's end keeps its answers, and riding Tauros the engine is
# asked with the player on each step's origin, facing its way.
Harness.load_common("rv_common")

class RvPassabilityTest < PokeAccessTest
  Probe = PokeAccess::World::Probe
  # The lava tiles of the corridor, the player at its left end.
  LAVA = [[2, 1], [3, 1]]

  test "the probe's answers onto lava follow the lava surf both ways" do
    corridor
    with_engine(lava_rule) do
      with_rv do
        assert_equal [false, true, false], answers_with([false, true, false]) { |on| $PokemonGlobal.lavasurfing = on }
      end
    end
  end

  test "the probe's answers follow Blindstep both ways" do
    corridor
    blind = lambda { |x, y, d| !LAVA.include?(ahead(x, y, d)) || $game_switches[:Blindstep] }
    with_engine(blind) do
      with_rv do
        assert_equal [false, true, false], answers_with([false, true, false]) { |on| $game_switches[:Blindstep] = on }
      end
    end
  end

  test "the regions stop at the lava on foot and cross it once it is surfed, with no step taken" do
    corridor
    with_engine(lava_rule) do
      with_rv do
        on_foot = LAVA.map { |x, y| reached?(x, y) }
        $PokemonGlobal.lavasurfing = true
        World.next_frame
        assert_equal [[false, false], [true, true]], [on_foot, LAVA.map { |x, y| reached?(x, y) }],
                     "on foot neither lava tile is reached, surfing both are"
      end
    end
  end

  test "an event's end keeps the probe's answers" do
    corridor
    with_engine(lambda { |_x, _y, _d| true }) do |seen|
      with_rv do
        Probe.step?(1, 1, 6)
        PokeAccess::Pathfinder.invalidate_cache
        World.next_frame
        Probe.step?(1, 1, 6)
        assert_equal 1, seen.length, "the engine was asked once"
      end
    end
  end

  test "riding Tauros the engine is asked with the player on the step's origin, on foot where they stand" do
    corridor
    with_engine(lambda { |_x, _y, _d| true }) do |seen|
      with_rv do
        { false => [[1, 1, 2]], true => [[3, 1, 6]] }.each do |riding, want|
          seen.clear
          $game_switches[:Riding_Tauros] = riding
          World.next_frame
          Probe.step?(3, 1, 6)
          assert_equal want, seen, riding ? "riding Tauros" : "on foot"
        end
      end
    end
  end

  test "riding Tauros the player is put back after each question" do
    corridor
    with_engine(lambda { |_x, _y, _d| true }) do
      with_rv do
        $game_switches[:Riding_Tauros] = true
        Probe.step?(3, 1, 6)
        assert_equal [1, 1, 2], [$game_player.x, $game_player.y, $game_player.direction]
      end
    end
  end

  test "a player with only position readers is placed through its fields and put back" do
    pl = reader_only_player
    with_player(pl) do
      with_rv do
        $game_switches[:Riding_Tauros] = true
        answer = Probe.step?(3, 1, 6)
        assert_equal [true, [[3, 1, 6]], [1, 1, 2]], [answer, pl.seen, [pl.x, pl.y, pl.direction]],
                     "the step answered, asked on its origin facing its way, the player back where it was"
      end
    end
  end

  test "a question the engine fails is a closed step, the player put back and the probe asking no more" do
    pl = reader_only_player
    pl.fail = true
    with_player(pl) do
      with_rv do
        $game_switches[:Riding_Tauros] = true
        answer = Probe.step?(3, 1, 6)
        assert_equal [false, [1, 1, 2], false], [answer, [pl.x, pl.y, pl.direction], Probe.quiet?]
      end
    end
  end

  test "loaded outside the RV engine it binds nothing: riding Tauros the engine is asked where the player stands" do
    corridor
    with_engine(lambda { |_x, _y, _d| true }) do |seen|
      $game_switches[:Riding_Tauros] = true
      World.next_frame
      Probe.step?(3, 1, 6)
      assert_equal [[1, 1, 2]], seen
    end
  end

  test "its pushed boulders slide on ice, as its engine slides any character" do
    pushes = PokeAccess::Routes::Pushes
    assert_equal [false, true], [pushes.sliding?, with_rv { pushes.sliding? }]
  end

  private

  # A corridor of five tiles with the player at (1, 1), facing down.
  def corridor
    $game_map.load_grid(["#####",
                         "#@..#",
                         "#####"])
    $game_player.direction = 2
  end

  # The engine's passability over the corridor: no wall ahead, and onto lava only while surfing it.
  def lava_rule
    lambda do |x, y, d|
      to = ahead(x, y, d)
      $game_map.cell(*to) != "#" && (!LAVA.include?(to) || $PokemonGlobal.lavasurfing)
    end
  end

  # The tile a step from (x, y) toward d lands on.
  def ahead(x, y, d)
    dd = PokeAccess::DIR_DELTA[d]
    [x + dd[0], y + dd[1]]
  end

  # The probe's answer for the step from (1, 1) onto the lava, as the next frame asks it, under each state the block
  # sets.
  def answers_with(states)
    states.map do |on|
      yield on
      World.next_frame
      Probe.step?(1, 1, 6)
    end
  end

  # Runs the block with the player's passable? answering rule's (x, y, d) and logging, for each question, where the
  # player stood and faced as it was asked; yields the log, the stub's own passable? put back afterwards.
  def with_engine(rule)
    seen = []
    pl = $game_player
    pl.define_singleton_method(:passable?) do |x, y, d|
      seen.push([pl.x, pl.y, pl.direction])
      rule.call(x, y, d)
    end
    yield seen
  ensure
    pl.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block on the RV engine's probe: no mode reader, placement or plain passability of another game, the
  # lava surf flag on the stub's global, switches by the engine's symbol names and PassabilityRV bound; all put back
  # afterwards.
  def with_rv
    saved = [:@readers, :@placers, :@plain].map { |iv| Probe.instance_variable_get(iv) }
    switches = $game_switches
    Probe.instance_variable_set(:@readers, [])
    Probe.instance_variable_set(:@placers, [])
    Probe.instance_variable_set(:@plain, false)
    def $PokemonGlobal.lavasurfing; @lavasurfing ? true : false; end
    def $PokemonGlobal.lavasurfing=(v); @lavasurfing = v; end
    $game_switches = Hash.new(false)
    PokeAccess::PassabilityRV.bind
    PokeAccess::World.reset!
    yield
  ensure
    [:@readers, :@placers, :@plain].each_with_index { |iv, i| Probe.instance_variable_set(iv, saved[i]) }
    $game_switches = switches
    class << $PokemonGlobal; remove_method :lavasurfing, :lavasurfing=; end
    $PokemonGlobal.remove_instance_variable(:@lavasurfing) if $PokemonGlobal.instance_variable_defined?(:@lavasurfing)
    PokeAccess::World.reset!
  end

  # A player as the RV engine has it: readers only for its position (Game_Character's attr_reader :x, :y, :direction),
  # at (1, 1) facing down; its passable? logs where it stood when asked, and raises with fail set.
  def reader_only_player
    klass = Class.new do
      attr_reader :x, :y, :direction, :seen
      attr_accessor :through, :fail
      def initialize; @x = 1; @y = 1; @direction = 2; @through = false; @fail = false; @seen = []; end

      def passable?(_x, _y, _d)
        raise "engine failure" if @fail
        @seen.push([@x, @y, @direction])
        true
      end
    end
    klass.new
  end

  # Runs the block with pl as $game_player, the stub's player put back afterwards.
  def with_player(pl)
    had = $game_player
    $game_player = pl
    yield
  ensure
    $game_player = had
  end
end
