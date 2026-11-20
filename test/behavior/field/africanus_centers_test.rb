# Africanvs' Pokemon Centres (games/africanus/centers.rb), with the profile loaded whole in a process of its own: a map
# is one when it holds the game's nurse, as MapMeta.pokecenter? and the locator's door names read it, each map file read
# once a run.
class AfricanusCentersTest < ProfileProcessTest
  WORLD = <<-'RUBY'
    $VERBOSE = nil
    RawMap = Struct.new(:events)
    RawEvent = Struct.new(:id, :pages)
    RawPage = Struct.new(:trigger, :graphic, :list)
    RawGraphic = Struct.new(:character_name)
    RawCmd = Struct.new(:code, :parameters)
    CENTER = RawCmd.new(355, ["Kernel.pbSetPokemonCenter"])
    GREETING = RawCmd.new(101, ["Salve, sea bienvenido al Centro Pokemon"])
    RECOVER = RawCmd.new(314, [0])
    AFRICANUS_MAPS = { "Data/Map027" => ["000", [CENTER, GREETING, RECOVER]],
                       "Data/Map123" => ["GALO", [CENTER, GREETING, RECOVER]],
                       "Data/Map008" => ["000", [GREETING, CENTER, RECOVER]] }
    LOADS = []
    def pbLoadRxData(file)
      LOADS.push(file)
      sprite, list = AFRICANUS_MAPS.fetch(file)
      RawMap.new({ 6 => RawEvent.new(6, [RawPage.new(0, RawGraphic.new(sprite), list)]) })
    end
    def pbGetMetadata(map, field); field == 1 && map == 1 ? true : nil; end
  RUBY

  PLAY = <<-'RUBY'
    $game_map = Struct.new(:map_id).new(1)
    probe(:centres) { [27, 123, 8, 50, 27, 50].map { |id| PokeAccess::MapMeta.pokecenter?(id) } }
    probe(:reads) do
      PokeAccess::Caches.reset_all
      PokeAccess::MapMeta.pokecenter?(27)
      LOADS.dup
    end
    probe(:doors) { [27, 123].map { |id| PokeAccess::Locator.same_place_name(id, "Siga") } }
  RUBY

  profile("africanus", WORLD, PLAY)

  test "a map holding the game's nurse is a Pokemon Centre, read once a run, and its door is named for it" do
    assert_equal [true, false, false, false, true, false], played(:centres)
    assert_equal %w[Data/Map027 Data/Map123 Data/Map008 Data/Map050], played(:reads)
    assert_equal [t(:loc_pokecenter), t(:loc_building)], played(:doors)
  end
end
