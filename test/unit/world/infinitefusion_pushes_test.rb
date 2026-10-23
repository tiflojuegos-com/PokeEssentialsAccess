# Both Infinite Fusion games push a boulder after the plain check (their pbPushThisEvent asks can_move_in_direction?
# with strict off), so their common profile declares the pushes loose and the probe asks the plain passable?.

class InfiniteFusionPushesTest < PokeAccessTest
  test "declares the pushes loose in both Infinite Fusion games' profile" do
    with_profile_state_kept do
      load File.expand_path("../../../games/infinitefusion_common/passability.rb", File.dirname(__FILE__))
      assert PokeAccess::World::Probe.instance_variable_get(:@loose_pushes)
    end
  end

  private

  def with_profile_state_kept
    probe = PokeAccess::World::Probe
    game = PokeAccess::Game
    kept = [probe.instance_variable_get(:@readers).dup, probe.instance_variable_get(:@plain),
            game.instance_variable_get(:@profiles).dup, game.instance_variable_get(:@profile_name)]
    yield
  ensure
    probe.instance_variable_set(:@readers, kept[0])
    probe.instance_variable_set(:@plain, kept[1])
    probe.forget
    game.instance_variable_set(:@profiles, kept[2])
    game.instance_variable_set(:@profile_name, kept[3])
  end
end
