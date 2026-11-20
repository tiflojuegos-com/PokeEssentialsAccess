# Revival's Pokemon Centres (games/revival/centers.rb), with the profile loaded whole in a process of its own: a map is
# one when the game's own name for it says so, as MapMeta.pokecenter? and the locator's door names read it.
class RevivalCentersGdTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    REVIVAL_NAMES = { 31 => "Ciudad Zahlen Centro Pokémon", 214 => "Centros Pokemon Galar", 5 => "Pokémon Center",
                      40 => "Ciudad Zahlen", 41 => "Centro comercial" }
    def pbGetMapNameFromId(id); REVIVAL_NAMES[id].to_s; end
  RUBY

  PLAY = <<-'RUBY'
    $game_map = Struct.new(:map_id).new(1)
    probe(:centres) { [31, 214, 5, 40, 41, 0].map { |id| PokeAccess::MapMeta.pokecenter?(id) } }
    probe(:doors) do
      PokeAccess::MapMeta.define_singleton_method(:outdoor?) { |id| id == 1 }
      [31, 41].map { |id| PokeAccess::Locator.same_place_name(id, "Ciudad Zahlen") }
    end
  RUBY

  profile("revival", WORLD, PLAY, "gamedata")

  test "a map the game names a Pokemon Centre is one, and its door is named for it" do
    assert_equal [true, true, true, false, false, false], played(:centres)
    assert_equal [t(:loc_pokecenter), t(:loc_building)], played(:doors)
  end
end
