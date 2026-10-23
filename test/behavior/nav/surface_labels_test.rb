# Surfaces with a name of their own under the player: seaweed (the underwater tall grass) while diving, and lava where
# the game's terrain names it (PBTerrain::Lava in Reborn and Rejuvenation), never a tag the game leaves unnamed.

class SurfaceLabelsTest < PokeAccessTest
  SEAWEED = 11
  LAVA = 26

  test "names the seaweed the player swims into" do
    standing_on(SEAWEED) do
      assert_equal [[PokeAccess::I18n.t(:surf_seaweed), false]], SpeakCapture.log
    end
  end

  test "names the lava of a game whose terrain tags name it" do
    PBTerrain.const_set(:Lava, LAVA)
    PokeAccess::World::Terrain.reset!
    standing_on(LAVA) do
      assert_equal [[PokeAccess::I18n.t(:surf_lava), false]], SpeakCapture.log
    end
  ensure
    PBTerrain.send(:remove_const, :Lava) if PBTerrain.const_defined?(:Lava)
    PokeAccess::World::Terrain.reset!
  end

  test "leaves the lava number unnamed in a game that does not name it" do
    standing_on(LAVA) do
      assert_nothing_spoken
    end
  end

  private

  def standing_on(tag)
    cfg = PokeAccess::Config
    was = cfg.surface_cues
    cfg.surface_cues = true
    $game_player.x = 5
    $game_player.y = 5
    $game_player.direction = 2
    $game_map.set_terrain(5, 5, tag)
    PokeAccess::Surfaces.reset_map_state
    SpeakCapture.clear
    PokeAccess::Surfaces.surfaces
    yield
  ensure
    cfg.surface_cues = was
    $game_map.clear_grid
    PokeAccess::Surfaces.reset_map_state
  end
end
