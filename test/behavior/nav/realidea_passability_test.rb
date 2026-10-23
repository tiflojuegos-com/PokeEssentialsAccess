# Realidea's passability check (games/realidea/passability.rb): asked by the world's probe it plays nothing, refreshes
# no follower and leaves switches 169 and 170 and the lead's status as they were, asked by the game it acts as ever,
# and its swim switch (182) joins the probe's mode.

# Realidea's check on its water floor: switch 169 on, a burn the burn floor left (switch 170) cured on the lead, the
# splash and a follower refresh, then the map's answer.
class Game_Map
  def playerPassable?(x, y, d, _self_event = nil)
    $game_switches[169] = true
    if $game_switches[170]
      $Trainer.party[0].status = 0
      $game_switches[170] = false
    end
    pbSEPlay("Water1")
    $PokemonTemp.dependentEvents.refresh_sprite
    passable?(x, y, d)
  end
end

# The follower events, counting their refreshes.
class DependentEvents
  attr_reader :refreshed
  def initialize; @refreshed = 0; end
  def refresh_sprite(_animation = false); @refreshed += 1; end
end

class RealideaPassabilityTest < PokeAccessTest
  PATH = File.join(Harness::ROOT, "games", "realidea", "passability.rb")
  BURNED = 3
  CURED = 0
  Lead = Struct.new(:status)
  Trainer = Struct.new(:party)
  Temp = Struct.new(:dependentEvents)

  class << self
    # Whether the profile was loaded, and the swim reader it registered, kept aside between tests: the profile loads
    # once per process.
    attr_accessor :loaded, :swim_reader
  end

  test "asked by the probe, the step is answered from the map" do
    on_water_floor do
      assert_equal [true, false], [probe.step?(1, 1, 6), probe.step?(1, 1, 8)], "east onto the floor, north into the wall"
    end
  end

  test "asked by the probe, it plays no sound" do
    on_water_floor do
      probe.step?(1, 1, 6)
      assert_equal [], $se_played
    end
  end

  test "asked by the probe, it refreshes no follower" do
    on_water_floor do |_lead, followers|
      probe.step?(1, 1, 6)
      assert_equal 0, followers.refreshed
    end
  end

  test "asked by the probe, it leaves switches 169 and 170 as they were" do
    on_water_floor do
      probe.step?(1, 1, 6)
      assert_equal [false, true], [$game_switches[169], $game_switches[170]]
    end
  end

  test "asked by the probe, it leaves the lead's status as it was" do
    on_water_floor do |lead, _followers|
      probe.step?(1, 1, 6)
      assert_equal BURNED, lead.status
    end
  end

  test "asked by the game, it plays, refreshes, sets the switches and cures the lead as ever" do
    on_water_floor do |lead, followers|
      $game_player.passable?(1, 1, 6)
      assert_equal [["Water1"], 1, [true, false], CURED],
                   [$se_played, followers.refreshed, [$game_switches[169], $game_switches[170]], lead.status]
    end
  end

  test "with no lead in the party, the probe's step is answered and switch 169 put back" do
    on_water_floor([]) do
      $game_switches[170] = false
      assert_equal [true, false], [probe.step?(1, 1, 6), $game_switches[169]]
    end
  end

  test "asked by the probe, a check that fails partway still puts back the switches and the lead's status" do
    on_water_floor do |lead, _followers|
      $PokemonTemp = Temp.new(nil)
      probe.step?(1, 1, 6)
      assert_equal [false, true, BURNED], [$game_switches[169], $game_switches[170], lead.status]
    end
  end

  test "the water opens the frame after the swim switch turns on, and shuts the frame after it turns off" do
    $game_map.load_grid(["#####",
                         "#@~~#",
                         "#####"])
    swims = lambda do |x, y, d|
      c = $game_map.cell(x + PokeAccess::DIR_DELTA[d][0], y + PokeAccess::DIR_DELTA[d][1])
      c != "#" && (c != "~" || $game_switches[182])
    end
    with_realidea do
      with_player_check(swims) do
        steps = [false, true, false].map do |on|
          $game_switches[182] = on
          World.next_frame
          probe.step?(1, 1, 6)
        end
        assert_equal [false, true, false], steps, "off, on, and off again"
      end
    end
  end

  private

  def probe
    PokeAccess::World::Probe
  end

  # Runs the block on a floor of one row with the profile on, the lead burned (switch 170 on), the followers counting
  # their refreshes and the player's passability going through the game's check; yields the lead and the followers.
  # The trainer, the followers and the sounds played are put back after.
  def on_water_floor(party = nil)
    saved = [$Trainer, $PokemonTemp, $se_played]
    lead = Lead.new(BURNED)
    followers = DependentEvents.new
    $Trainer = Trainer.new(party || [lead])
    $PokemonTemp = Temp.new(followers)
    $se_played = []
    $game_switches[170] = true
    $game_map.load_grid(["#####",
                         "#@..#",
                         "#####"])
    game_check = lambda { |x, y, d| $game_map.playerPassable?(x, y, d, $game_player) }
    with_realidea { with_player_check(game_check) { yield lead, followers } }
  ensure
    $Trainer, $PokemonTemp, $se_played = saved
  end

  # Runs the block with the player's passability answering by check, the stub's put back after.
  def with_player_check(check)
    $game_player.define_singleton_method(:passable?) { |x, y, d| check.call(x, y, d) }
    yield
  ensure
    $game_player.singleton_class.send(:remove_method, :passable?)
  end

  # Runs the block with the profile on: loaded once per process (its hooks bind once by name), its swim reader
  # registered for the block only, the probe's answers dropped on the way in and out.
  def with_realidea
    readers = probe.instance_variable_get(:@readers)
    unless self.class.loaded
      self.class.loaded = true
      self.class.swim_reader = load_profile(readers)
    end
    reader = self.class.swim_reader
    readers.push(reader) if reader
    probe.forget
    yield
  ensure
    readers.reject! { |r| r.equal?(reader) } if reader
    probe.forget
  end

  # Evaluates the profile as the harness loads a file and takes back what it declares beyond its hooks: the profile's
  # name, its plain passability and its swim reader, which it returns.
  def load_profile(readers)
    game = PokeAccess::Game
    kept = [readers.length, game.profiles.dup, game.instance_variable_get(:@profile_name), probe.plain?]
    eval(Harness.source(PATH), TOPLEVEL_BINDING, PATH)
    reader = readers[kept[0]]
    readers.slice!(kept[0]..-1)
    game.profiles.replace(kept[1])
    game.instance_variable_set(:@profile_name, kept[2])
    probe.instance_variable_set(:@plain, kept[3])
    reader
  end
end
