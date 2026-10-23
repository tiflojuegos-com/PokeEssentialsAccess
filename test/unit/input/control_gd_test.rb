# Control on the gamedata engine, where v21 flags a menu or message loop updating the map on Game_Temp itself
# (in_mini_update): it holds the cues, and the locator keys only while no message is up.
class ControlGdTest < PokeAccessTest
  Control = PokeAccess::Control

  test "v21's mini update holds the cues, and with no message up the keys as an overlay" do
    assert_equal [:mini_update, :overlay], answering($game_temp, :in_mini_update, lambda { true }) { scopes }
  end

  test "a message over v21's mini update holds the cues and leaves the keys free" do
    got = answering($game_temp, :in_mini_update, lambda { true }) { message_showing { scopes } }
    assert_equal [:message, nil], got
  end

  private

  # The reasons that hold the player now, for the cues and for the locator keys.
  def scopes
    [Control.reason(:hold), Control.reason(:keys)]
  end

  # The block's value with a message showing, the flag put back after.
  def message_showing
    was = $game_temp.message_window_showing
    $game_temp.message_window_showing = true
    yield
  ensure
    $game_temp.message_window_showing = was
  end

  # The block's value with obj's meth answering as body does; the method obj had of its own, if any, put back after.
  def answering(obj, meth, body)
    sc = obj.singleton_class
    own = sc.instance_methods(false).include?(meth) || sc.private_instance_methods(false).include?(meth)
    was = own ? obj.method(meth) : nil
    obj.define_singleton_method(meth, &body)
    yield
  ensure
    if was
      obj.define_singleton_method(meth, was)
    elsif sc && sc.instance_methods(false).include?(meth)
      sc.send(:remove_method, meth)
    end
  end
end
