# The ice-slide flag is $PokemonGlobal.sliding up to v20 and ice_sliding from v21 (gamedata pass): Control.sliding?,
# which holds the guides and the soundscape through a slide, answers to the modern name, and neither a step that is no
# slide nor a flag that cannot be read is taken for one.
class IceSlidingGdTest < PokeAccessTest
  Control = PokeAccess::Control

  test "takes the v21 flag alone for a slide" do
    $PokemonGlobal.ice_sliding = true
    assert_equal true, Control.sliding?
  ensure
    $PokemonGlobal.ice_sliding = false
  end

  test "tells the player moving by the v21 flag as sliding" do
    $PokemonGlobal.ice_sliding = true
    assert_equal :sliding, Control.motion
  ensure
    $PokemonGlobal.ice_sliding = false
  end

  test "is no slide once the v21 flag drops" do
    $PokemonGlobal.ice_sliding = true
    $PokemonGlobal.ice_sliding = false
    assert_equal [false, :still], [Control.sliding?, Control.motion]
  end

  test "takes a step on ground that is not ice for a step, not a slide" do
    $game_player.define_singleton_method(:moving?) { true }
    assert_equal [false, :moving], [Control.sliding?, Control.motion]
  ensure
    $game_player.singleton_class.send(:remove_method, :moving?) if $game_player.singleton_methods.include?(:moving?)
  end

  test "takes a v21 flag that cannot be read for no slide" do
    was = $PokemonGlobal.method(:ice_sliding)
    $PokemonGlobal.define_singleton_method(:ice_sliding) { raise "unreadable" }
    assert_equal false, Control.sliding?
  ensure
    $PokemonGlobal.define_singleton_method(:ice_sliding, was)
  end
end
