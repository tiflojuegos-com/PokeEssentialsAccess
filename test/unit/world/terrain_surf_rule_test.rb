# A game's own surf rule (Insurgence's still water once Seed Flare cleans the map's sludge slot): the SURF bit of a tag
# follows it, and is taken again when the map's tiles change.

class TerrainSurfRuleTest < PokeAccessTest
  OWN_TAG = 40

  test "gives the SURF bit to a tag the rule lets the player surf on" do
    with_rule(lambda { |n| n == OWN_TAG }) do
      assert_equal true, surf?(OWN_TAG)
      assert_equal false, surf?(OWN_TAG + 1)
    end
  end

  test "takes the bit again once the tiles change" do
    clean = false
    with_rule(lambda { |n| n == OWN_TAG && clean }) do
      assert_equal false, surf?(OWN_TAG)
      clean = true
      PokeAccess::World::Epoch.touch(:tiles)

      assert_equal true, surf?(OWN_TAG)
    end
  end

  private

  def surf?(tag)
    PokeAccess::World::Terrain.tag_bits(tag) & PokeAccess::World::Terrain::SURF != 0
  end

  def with_rule(rule)
    terrain = PokeAccess::World::Terrain
    terrain.reset!
    terrain.surf_rule(&rule)
    yield
  ensure
    terrain.instance_variable_get(:@surf_rules).pop
    terrain.reset!
  end
end
