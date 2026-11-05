# Infinite Fusion 2's secret base seats (games/infinitefusion_hoenn/secret_base.rb): sitting down is said, then the key
# that stands the player up while key hints are said; standing up is said, cutting in, as the seat's loop returns.

# The seat's jump and wait, down to its argument; it returns once an arrow stands the player up.
def sit_on_chair_event(_event); :stood_up; end

class IfhSecretBaseGdTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "infinitefusion_hoenn", "secret_base.rb")

  # Evaluates the profile file once, as boot does, its wraps bound to the stand-in above.
  def self.load_profile
    profiles = PokeAccess::Game.profiles.dup
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
  ensure
    PokeAccess::Game.profiles.replace(profiles)
  end
  load_profile

  # A base the player is in, landed on (8, 12).
  Base = Struct.new(:inside_entrance_position)

  # Runs the block on the map of the bases, with the player inside base (nil for none).
  def in_bases(base)
    Object.const_set(:MAP_SECRET_BASES, 64)
    was = $game_map.map_id
    $game_map.map_id = 64
    entered = base
    Object.send(:define_method, :getEnteredSecretBase) { entered }
    Object.send(:private, :getEnteredSecretBase)
    PokeAccess::Locator.clear_verdicts
    yield
  ensure
    Object.send(:remove_const, :MAP_SECRET_BASES)
    Object.send(:remove_method, :getEnteredSecretBase)
    $game_map.map_id = was
    PokeAccess::Locator.clear_verdicts
  end

  # A way out of a base on (x, y).
  def way_out(x, y, id = 1)
    World.touch(:id => id, :x => x, :y => y, :list => [TestCmd.new(355, ["exitSecretBase"])])
  end

  test "the way out of the base the player is in is a door, said as an exit, and it alone is listed" do
    in_bases(Base.new([8, 12])) do
      mine = way_out(8, 13, 1)
      other = way_out(35, 13, 2)
      assert_equal [true, true], [PokeAccess::Locator.transfer_event?(mine), PokeAccess::Locator.in_category?(mine, :exits)]
      assert_equal t(:loc_exit), PokeAccess::Locator.target_name(mine)
      assert_equal [false, true], [PokeAccess::Locator.hidden?(mine), PokeAccess::Locator.hidden?(other)]
    end
  end

  test "with no base entered, nothing is left out of the list" do
    in_bases(nil) do
      assert_equal false, PokeAccess::Locator.hidden?(way_out(35, 13))
    end
  end

  test "with none entered, as in a game loaded inside a base, the player's own base is the one with a way out" do
    was = $player
    $player = Struct.new(:secretBase).new(Base.new([8, 12]))
    in_bases(nil) do
      assert_equal [false, true], [PokeAccess::Locator.hidden?(way_out(8, 13, 1)), PokeAccess::Locator.hidden?(way_out(35, 13, 2))]
    end
  ensure
    $player = was
  end

  test "only a way out is left out, and only on the map of the bases" do
    in_bases(Base.new([8, 12])) do
      thing = World.touch(:id => 3, :x => 35, :y => 13, :list => [TestCmd.new(355, ["pbMessage(1)"])])
      assert_equal false, PokeAccess::Locator.hidden?(thing)
      $game_map.map_id = 65
      assert_equal false, PokeAccess::Locator.hidden?(way_out(35, 13, 4))
    end
  end

  test "the way in leads to the map of the bases" do
    in_bases(nil) do
      assert_equal [64, nil, nil], PokeAccess::Locator.script_transfer_dest("enterSecretBase")
    end
  end

  test "sitting down is said, queued, with the key that stands up, and the seat keeps the game's result" do
    assert_equal :stood_up, sit_on_chair_event(nil)
    assert_equal ["#{t(:if2_seat)}. #{t(:if2_seat_hint)}", false], SpeakCapture.log.first
  end

  test "standing up is said, cutting in, as the seat's loop returns" do
    sit_on_chair_event(nil)
    assert_equal [t(:if2_standing), true], SpeakCapture.log.last
    assert_equal 2, SpeakCapture.log.length
  end

  test "the key is left out while key hints are not said" do
    PokeAccess::Config.verbosity = :brief
    sit_on_chair_event(nil)
    assert_equal [[t(:if2_seat), false], [t(:if2_standing), true]], SpeakCapture.log
  end

  private

  def t(key)
    PokeAccess::I18n.t(key)
  end
end
