# pbTopRightWindow, the modal panel the confirm key closes, reads itself, queued, unless a caller mutes it for its
# call, as the battle scene's pbLevelUp does. The function is an engine stub, so core binds to it at load.

# A level-up that says its own line and mutes the two stat panels it raises.
class TopRightLevelUpScene
  def pbLevelUp(pkmn, _battler, _ohp, _oatk, _odef, _ospa, _ospd, _ospe)
    pbTopRightWindow("Max. HP<r>+3\r\nAttack<r>+2")
    pbTopRightWindow("Max. HP<r>44\r\nAttack<r>30")
    pkmn
  end
end

PokeAccess::Hooks.around_hook("TopRightLevelUpScene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess.speak("subio de nivel", false)
  PokeAccess::ModalPanel.muted { nxt.call }
end

# A level-up whose reader throws before it: the mute rides an around-hook of its own.
class TopRightThrowingScene
  def pbLevelUp(*_a); pbTopRightWindow("Max. HP<r>+1"); :done; end
end

PokeAccess::Hooks.before_hook("TopRightThrowingScene", :pbLevelUp) { |_s, _a| raise "reader boom" }
PokeAccess::Hooks.around_hook("TopRightThrowingScene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess::ModalPanel.muted { nxt.call }
end

class ModalPanelTest < PokeAccessTest
  test "a panel raised on its own is read, queued, its markup and line breaks gone" do
    pbTopRightWindow("Max. HP<r>+3\r\nAttack<r>+2")
    assert_equal [["Max. HP+3 Attack+2", false]], SpeakCapture.log
  end

  test "a panel's key hint names the key the player has bound now" do
    was = [PokeAccess::Config.rebinds, PokeAccess::Config.key_hint_letters]
    PokeAccess::Config.key_hint_letters = { "C" => :c }
    PokeAccess::Config.rebinds = { :c => 0x4B }
    pbTopRightWindow("Pulsa C para continuar.")
    assert_equal [["Pulsa K para continuar.", false]], SpeakCapture.log
  ensure
    PokeAccess::Config.rebinds = was[0]
    PokeAccess::Config.key_hint_letters = was[1]
  end

  test "a panel keeps the value its function returns" do
    assert_equal "Speed<r>+1", pbTopRightWindow("Speed<r>+1")
  end

  test "a caller that speaks for the panels silences them for its call" do
    assert_equal :pkmn, TopRightLevelUpScene.new.pbLevelUp(:pkmn, nil, 1, 2, 3, 4, 5, 6)
    assert_equal [["subio de nivel", false]], SpeakCapture.log
  end

  test "the panel after a muted call is read again" do
    TopRightLevelUpScene.new.pbLevelUp(nil, nil, 1, 2, 3, 4, 5, 6)
    SpeakCapture.clear
    pbTopRightWindow("Speed<r>+1")
    assert_equal [["Speed+1", false]], SpeakCapture.log
  end

  test "a muted call that throws still lets the next panel be read" do
    assert_raises(RuntimeError) { PokeAccess::ModalPanel.muted { raise "boom" } }
    pbTopRightWindow("Defense<r>+1")
    assert_equal [["Defense+1", false]], SpeakCapture.log
  end

  test "a reader that throws costs its line, not the level-up, and the panels stay muted" do
    assert_equal :done, TopRightThrowingScene.new.pbLevelUp(nil)
    assert_nothing_spoken
  end
end
