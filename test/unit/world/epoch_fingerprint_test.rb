# The tiles fingerprint keeps copies of what it compares: a game that rewrites an autotile in place, with no new map
# (Insurgence's Seed Flare turns a sludge slot into water), changes it.

class EpochFingerprintTest < PokeAccessTest
  test "changes when an autotile name is rewritten in place" do
    names = ["slime", "grass"]
    with_autotiles(names) do
      before = PokeAccess::World::Epoch.fingerprint
      names[0] = "calm transparent water 2"

      refute_equal before, PokeAccess::World::Epoch.fingerprint
    end
  end

  test "changes when an autotile name's own string is edited" do
    names = ["slime", "grass"]
    with_autotiles(names) do
      before = PokeAccess::World::Epoch.fingerprint
      names[1] << " 2"

      refute_equal before, PokeAccess::World::Epoch.fingerprint
    end
  end

  test "stays the same while nothing changes" do
    with_autotiles(["slime", "grass"]) do
      assert_equal PokeAccess::World::Epoch.fingerprint, PokeAccess::World::Epoch.fingerprint
    end
  end

  private

  def with_autotiles(names)
    $game_map.define_singleton_method(:autotile_names) { names }
    yield
  ensure
    class << $game_map; remove_method :autotile_names; end
  end
end
