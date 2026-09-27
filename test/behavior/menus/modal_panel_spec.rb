# pbTopRightWindow, the modal panel the confirm key closes, reads itself unless a caller mutes it for its call, as the
# battle scene's pbLevelUp does. The function is an engine stub, so core binds to it at load.
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

Suite.define("top-right panel: reads itself, except where the caller already said it better") do
  SpeakCapture.clear
  pbTopRightWindow("Max. HP<r>+3\r\nAttack<r>+2")
  line = SpeakCapture.lines.join(" ")
  match "a panel raised on its own is read", line, /Max\. HP/
  truthy "with its markup and line breaks gone",
         !line.include?("<r>") && !line.include?("\r") && !line.include?("\n")

  SpeakCapture.clear
  TopRightLevelUpScene.new.pbLevelUp(nil, nil, 1, 2, 3, 4, 5, 6)
  eq "a caller that speaks for the panels silences them", SpeakCapture.lines, ["subio de nivel"]

  SpeakCapture.clear
  pbTopRightWindow("Speed<r>+1")
  spoke "and the next panel after it is read again", /Speed/

  begin
    PokeAccess::ModalPanel.muted { raise "boom" }
  rescue StandardError
    nil
  end
  SpeakCapture.clear
  pbTopRightWindow("Defense<r>+1")
  spoke "even when the muted call threw", /Defense/
end

# A reader body that throws costs its line, never the level-up; the mute rides an around-hook of its own.
class TopRightThrowingScene
  def pbLevelUp(*_a); pbTopRightWindow("Max. HP<r>+1"); :done; end
end

PokeAccess::Hooks.before_hook("TopRightThrowingScene", :pbLevelUp) { |_s, _a| raise "reader boom" }
PokeAccess::Hooks.around_hook("TopRightThrowingScene", :pbLevelUp) do |_s, nxt, _a|
  PokeAccess::ModalPanel.muted { nxt.call }
end

Suite.define("top-right panel: a reader that throws costs its line, not the level-up") do
  SpeakCapture.clear
  got = (begin; TopRightThrowingScene.new.pbLevelUp(nil); rescue StandardError; :propagated; end)
  eq "the original still ran and returned", got, :done
  silent "the panels stayed muted even though the reader threw"
end
