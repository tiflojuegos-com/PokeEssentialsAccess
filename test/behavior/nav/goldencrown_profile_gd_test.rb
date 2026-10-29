# Pokemon Golden Crown's profile (games/goldencrown/): its surf refuses while someone walks along, by the game's own
# dependent-event check (Following Pokemon EX's, which leaves the following Pokemon out), and its passability is plain.
class GoldencrownProfileGdTest < PokeAccessTest
  DIR = File.join(Harness::ROOT, "games", "goldencrown")
  Player = Struct.new(:dependents) do
    def pbHasDependentEvents?; dependents; end
  end

  test "surfing with company follows the game's own check: refused while a dependent walks along" do
    was = $game_player
    got = with_profile("constants") do
      $game_player = Player.new(true)
      refused = PokeAccess::Pathfinder.surf_with_company?
      $game_player = Player.new(false)
      [refused, PokeAccess::Pathfinder.surf_with_company?]
    end
    assert_equal [false, true], got
  ensure
    $game_player = was
  end

  test "the profile declares its passability plain" do
    assert_equal true, with_profile("passability") { PokeAccess::World::Probe.plain? }
  end

  test "both files name the profile" do
    names = with_profile("constants") { with_profile("passability") { PokeAccess::Game.profiles.dup } }
    assert_includes names, "goldencrown"
  end

  private

  # The block's value with one of the profile's files evaluated, the rule on surfing with company, the plain flag and
  # the profile list it changed put back after.
  def with_profile(name)
    company = PokeAccess::Pathfinder.instance_variable_get(:@surf_company)
    plain = PokeAccess::World::Probe.instance_variable_get(:@plain)
    profiles = PokeAccess::Game.profiles.dup
    path = File.join(DIR, "#{name}.rb")
    eval(Harness.source(path), TOPLEVEL_BINDING, path)
    yield
  ensure
    PokeAccess::Pathfinder.instance_variable_set(:@surf_company, company)
    PokeAccess::World::Probe.instance_variable_set(:@plain, plain)
    PokeAccess::Game.instance_variable_set(:@profiles, profiles)
    PokeAccess::Game.instance_variable_set(:@profile_name, nil)
  end
end
