# Surfable water past the map's edge (a coast connected to a sea route): the game reads the connected map's terrain to
# let the player surf across the seam, so the surfable-water notice is said there too.

class SurfAcrossSeamTest < PokeAccessTest
  SEA = 99
  WATER = 7
  LAND = 0

  test "says surfable water ahead across a map connection" do
    facing_seam(WATER) do
      assert_equal [[PokeAccess::I18n.t(:surf_ahead), false]], SpeakCapture.log
    end
  end

  test "keeps quiet when the connected map's tile is land" do
    facing_seam(LAND) do
      assert_nothing_spoken
    end
  end

  private

  def facing_seam(far_tag)
    cfg = PokeAccess::Config
    was = [cfg.surface_cues, $MapFactory]
    cfg.surface_cues = true
    connect_sea_east
    $MapFactory = factory_with(far_tag)
    PokeAccess::MapMeta.forget_foreign
    $game_player.x = $game_map.width - 1
    $game_player.y = 5
    $game_player.direction = 6
    PokeAccess::Surfaces.reset_map_state
    SpeakCapture.clear
    PokeAccess::Surfaces.surfaces
    yield
  ensure
    cfg.surface_cues, $MapFactory = was
    Object.send(:remove_const, :MapFactoryHelper) if Object.const_defined?(:MapFactoryHelper)
    PokeAccess::MapMeta.forget_foreign
  end

  def connect_sea_east
    edge = $game_map.width
    here = $game_map.map_id
    helper = Module.new
    helper.define_singleton_method(:getMapConnections) { [[here, edge, 0, SEA, 0, 0]] }
    helper.define_singleton_method(:getMapDims) { |id| id == SEA ? [10, 10] : [0, 0] }
    Object.const_set(:MapFactoryHelper, helper)
  end

  def factory_with(tag)
    sea = Object.new
    sea.define_singleton_method(:terrain_tag) { |_x, _y| tag }
    factory = Object.new
    factory.define_singleton_method(:getMap) { |_id, _add| sea }
    factory
  end
end
