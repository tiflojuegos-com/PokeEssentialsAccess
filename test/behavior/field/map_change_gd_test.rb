# Map names in the gamedata engine, which loads MapInfos with pbLoadMapInfos rather than gen-6's pbLoadRxData; the
# announcing itself, the same in both engines, is pinned in map_change_test.
class MapChangeGdTest < PokeAccessTest
  test "a map is named through the modern MapInfos loader, and an id it lacks not at all" do
    assert_equal "Mapa 35", PokeAccess::Locator.map_name(35)
    assert_nil PokeAccess::Locator.map_name(999999)
  end

  test "a map name is cleaned for speech, the player's name in place of \\PN" do
    assert_equal "Casa de #{$player.name}", PokeAccess::Locator.map_name(36)
  end
end
