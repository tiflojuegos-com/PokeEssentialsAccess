# The surface notice for water ahead (surface_cues), queued behind what is being said (the map's name on arrival):
# surfable where the game would let the player start Surf, plain water on a map that keeps the player on the bike or
# where the routes would not surf (the party, company); nothing over falling water, nor from a tile closed on that side.

class SurfAheadTest < PokeAccessTest
  test "says surfable water ahead, queued" do
    facing_water(["#####", "#@~~#", "#####"]) do
      assert_equal [[PokeAccess::I18n.t(:surf_ahead), false]], SpeakCapture.log
    end
  end

  test "keeps quiet facing falling water" do
    facing_water(["#####", '#@W~#', "#####"]) do
      assert_nothing_spoken
    end
  end

  test "keeps quiet where the player's tile is closed toward the water" do
    facing_water(["######", "#@]~~#", "######"], [2, 1]) do
      assert_nothing_spoken
    end
  end

  test "says plain water ahead on a map that keeps the player on the bike" do
    meta = PokeAccess::MapMeta
    meta.singleton_class.send(:alias_method, :always_bicycle_spec?, :always_bicycle?)
    meta.define_singleton_method(:always_bicycle?) { |_mid| true }
    facing_water(["#####", "#@~~#", "#####"]) do
      assert_equal [[PokeAccess::I18n.t(:water_ahead), false]], SpeakCapture.log
    end
  ensure
    meta.singleton_class.send(:alias_method, :always_bicycle?, :always_bicycle_spec?)
    meta.singleton_class.send(:remove_method, :always_bicycle_spec?)
  end

  test "says plain water ahead where the party cannot surf, as the routes take it" do
    stubbing(PokeAccess::FieldMoves, :can?, proc { |move| move == :SURF ? false : nil }) do
      facing_water(["#####", "#@~~#", "#####"]) { assert_said_water }
    end
  end

  test "says plain water ahead where the game will not let the player surf with whoever walks along" do
    stubbing(PokeAccess::Pathfinder, :surf_with_company?, proc { false }) do
      facing_water(["#####", "#@~~#", "#####"]) { assert_said_water }
    end
  end

  private

  # Asserts the only line said was plain water ahead, queued.
  def assert_said_water
    assert_equal [[PokeAccess::I18n.t(:water_ahead), false]], SpeakCapture.log
  end

  # Runs the block with mod's method meth answering as body does, the real one put back after.
  def stubbing(mod, meth, body)
    real = mod.method(meth)
    mod.define_singleton_method(meth, &body)
    yield
  ensure
    mod.define_singleton_method(meth, real)
  end

  def facing_water(rows, at = nil)
    cfg = PokeAccess::Config
    was = cfg.surface_cues
    cfg.surface_cues = true
    with_tile_world(rows) do |world|
      $game_player.x, $game_player.y = (at || world.start)
      $game_player.direction = 6
      PokeAccess::Surfaces.reset_map_state
      SpeakCapture.clear
      PokeAccess::Surfaces.surfaces
      yield
    end
  ensure
    cfg.surface_cues = was
  end
end
