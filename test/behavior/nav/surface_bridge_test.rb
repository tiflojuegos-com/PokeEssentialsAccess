# The surface cue on a bridge's tiles follows the engine's bridge height: on the bridge it names the bridge, and under
# it (height 0, where the engine ignores the bridge) it says the player is under the bridge.

class SurfaceBridgeTest < PokeAccessTest
  test "names the bridge while the player walks on it" do
    on_bridge_tile(2, false) do
      assert_equal [[PokeAccess::I18n.t(:surf_bridge), false]], SpeakCapture.log
    end
  end

  test "says the player is under the bridge while surfing beneath it" do
    on_bridge_tile(0, true) do
      assert_equal [[PokeAccess::I18n.t(:surf_under_bridge), false]], SpeakCapture.log
    end
  end

  private

  def on_bridge_tile(height, surfing)
    cfg = PokeAccess::Config
    was = [cfg.surface_cues, $PokemonGlobal.bridge, $PokemonGlobal.surfing]
    cfg.surface_cues = true
    $game_map.load_grid(["#####", "##~##", "##@##", "##~##", "#####"])
    [1, 2, 3].each { |y| $game_map.place_bridge(2, y) }
    $game_player.direction = 4
    $PokemonGlobal.bridge = height
    $PokemonGlobal.surfing = surfing
    PokeAccess::Surfaces.reset_map_state
    SpeakCapture.clear
    PokeAccess::Surfaces.surfaces
    yield
  ensure
    cfg.surface_cues, $PokemonGlobal.bridge, $PokemonGlobal.surfing = was
    $game_map.clear_grid
    PokeAccess::Surfaces.reset_map_state
  end
end
